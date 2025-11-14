/* main.js - Core functionality for Xodus Studios
 * Applies across all pages: navigation, accessibility, forms, animations, utilities.
 * Modern ES6+, defensive coding, and performance-minded.
 */

(() => {
  'use strict';

  /* ----------------------------- Utilities ------------------------------ */
  const $ = (sel, scope = document) => scope.querySelector(sel) || null;
  const $$ = (sel, scope = document) => Array.from(scope.querySelectorAll(sel));

  const noop = () => {};

  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);

  const debounce = (fn, wait = 100) => {
    let t = null;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...args), wait);
    };
  };

  const throttle = (fn, limit = 100) => {
    let last = 0;
    return (...args) => {
      const now = Date.now();
      if (now - last >= limit) {
        last = now;
        fn(...args);
      }
    };
  };
const isHidden = (el) => !el || (el.offsetParent === null && getComputedStyle(el).position !== 'fixed');

  // Simple accessible focus helper
  const safeFocus = (el) => {
    try {
      if (el && typeof el.focus === 'function') el.focus();
    } catch (e) {
      // ignore
    }
  };

  /* -------------------------- Global variables -------------------------- */
  const body = document.body;
  const header = $('#site-header');
  const mobileToggleSelector = '#mobile-menu-toggle, .mobile-menu-toggle';
  const MOBILE_BREAKPOINT = 900; // px - used to auto close mobile menu on resize

  /* ---------------------- Mobile Navigation Toggle ---------------------- */
  function initMobileMenu() {
    const toggles = Array.from(document.querySelectorAll(mobileToggleSelector));
    if (!toggles.length) return;
toggles.forEach(toggle => {
      try {
        // Find the menu this toggle controls
        const controlsId = toggle.getAttribute('aria-controls');
        const menu = controlsId ? document.getElementById(controlsId) : document.querySelector('.main-nav, .primary-nav, #main-nav');
        if (!menu) return;

        // Ensure initial ARIA state
        toggle.setAttribute('aria-expanded', 'false');
        menu.setAttribute('data-mobile', 'true');
        menu.setAttribute('aria-hidden', 'true');

        // click handler
        toggle.addEventListener('click', (e) => {
          e.preventDefault();
          const expanded = toggle.getAttribute('aria-expanded') === 'true';
          if (expanded) closeMobileMenu(toggle, menu);
          else openMobileMenu(toggle, menu);
        });
// Close menu if focus moves outside when open
        document.addEventListener('click', (e) => {
          if (!menu.classList.contains('is-open')) return;
          // Click outside menu and toggle -> close
          if (!menu.contains(e.target) && !toggle.contains(e.target)) {
            closeMobileMenu(toggle, menu);
          }
        });

        // Close on escape
        document.addEventListener('keydown', (e) => {
          if (e.key === 'Escape' && menu.classList.contains('is-open')) {
            closeMobileMenu(toggle, menu);
            toggle.focus();
          }
        });

        // Close on resize above breakpoint
        window.addEventListener('resize', debounce(() => {
          try {
            if (window.innerWidth > MOBILE_BREAKPOINT && menu.classList.contains('is-open')) {
              closeMobileMenu(toggle, menu);
            }
          } catch (err) {
            // ignore
          }
        }, 200));
function getFocusable(root) {
    const sel = 'a[href], area[href], input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])';
    return Array.from(root.querySelectorAll(sel)).filter(el => el.offsetParent !== null || getComputedStyle(el).position === 'fixed');
  }

  function openMobileMenu(toggle, menu) {
    try {
      toggle.setAttribute('aria-expanded', 'true');
      menu.classList.add('is-open');
      menu.setAttribute('aria-hidden', 'false');
      document.documentElement.classList.add('no-scroll');
      // Focus first element in menu
      const focusable = getFocusable(menu);
      if (focusable.length) safeFocus(focusable[0]);
    } catch (err) {
      console.error('openMobileMenu error:', err);
    }
  }
function closeMobileMenu(toggle, menu) {
    try {
      toggle.setAttribute('aria-expanded', 'false');
      menu.classList.remove('is-open');
      menu.setAttribute('aria-hidden', 'true');
      document.documentElement.classList.remove('no-scroll');
    } catch (err) {
      console.error('closeMobileMenu error:', err);
    }
  }

  /* ---------------------- Active Nav Link Detection --------------------- */
  function initActiveNavLinks() {
    try {
      const links = $$('a.nav-link');
      if (!links.length) return;

      // Normalize path (remove leading /pages/ for multi-dir setups)
      let path = window.location.pathname.replace(/\/pages\//, '/');
      path = path.replace(/\/index\.html$/, '/').replace(/\/$/, '') || '/';
links.forEach(a => {
        try {
          const href = a.getAttribute('href') || '';
          const url = new URL(href, window.location.origin);
          let linkPath = url.pathname.replace(/\/pages\//, '/').replace(/\/$/, '') || '/';
          if (linkPath === path) {
            a.classList.add('active');
            a.setAttribute('aria-current', 'page');
          } else {
            a.classList.remove('active');
            a.removeAttribute('aria-current');
          }
        } catch (err) {
          // ignore malformed href
        }
      });
    } catch (err) {
      console.error('Active nav init error:', err);
    }
  }

  /* ---------------------------- Skip Link ------------------------------- */
  function initSkipLink() {
    const skip = $('.skip-link');
    if (!skip) return;

    skip.addEventListener('click', (e) => {
      try {
        const targetId = skip.getAttribute('href')?.replace('#', '');
        const target = targetId ? document.getElementById(targetId) : document.getElementById('main-content');
        if (target) {
          target.setAttribute('tabindex', '-1');
          safeFocus(target);
          // Remove tabindex after focus to keep DOM tidy
          window.setTimeout(() => target.removeAttribute('tabindex'), 1000);
        }
      } catch (err) {
        console.error('Skip link error:', err);
      }
    });
  }
/* --------------------------- Smooth Scroll ---------------------------- */
  function initSmoothAnchors() {
    document.body.addEventListener('click', (e) => {
      const a = e.target.closest('a[href^="#"]');
      if (!a) return;
      const hash = a.getAttribute('href');
      if (!hash || hash.length === 1) return; // '#' only

      const id = hash.slice(1);
      const target = document.getElementById(id);
      if (!target) return;
      e.preventDefault();

      // If mobile menu is open, close it first
      const openMenu = document.querySelector('.is-open');
      if (openMenu) {
        const toggle = document.querySelector(mobileToggleSelector);
        if (toggle) closeMobileMenu(toggle, openMenu);
      }
// Scroll with offset for fixed header
      const headerHeight = header ? header.offsetHeight : 0;
      const top = Math.max(0, target.getBoundingClientRect().top + window.scrollY - headerHeight - 12);
      window.scrollTo({ top, behavior: 'smooth' });
      history.pushState(null, '', `#${id}`);
    });
  }

  /* --------------------------- Sticky Header ---------------------------- */
  function initStickyHeader() {
    if (!header) return;
    const onScroll = throttle(() => {
      const scrolled = window.scrollY > 30;
      header.classList.toggle('scrolled', scrolled);
    }, 100);
    window.addEventListener('scroll', onScroll);
  }

  /* ------------------------- In-view Animations ------------------------- */
  function initInViewAnimations() {
    const animated = $$('[data-animate]');
    if (!animated.length) return;

    if (!('IntersectionObserver' in window)) {
      // Fallback: reveal all
      animated.forEach(el => el.classList.add('in-view'));
      return;
    }

    const io = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('in-view');
          obs.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });

    animated.forEach(el => io.observe(el));
  }

  /* -------------------------- Newsletter Form -------------------------- */
  function initNewsletterForm() {
    const form = $('#newsletter-form');
    if (!form) return;

    const email = $('#newsletter-email', form) || form.querySelector('input[type="email"]');
    const status = document.createElement('div');
    status.className = 'newsletter-status sr-only';
    status.setAttribute('aria-live', 'polite');
    form.appendChild(status);
const showMessage = (msg, isError = false) => {
      status.className = `newsletter-status ${isError ? 'error' : 'success'}`;
      status.textContent = msg;
      // For visible feedback, also raise a small toast if CSS provides it
      const toast = document.createElement('div');
      toast.className = `toast ${isError ? 'toast-error' : 'toast-success'}`;
      toast.textContent = msg;
      document.body.appendChild(toast);
      setTimeout(() => toast.classList.add('visible'), 10);
      setTimeout(() => { toast.classList.remove('visible'); setTimeout(() => toast.remove(), 300); }, 4000);
    };

    const isValidEmail = (v) => {
      if (!v) return false;
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
    };

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      try {
        const val = email ? email.value.trim() : '';
        if (!isValidEmail(val)) {
          showMessage('Please enter a valid email address.', true);
          if (email) email.focus();
          return;
        }

        // Simulate network request; if form has action, attempt to POST
        const action = form.getAttribute('action') || '#';
        const method = (form.getAttribute('method') || 'POST').toUpperCase();

        // If action is '#', just simulate success
        if (action === '#' || action === '') {
          showMessage('Thanks! You are subscribed to the newsletter.');
          form.reset();
          return;
        }
// Attempt to send via fetch (graceful failure)
        fetch(action, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: val }) })
          .then(res => {
            if (!res.ok) throw new Error('Network response was not ok');
            return res.json().catch(() => ({}));
          })
          .then(() => {
            showMessage('Thanks! You are subscribed to the newsletter.');
            form.reset();
          })
          .catch(err => {
            console.warn('Newsletter submit failed:', err);
            showMessage('Subscription failed. Please try again later.', true);
          });

      } catch (err) {
        console.error('Newsletter form error:', err);
      }
    });
  }

  /* -------------------------- Generic Forms ----------------------------- */
  // Attach simple validation to any form with data-validate="true"
  function initGenericForms() {
    const forms = $$('form[data-validate="true"]');
    if (!forms.length) return;
forms.forEach(form => {
      form.addEventListener('submit', (e) => {
        try {
          const required = Array.from(form.querySelectorAll('[required]'));
          let valid = true;
          required.forEach(inp => {
            const val = (inp.value || '').trim();
            const name = inp.getAttribute('name') || 'field';
            // Email check
            if (inp.type === 'email') {
              if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)) {
                showInputError(inp, 'Please enter a valid email address');
                valid = false;
              } else clearInputError(inp);
            } else if (!val) {
              showInputError(inp, `Please complete the ${name} field`);
              valid = false;
            } else {
              clearInputError(inp);
            }
          });
if (!valid) {
            e.preventDefault();
            const firstErr = form.querySelector('.input-error, [aria-invalid="true"]');
            if (firstErr) safeFocus(firstErr);
          }
        } catch (err) {
          console.error('Form validation error:', err);
        }
      });

      // Live clear on input
      form.addEventListener('input', (e) => {
        const t = e.target;
        if (t && t.matches('input,textarea,select')) clearInputError(t);
      });
    });
  }

  function showInputError(elem, msg) {
    try {
      if (!elem) return;
      elem.classList.add('input-error');
      elem.setAttribute('aria-invalid', 'true');
      let hint = elem.nextElementSibling;
      if (!hint || !hint.classList.contains('error-message')) {
        hint = document.createElement('div');
        hint.className = 'error-message';
        elem.parentNode.insertBefore(hint, elem.nextSibling);
      }
      hint.textContent = msg;
    } catch (err) { console.error(err); }
  }
