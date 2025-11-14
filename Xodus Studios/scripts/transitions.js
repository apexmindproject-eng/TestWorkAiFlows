/* transitions.js - Page transition & animated navigation manager for Xodus Studios
 * Responsibilities:
 * - Smooth page transitions (AJAX navigation + history management)
 * - Prefetching and caching of internal pages
 * - Top progress bar and preloader handling
 * - Mobile menu safety helpers (toggle, close on navigation)
 * - Active navigation detection & focus management after navigation
 * - Lightweight post-navigation initialization (animations, forms, lazy images)
 *
 * Defensive, modern ES6+ code. Uses delegated events where appropriate. Designed to work across
 * all pages in the project: index, merch, trailers, shorts, social, about, projects, characters, videogames.
 */

(() => {
  'use strict';

  // ---------- Utilities ----------
  const $ = (sel, scope = document) => scope.querySelector(sel) || null;
  const $$ = (sel, scope = document) => Array.from((scope || document).querySelectorAll(sel));

  const noop = () => {};

  const isSameOrigin = (url) => {
    try {
      const u = new URL(url, location.href);
      return u.origin === location.origin;
    } catch (e) {
      return false;
    }
  };

  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);

  const safeFocus = (el) => {
    try { if (el && typeof el.focus === 'function') el.focus(); } catch (e) {}
  };

  const parseHTML = (html) => new DOMParser().parseFromString(html, 'text/html');

  // Debounce to avoid excessive prefetches
  const debounce = (fn, wait = 100) => {
    let t = null;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...args), wait);
    };
  };

  // ---------- State & Cache ----------
  const pageCache = new Map(); // url -> { html, title, mainHTML }
  const prefetchControllers = new Map(); // url -> AbortController
  let currentController = null;
// ---------- Elements ----------
  const mainSelector = '#main-content';
  const mainEl = $(mainSelector);
  const headerEl = $('#site-header');
  const mobileToggleSelector = '#mobile-menu-toggle, .mobile-menu-toggle';

  // Progress bar (top) creation
  const progress = (() => {
    let el = null;
    let visible = false;
    const create = () => {
      if (el) return el;
      el = document.createElement('div');
      el.id = 'page-progress';
      el.setAttribute('aria-hidden', 'true');
      el.style.position = 'fixed';
      el.style.top = '0';
      el.style.left = '0';
      el.style.height = '3px';
      el.style.width = '0%';
      el.style.background = 'linear-gradient(90deg,#00f,#0ff)';
      el.style.zIndex = '9999';
      el.style.transition = 'width 250ms linear, opacity 200ms linear';
      el.style.opacity = '0';
      document.documentElement.appendChild(el);
      return el;
    };
const show = () => {
      try {
        create();
        visible = true;
        el.style.opacity = '1';
        setWidth(4);
      } catch (e) { console.error('progress show', e); }
    };
    const hide = () => {
      try {
        if (!el) return;
        el.style.width = '100%';
        setTimeout(() => { el.style.opacity = '0'; el.style.width = '0%'; }, 250);
        visible = false;
      } catch (e) { console.error('progress hide', e); }
    };
    const setWidth = (p) => { if (!el) create(); el.style.width = `${clamp(p, 0, 100)}%`; };

    return { show, hide, setWidth };
  })();

  // ---------- Mobile menu helpers ----------
  function initMobileToggles() {
    const toggles = document.querySelectorAll(mobileToggleSelector);
    toggles.forEach(t => {
      try {
        const targetId = t.getAttribute('aria-controls');
        const menu = targetId ? document.getElementById(targetId) : document.querySelector('.main-nav, .primary-nav');
        if (!menu) return;
t.setAttribute('aria-expanded', 'false');
        menu.setAttribute('aria-hidden', 'true');

        t.addEventListener('click', (ev) => {
          ev.preventDefault();
          const open = t.getAttribute('aria-expanded') === 'true';
          if (open) closeMobileMenu(t, menu); else openMobileMenu(t, menu);
        });
      } catch (e) { console.error('mobile toggle init err', e); }
    });

    // Close mobile menus when navigation occurs
    document.addEventListener('xodus:navigateComplete', () => {
      document.querySelectorAll(mobileToggleSelector).forEach(t => {
        const targetId = t.getAttribute('aria-controls');
        const menu = targetId ? document.getElementById(targetId) : document.querySelector('.main-nav, .primary-nav');
        if (menu && menu.classList.contains('is-open')) closeMobileMenu(t, menu);
      });
    });
  }
