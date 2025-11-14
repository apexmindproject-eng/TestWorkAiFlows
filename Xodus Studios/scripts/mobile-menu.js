/* mobile-menu.js - Robust mobile navigation manager for Xodus Studios
 * Features:
 * - Mobile menu toggle and off-canvas behavior
 * - Focus trap for accessibility
 * - Submenu handling (aria-expanded toggles)
 * - Close-on-navigation, outside click, Escape, and swipe-to-close
 * - Active link detection for mobile nav
 * - Lightweight form validation for forms inside the mobile menu
 * - Event delegation for performance
 * - Defensive coding and error handling
 */

(() => {
  'use strict';

  // Utilities
  const $ = (sel, ctx = document) => (ctx || document).querySelector(sel) || null;
  const $$ = (sel, ctx = document) => Array.from((ctx || document).querySelectorAll(sel));

  const noop = () => {};
  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);

  const isFunction = (v) => typeof v === 'function';

  const safeFocus = (el) => { try { if (el && typeof el.focus === 'function') el.focus(); } catch (e) { /* ignore */ } };

  // Elements and selectors
  const TOGGLE_SELECTOR = '#mobile-menu-toggle, .mobile-menu-toggle';
  const NAV_SELECTORS = '.main-nav, .primary-nav, #main-nav, nav[role="navigation"]';
  const NAV_LINKS_SELECTOR = 'a.nav-link, nav a';
  const OVERLAY_ID = 'mobile-menu-overlay-xodus';

  // State
  let activeToggle = null;
  let activeMenu = null;
  let overlayEl = null;
  let previouslyFocused = null;
  let isOpen = false;

  // Config
  const ANIMATION_DURATION = 280; // match css transition
  const SWIPE_CLOSE_THRESHOLD = 80; // px
  const BREAKPOINT_CLOSE = 960; // px - automatically close menu above

  // Keep track of touch start for swipe gestures
  let touchStartX = 0;
  let touchStartY = 0;
  let touchTracking = false;
// Find toggle elements and attach handlers
  function initToggles() {
    try {
      const toggles = document.querySelectorAll(TOGGLE_SELECTOR);
      if (!toggles.length) return;

      toggles.forEach(toggle => {
        try {
          // normalize attributes
          if (!toggle.hasAttribute('aria-controls')) {
            const menu = document.querySelector(NAV_SELECTORS);
            if (menu && menu.id) toggle.setAttribute('aria-controls', menu.id);
            else if (menu) {
              // ensure it has id
              const id = `mobile-nav-${Math.random().toString(36).slice(2, 8)}`;
              menu.id = id; toggle.setAttribute('aria-controls', id);
            }
          }
          toggle.setAttribute('aria-expanded', toggle.getAttribute('aria-expanded') || 'false');
          toggle.addEventListener('click', onToggleClick);
        } catch (err) { console.error('initToggles inner', err); }
      });
// Close menus when clicking nav links
      document.body.addEventListener('click', (e) => {
        try {
          const link = e.target.closest(NAV_LINKS_SELECTOR);
          if (!link) return;
          if (!isOpen) return;
          // if link is external or has target _blank, let default happen
          if (link.target === '_blank' || link.hasAttribute('download') || link.dataset.noClose === 'true') return;
          // small delay to allow transitions or navigation
          setTimeout(() => closeMobileMenu(), 160);
        } catch (err) { console.error('nav link click handler', err); }
      });

      // Accessibility keyboard support
      document.body.addEventListener('keydown', (e) => {
        try {
          if (!isOpen) return;
          if (e.key === 'Escape') { e.preventDefault(); closeMobileMenu(); return; }
          if (e.key === 'Tab') handleFocusTrap(e);
        } catch (err) { console.error('keyboard handler', err); }
      });
// Window resize to auto-close when larger viewport
      window.addEventListener('resize', debounce(() => {
        try {
          if (window.innerWidth > BREAKPOINT_CLOSE && isOpen) {
            closeMobileMenu(true);
          }
        } catch (err) { /* ignore */ }
      }, 200));

    } catch (err) {
      console.error('initToggles error', err);
    }
  }

  // Toggle click handler
  function onToggleClick(e) {
    try {
      e.preventDefault();
      const toggle = e.currentTarget;
      const controlsId = toggle.getAttribute('aria-controls');
      const menu = controlsId ? document.getElementById(controlsId) : document.querySelector(NAV_SELECTORS);
      if (!menu) return;

      // remember last focused element
      previouslyFocused = document.activeElement;

      activeToggle = toggle; activeMenu = menu;
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      if (expanded) closeMobileMenu(); else openMobileMenu(toggle, menu);
    } catch (err) { console.error('onToggleClick error', err); }
  }

  // Open menu with animation and focus trap
  function openMobileMenu(toggle, menu) {
    try {
      if (!menu || !toggle) return;
      // set aria states
      toggle.setAttribute('aria-expanded', 'true');
      menu.classList.add('is-open');
      menu.setAttribute('aria-hidden', 'false');
      document.documentElement.classList.add('no-scroll');

      // overlay show
      const overlay = createOverlay();
      if (overlay) setTimeout(() => overlay.style.opacity = '1', 10);

      isOpen = true;
// Close menu with optional immediate flag
  function closeMobileMenu(immediate = false) {
    try {
      if (!activeMenu || !activeToggle) {
        // attempt to find a menu open on the document
        const menu = document.querySelector(`${NAV_SELECTORS}.is-open`);
        const toggle = document.querySelector(TOGGLE_SELECTOR);
        if (menu) activeMenu = menu; if (toggle) activeToggle = toggle;
      }

      if (!activeMenu) return;
      // set aria states
      if (activeToggle) activeToggle.setAttribute('aria-expanded', 'false');
      activeMenu.classList.remove('is-open');
      activeMenu.setAttribute('aria-hidden', 'true');
      document.documentElement.classList.remove('no-scroll');

      // overlay hide
      if (overlayEl) {
        overlayEl.style.opacity = '0';
        setTimeout(() => { try { overlayEl && overlayEl.parentNode && overlayEl.parentNode.removeChild(overlayEl); overlayEl = null; } catch (err) {} }, ANIMATION_DURATION);
      }
isOpen = false;

      // remove swipe listeners
      detachSwipeListeners(activeMenu);

      if (activeToggle) activeToggle.classList.remove('is-active');

      // restore focus
      if (previouslyFocused) safeFocus(previouslyFocused);

      previouslyFocused = null; activeToggle = null; activeMenu = null;

      document.dispatchEvent(new CustomEvent('xodus:mobileMenu:close', {}));
    } catch (err) { console.error('closeMobileMenu', err); }
  }

  // Focus trap implementation
  function getFocusable(root) {
    const sel = 'a[href], area[href], input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])';
    try {
      return Array.from(root.querySelectorAll(sel)).filter(el => el.offsetParent !== null || getComputedStyle(el).position === 'fixed');
    } catch (err) { return []; }
  }
function handleFocusTrap(e) {
    try {
      const menu = activeMenu; if (!menu) return;
      const focusable = getFocusable(menu);
      if (!focusable.length) {
        e.preventDefault(); return;
      }
      const first = focusable[0]; const last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    } catch (err) { console.error('handleFocusTrap', err); }
  }
// ---------- Submenu toggles (expand/collapse) ----------
  function initSubmenus() {
    try {
      const navs = document.querySelectorAll(NAV_SELECTORS);
      navs.forEach(nav => {
        nav.querySelectorAll('li').forEach(li => {
          try {
            const sub = li.querySelector('ul');
            const link = li.querySelector('a');
            if (sub && link) {
              // ensure button for expanding
              if (!li.querySelector('.submenu-toggle')) {
                const btn = document.createElement('button');
                btn.className = 'submenu-toggle';
                btn.setAttribute('aria-expanded', 'false');
                btn.setAttribute('aria-label', `Toggle submenu for ${link.textContent.trim()}`);
                btn.textContent = '▾';
                link.insertAdjacentElement('afterend', btn);
btn.addEventListener('click', (e) => {
                  e.preventDefault();
                  const exp = btn.getAttribute('aria-expanded') === 'true';
                  btn.setAttribute('aria-expanded', exp ? 'false' : 'true');
                  sub.style.display = exp ? 'none' : 'block';
                });
                // hide submenu initially for mobile if not open
                if (!li.classList.contains('is-open')) sub.style.display = 'none';
              }
            }
          } catch (err) { /* ignore per-li errors */ }
        });
      });
    } catch (err) { console.error('initSubmenus', err); }
  }
// ---------- Active link detection (mobile-specific) ----------
  function updateActiveLinks(scope = document) {
    try {
      const links = scope.querySelectorAll(NAV_LINKS_SELECTOR);
      const path = location.pathname.replace(/index\.html$/, '').replace(/\/pages\//, '/').replace(/\/$/, '') || '/';
      links.forEach(a => {
        try {
          const href = a.getAttribute('href') || '';
          const url = new URL(href, location.origin);
          let linkPath = url.pathname.replace(/index\.html$/, '').replace(/\/pages\//, '/').replace(/\/$/, '') || '/';
          if (linkPath === path) { a.classList.add('active'); a.setAttribute('aria-current', 'page'); }
          else { a.classList.remove('active'); a.removeAttribute('aria-current'); }
        } catch (err) { /* ignore bad href */ }
      });
    } catch (err) { console.error('updateActiveLinks', err); }
  }
// ---------- Lightweight form validation for forms inside mobile menu ----------
  function initMobileMenuForms(scope = document) {
    try {
      const forms = scope.querySelectorAll('nav form, .mobile-menu form, form[data-mobile="true"]');
      if (!forms.length) return;

      forms.forEach(form => {
        try {
          if (form._xodusMobileFormInit) return; form._xodusMobileFormInit = true;

          const email = form.querySelector('input[type="email"]');
          const requiredFields = Array.from(form.querySelectorAll('[required]'));

          const showError = (el, msg) => {
            try {
              el.classList.add('input-error');
              el.setAttribute('aria-invalid', 'true');
              let hint = el.nextElementSibling;
              if (!hint || !hint.classList.contains('field-error')) {
                hint = document.createElement('div'); hint.className = 'field-error'; el.parentNode.insertBefore(hint, el.nextSibling);
              }
              hint.textContent = msg;
            } catch (e) {}
          };
          const clearError = (el) => {
            try { el.classList.remove('input-error'); el.removeAttribute('aria-invalid'); const h = el.nextElementSibling; if (h && h.classList.contains('field-error')) h.textContent = ''; } catch (e) {}
          };
form.addEventListener('submit', (e) => {
            try {
              let ok = true;
              requiredFields.forEach(f => {
                const v = (f.value || '').trim();
                if (!v) { ok = false; showError(f, 'This field is required'); }
                else clearError(f);
                if (f.type === 'email' && v) {
                  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) { ok = false; showError(f, 'Enter a valid email'); }
                }
              });
              if (!ok) { e.preventDefault(); e.stopImmediatePropagation(); const first = form.querySelector('.input-error'); if (first) safeFocus(first); }
            } catch (err) { console.error('mobile form submit error', err); }
          });

          form.addEventListener('input', (ev) => { try { clearError(ev.target); } catch (e) {} });
        } catch (err) { /* per-form error */ }
      });

    } catch (err) { console.error('initMobileMenuForms', err); }
  }

  // ---------- Public Init / Reinit (for SPA transitions) ----------
  function init(root = document) {
    try {
      initToggles();
      initSubmenus();
      updateActiveLinks(root);
      initMobileMenuForms(root);

      // Recalculate active links when SPA navigation completes
      document.addEventListener('xodus:navigateComplete', (e) => {
        try { updateActiveLinks(document); initMobileMenuForms(document); } catch (err) { /* ignore */ }
      });

    } catch (err) { console.error('mobile-menu init error', err); }
  }