function clearInputError(elem) {
    try {
      if (!elem) return;
      elem.classList.remove('input-error');
      elem.removeAttribute('aria-invalid');
      const hint = elem.nextElementSibling;
      if (hint && hint.classList.contains('error-message')) hint.textContent = '';
    } catch (err) { console.error(err); }
  }
const modalClose = e.target.closest('[data-close-modal]');
      if (modalClose) {
        e.preventDefault();
        try {
          const modal = e.target.closest('.modal');
          if (modal) {
            modal.classList.remove('open');
            modal.setAttribute('aria-hidden', 'true');
            document.dispatchEvent(new Event('modalClosed'));
          }
        } catch (err) { console.error('data-close-modal error:', err); }
      }
    });
  }

  /* --------------------------- Global Setup ----------------------------- */
  function initGlobalErrorHandling() {
    window.addEventListener('error', (e) => {
      // Log via console for dev, could be sent to remote logging
      console.error('Global error:', e.message, 'at', `${e.filename}:${e.lineno}:${e.colno}`);
    });
    window.addEventListener('unhandledrejection', (e) => {
      console.error('Unhandled rejection:', e.reason);
    });
  }
/* ------------------------------ Init --------------------------------- */
  function init() {
    initGlobalErrorHandling();
    initMobileMenu();
    initActiveAndNav();
    initSkipLink();
    initSmoothAnchors();
    initStickyHeader();
    initInViewAnimations();
    initNewsletterForm();
    initGenericForms();
    initDelegatedActions();

    // Re-check active nav links when history changes (SPA-like navigation)
    window.addEventListener('popstate', debounce(initActiveAndNav, 80));
  }

  function initActiveAndNav() {
    initActiveNavLinks();
    // keyboard accessibility for nav lists
    initNavKeyboardSupport();
  }

  function initNavKeyboardSupport() {
    const navs = $$('.nav-list');
    navs.forEach(nav => {
      nav.addEventListener('keydown', (e) => {
        try {
          if (!['ArrowDown', 'ArrowUp', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
          const links = Array.from(nav.querySelectorAll('a.nav-link'));
          if (!links.length) return;
          const idx = links.indexOf(document.activeElement);
          if (idx === -1) return;
          e.preventDefault();
          if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
            links[(idx + 1) % links.length].focus();
          } else {
            links[(idx - 1 + links.length) % links.length].focus();
          }
        } catch (err) { console.error('nav keyboard support error:', err); }
      });
    });
  }
// Active nav links helper used internally
  function initActiveNavLinks() {
    try {
      const links = $$('a.nav-link');
      if (!links.length) return;

      let path = window.location.pathname;
      // normalize many possible setups: root/index.html or pages/
      path = path.replace(/\/index\.html$/, '/').replace(/\/pages\//, '/').replace(/\/$/, '');
      if (!path) path = '/';

      links.forEach(link => {
        try {
          const href = link.getAttribute('href') || '';
          const url = new URL(href, window.location.origin);
          let linkPath = url.pathname.replace(/\/index\.html$/, '/').replace(/\/pages\//, '/').replace(/\/$/, '');
          if (!linkPath) linkPath = '/';
if (linkPath === path) {
            link.classList.add('active');
            link.setAttribute('aria-current', 'page');
          } else {
            link.classList.remove('active');
            link.removeAttribute('aria-current');
          }
        } catch (err) {
          // Ignore malformed
        }
      });
    } catch (err) {
      console.error('initActiveNavLinks error:', err);
    }
  }

  /* ---------------------------- Boot up ------------------------------- */
  document.addEventListener('DOMContentLoaded', () => {
    try {
      init();
    } catch (err) {
      console.error('main.js init error:', err);
    }
  });

})();