function openMobileMenu(toggle, menu) {
    try {
      toggle.setAttribute('aria-expanded', 'true');
      menu.classList.add('is-open');
      menu.setAttribute('aria-hidden', 'false');
      document.documentElement.classList.add('no-scroll');
      const first = menu.querySelector('a, button, input');
      safeFocus(first);
    } catch (e) { console.error('openMobileMenu', e); }
  }

  function closeMobileMenu(toggle, menu) {
    try {
      toggle.setAttribute('aria-expanded', 'false');
      menu.classList.remove('is-open');
      menu.setAttribute('aria-hidden', 'true');
      document.documentElement.classList.remove('no-scroll');
    } catch (e) { console.error('closeMobileMenu', e); }
  }
// ---------- Active link detection ----------
  function updateActiveNavLinks(context = document) {
    try {
      const links = context.querySelectorAll('a.nav-link');
      const locPath = location.pathname.replace(/\/pages\//, '/').replace(/index\.html$/, '').replace(/\/$/, '') || '/';
      links.forEach(a => {
        try {
          const href = a.getAttribute('href') || '';
          const url = new URL(href, location.href);
          let p = url.pathname.replace(/\/pages\//, '/').replace(/index\.html$/, '').replace(/\/$/, '') || '/';
          if (p === locPath) { a.classList.add('active'); a.setAttribute('aria-current', 'page'); }
          else { a.classList.remove('active'); a.removeAttribute('aria-current'); }
        } catch (e) {}
      });
    } catch (e) { console.error('updateActiveNavLinks', e); }
  }
// ---------- Prefetching ----------
  const prefetch = debounce((href) => {
    try {
      if (!href || !isSameOrigin(href)) return;
      if (pageCache.has(href)) return; // already cached
      if (prefetchControllers.has(href)) return; // already prefetching
const ac = new AbortController();
      prefetchControllers.set(href, ac);
      fetch(href, { signal: ac.signal, credentials: 'same-origin' })
        .then(res => { if (!res.ok) throw new Error('Network response not ok'); return res.text(); })
        .then(html => {
          try {
            const doc = parseHTML(html);
            const title = doc.querySelector('title')?.textContent || '';
            const main = doc.querySelector(mainSelector)?.innerHTML || '';
            pageCache.set(href, { html, title, main });
          } catch (e) { /* parsing error */ }
        })
        .catch(() => {})
        .finally(() => prefetchControllers.delete(href));
    } catch (e) { console.error('prefetch error', e); }
  }, 80);
function addPrefetchListeners() {
    // Prefetch on hover/focus for internal links
    document.body.addEventListener('mouseover', (e) => {
      const a = e.target.closest('a');
      if (!a) return;
      const href = a.href;
      prefetch(href);
    }, { passive: true });

    document.body.addEventListener('focusin', (e) => {
      const a = e.target.closest('a');
      if (!a) return;
      prefetch(a.href);
    });
  }

  // ---------- Page Fetching & Swap ----------
  async function fetchPage(href) {
    try {
      // Cancel any ongoing fetch
      if (currentController) currentController.abort();
      currentController = new AbortController();

      // Use cached if present
      if (pageCache.has(href)) return pageCache.get(href);

      const res = await fetch(href, { signal: currentController.signal, credentials: 'same-origin' });
      if (!res.ok) throw new Error('Network error ' + res.status);
      const text = await res.text();
      const doc = parseHTML(text);
      const title = doc.querySelector('title')?.textContent || '';
      const main = doc.querySelector(mainSelector)?.innerHTML || '';
      const payload = { html: text, title, main };
      pageCache.set(href, payload);
      return payload;
    } catch (e) {
      if (e.name === 'AbortError') throw e;
      console.error('fetchPage error', e);
      throw e;
    } finally { currentController = null; }
  }

  function serializeScroll() {
    return { x: window.scrollX, y: window.scrollY }; 
  }

  function restoreScroll(pos) {
    if (!pos) return window.scrollTo(0, 0);
    window.scrollTo(pos.x || 0, pos.y || 0);
  }

  async function navigateTo(href, opts = {}) {
    if (!href) return;
    if (!isSameOrigin(href)) return (location.href = href); // external - full navigation

    // Avoid navigating to same hash on same page
    const cur = location.href.split('#')[0];
    const destNoHash = href.split('#')[0];
    if (cur === destNoHash && href.includes('#')) {
      // Just jump to anchor
      const id = href.split('#')[1];
      const target = document.getElementById(id);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        history.pushState({ url: href, scroll: serializeScroll() }, '', href);
      }
      return;
    }

    try {
      progress.show();
      progress.setWidth(6);

      // Trigger exit animation
      if (mainEl) mainEl.classList.add('page-exit');
      await timeout(180); // give CSS time for exit

      // Save current scroll into history state
      const prevState = history.state || {};
      history.replaceState(Object.assign({}, prevState, { scroll: serializeScroll() }), '', location.href);

      const payload = await fetchPage(href);

      // Swap title
      if (payload.title) document.title = payload.title;

      // Replace main content safely
      if (mainEl) {
        try {
          mainEl.innerHTML = payload.main || payload.html || '';
        } catch (e) {
          console.error('Error replacing main content', e);
          mainEl.innerHTML = payload.main || '';
        }
      }

      // Update history
      history.pushState({ url: href, scroll: { x: 0, y: 0 } }, '', href);

      // Update active nav links
      updateActiveNavLinks();

      // Run lightweight reinit for new content
      runPostNavigationInit();

      // entrance animation
      if (mainEl) {
        mainEl.classList.remove('page-exit');
        mainEl.classList.add('page-enter');
        // force reflow then remove class to trigger animation
        void mainEl.offsetWidth;
        setTimeout(() => mainEl.classList.remove('page-enter'), 700);
      }

      // finalize progress
      progress.setWidth(100);
      await timeout(220);
      progress.hide();

      // Fire custom event
      document.dispatchEvent(new CustomEvent('xodus:navigateComplete', { detail: { url: href } }));

    } catch (e) {
      progress.hide();
      // If fetch aborted, do nothing
      if (e.name === 'AbortError') return;

      console.error('Navigation failed, falling back to full navigation', e);
      // Show basic error overlay then fallback
      showErrorOverlay('Failed to load page. Redirecting...');
      setTimeout(() => location.href = href, 900);
    }
  }

  // ---------- Helpers ----------
  const timeout = (ms) => new Promise(res => setTimeout(res, ms));
function showErrorOverlay(message) {
    try {
      let overlay = $('#transition-error-overlay');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'transition-error-overlay';
        overlay.style.position = 'fixed';
        overlay.style.left = '0';
        overlay.style.top = '0';
        overlay.style.right = '0';
        overlay.style.bottom = '0';
        overlay.style.zIndex = '99999';
        overlay.style.display = 'flex';
        overlay.style.alignItems = 'center';
        overlay.style.justifyContent = 'center';
        overlay.style.background = 'rgba(0,0,0,0.85)';
        overlay.style.color = '#fff';
        overlay.style.fontSize = '18px';
        overlay.style.padding = '20px';
        overlay.innerHTML = `<div>${escapeHtml(message)}</div>`;
        document.body.appendChild(overlay);
      }
      overlay.style.opacity = '0';
      setTimeout(() => overlay.style.opacity = '1', 10);
function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":"&#39;" })[c]);
  }

  // Execute script tags within replaced content (limited and safe)
  function runInlineScripts(scope = mainEl) {
    try {
      if (!scope) return;
      const scripts = Array.from(scope.querySelectorAll('script'));
      scripts.forEach(old => {
        const src = old.getAttribute('src');
        const type = old.getAttribute('type');
        if (type && type !== 'text/javascript' && type !== 'application/javascript') return;
        const script = document.createElement('script');
        if (src) {
          script.src = src;
          script.async = false;
        } else {
          script.textContent = old.textContent;
        }
        old.parentNode.replaceChild(script, old);
      });
    } catch (e) { console.error('runInlineScripts', e); }
  }
// ---------- Post-navigation initialization ----------
  function runPostNavigationInit() {
    try {
      // Update active navs
      updateActiveNavLinks();

      // Re-enable prefetch listeners for new anchors
      // (listeners are global so no-op)

      // Execute potential inline scripts inserted inside main content
      runInlineScripts(mainEl);

      // Reveal animation for elements tagged with data-animate
      const animated = $$('[data-animate]', mainEl);
      animated.forEach((el, idx) => {
        el.classList.remove('in-view');
        // stagger
        setTimeout(() => el.classList.add('in-view'), 80 * idx);
      });

      // Re-init lightweight features: forms, lazy images, focus anchors
      initLightFormValidation(mainEl);
      initLazyImages(mainEl);

      // Focus first heading for accessibility
      const heading = mainEl.querySelector('h1, h2, [data-focus-after]');
      if (heading) {
        heading.setAttribute('tabindex', '-1');
        safeFocus(heading);
        setTimeout(() => heading.removeAttribute('tabindex'), 800);
      }
    } catch (e) { console.error('runPostNavigationInit', e); }
  }

  // Lightweight form validation and handling for common newsletter/contact forms
  function initLightFormValidation(scope = document) {
    try {
      const forms = scope.querySelectorAll('form');
      if (!forms.length) return;
      forms.forEach(form => {
        // only attach once
        if (form._xodusValidated) return; form._xodusValidated = true;
form.addEventListener('submit', (e) => {
          try {
            const required = form.querySelectorAll('[required]');
            let ok = true;
            required.forEach(el => {
              if (!el.value || String(el.value).trim() === '') { ok = false; showInlineFormError(el, 'This field is required'); }
              else clearInlineFormError(el);
              if (el.type === 'email' && el.value) {
                if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(el.value)) { ok = false; showInlineFormError(el, 'Enter a valid email'); }
              }
            });
            if (!ok) { e.preventDefault(); e.stopImmediatePropagation(); const firstErr = form.querySelector('.input-error'); if (firstErr) safeFocus(firstErr); }
          } catch (err) { console.error('form submit validation', err); }
        });

        form.addEventListener('input', (e) => { clearInlineFormError(e.target); });
      });
    } catch (e) { console.error('initLightFormValidation', e); }
  }

  function showInlineFormError(el, msg) {
    try {
      if (!el) return;
      el.classList.add('input-error');
      el.setAttribute('aria-invalid', 'true');
      let node = el.nextElementSibling;
      if (!node || !node.classList || !node.classList.contains('field-error')) {
        node = document.createElement('div'); node.className = 'field-error'; el.parentNode.insertBefore(node, el.nextSibling);
      }
      node.textContent = msg;
    } catch (e) { console.error('showInlineFormError', e); }
  }
function clearInlineFormError(el) {
    try {
      if (!el) return;
      el.classList.remove('input-error');
      el.removeAttribute('aria-invalid');
      const node = el.nextElementSibling; if (node && node.classList && node.classList.contains('field-error')) node.textContent = '';
    } catch (e) { /* noop */ }
  }
// Lazy load images within a container
  function initLazyImages(scope = document) {
    try {
      const imgs = Array.from(scope.querySelectorAll('img[data-src]'));
      if (!imgs.length) return;
      if (!('IntersectionObserver' in window)) { imgs.forEach(i => { i.src = i.getAttribute('data-src'); i.removeAttribute('data-src'); }); return; }
      const io = new IntersectionObserver((entries, obs) => {
        entries.forEach(entry => {
          if (!entry.isIntersecting) return;
          const img = entry.target;
          const src = img.getAttribute('data-src');
          if (src) { img.src = src; img.removeAttribute('data-src'); }
          obs.unobserve(img);
        });
      }, { rootMargin: '160px 0px' });
      imgs.forEach(img => io.observe(img));
    } catch (e) { console.error('initLazyImages', e); }
  }
// ---------- Delegated link handling ----------
  function initLinkInterception() {
    // Intercept clicks on same-origin internal links and handle transitions
    document.body.addEventListener('click', (e) => {
      const a = e.target.closest('a');
      if (!a) return;
      // ignore downloads, external, anchors with data-no-ajax
      if (a.hasAttribute('download') || a.getAttribute('target') === '_blank' || a.dataset.noAjax !== undefined) return;
      const href = a.href;
      if (!href || !isSameOrigin(href)) return;
// allow anchor hash navigation without full AJAX fetch if same page
      const curBase = location.href.split('#')[0];
      const destBase = href.split('#')[0];
      e.preventDefault();
      if (curBase === destBase) {
        // only scroll to anchor
        const hash = href.split('#')[1]; if (hash) { const target = document.getElementById(hash); if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' }); history.pushState({}, '', href); }
        return;
      }

      // perform SPA-like navigation
      navigateTo(href);
    });

    // Back/forward support
    window.addEventListener('popstate', async (e) => {
      try {
        const state = e.state || {};
        const url = state.url || location.href;
        // re-fetch and swap content
        progress.show();
        const payload = await fetchPage(url).catch(() => null);
        if (!payload) return location.reload();
        if (mainEl) mainEl.innerHTML = payload.main || '';
        document.title = payload.title || document.title;
        runPostNavigationInit();
        progress.hide();
      } catch (err) {
        console.error('popstate handler error', err);
      }
    });
  }
// ---------- Initialization ----------
  function init() {
    try {
      // init components
      initMobileToggles();
      addPrefetchListeners();
      initLinkInterception();
      // initial active link update
      updateActiveNavLinks();
      // run a post-navigation init on load
      runPostNavigationInit();
    } catch (e) { console.error('transitions init error', e); }
  }

  // Kick-off
  document.addEventListener('DOMContentLoaded', () => {
    try { init(); } catch (err) { console.error('transitions DOMContentLoaded error', err); }
  });

  // Expose API for debugging or advanced usage
  window.XodusTransitions = {
    navigateTo,
    prefetch: (u) => prefetch(u),
    cache: pageCache,
    clearCache: () => pageCache.clear(),
  };

})();