// main.js - Core JS for ApexMind professional website
// Handles global navigation, accessibility, mobile menu toggle, active link highlighting,
// form validation, interactive UI components and performance optimizations

'use strict';

(() => {
  // Cache DOM elements used globally
  const body = document.body;
  const header = document.getElementById('site-header');
  const nav = document.getElementById('main-navigation');
  const navList = nav ? nav.querySelector('.nav-list') : null;

  // Utility: Debounce to limit function calls
  const debounce = (func, wait, immediate = false) => {
    let timeout;
    return function(...args) {
      const context = this;
      const later = () => {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      const callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  };
// Smooth scroll utility
  const smoothScrollTo = target => {
    if (!target) return;
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  // --- Navigation & UI ---

  // Highlight active nav link based on current page URL
  const highlightActiveNav = () => {
    try {
      if (!navList) return;
      const currentPage = window.location.pathname.split('/').pop() || 'index.html';
      navList.querySelectorAll('.nav-link').forEach(link => {
        let href = link.getAttribute('href');
        href = href ? href.trim() : '';
        if (href === currentPage) {
          link.classList.add('current');
          link.setAttribute('aria-current', 'page');
        } else {
          link.classList.remove('current');
          link.removeAttribute('aria-current');
        }
      });
    } catch (error) {
      console.error('Error highlighting active navigation:', error);
    }
  };
// Create mobile nav toggle button and setup toggle behavior
  let mobileNavToggleBtn = null;
  const createMobileNavToggle = () => {
    try {
      if (!nav || document.getElementById('mobile-nav-toggle')) return;

      mobileNavToggleBtn = document.createElement('button');
      mobileNavToggleBtn.id = 'mobile-nav-toggle';
      mobileNavToggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      mobileNavToggleBtn.className = 'mobile-nav-toggle';
      mobileNavToggleBtn.innerHTML = '<span class="hamburger-line"></span><span class="hamburger-line"></span><span class="hamburger-line"></span>';

      const container = header.querySelector('.container') || header;
      container.insertBefore(mobileNavToggleBtn, nav);

      mobileNavToggleBtn.addEventListener('click', () => {
        const expanded = mobileNavToggleBtn.getAttribute('aria-expanded') === 'true';
        mobileNavToggleBtn.setAttribute('aria-expanded', String(!expanded));
        nav.classList.toggle('nav-open');
        body.classList.toggle('no-scroll');
      });

      // Close menu on outside click
      document.addEventListener('click', e => {
        if (!nav.classList.contains('nav-open')) return;
        if (e.target === mobileNavToggleBtn || nav.contains(e.target)) return;

        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      });

      // Close nav on ESC key press
      document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && nav.classList.contains('nav-open')) {
          nav.classList.remove('nav-open');
          body.classList.remove('no-scroll');
          if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
          mobileNavToggleBtn.focus();
        }
      });
    } catch (error) {
      console.error('Error setting up mobile nav toggle:', error);
    }
  };
// Enhance keyboard navigation on main nav (arrow keys for menu)
  const enhanceNavKeyboard = () => {
    try {
      if (!navList) return;
      navList.addEventListener('keydown', e => {
        const links = Array.from(navList.querySelectorAll('.nav-link'));
        let index = links.indexOf(document.activeElement);
        if (index < 0) return;

        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
          e.preventDefault();
          index = (index + 1) % links.length;
          links[index].focus();
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
          e.preventDefault();
          index = (index - 1 + links.length) % links.length;
          links[index].focus();
        }
      });
    } catch (error) {
      console.error('Error enhancing nav keyboard navigation:', error);
    }
  };
// --- Accessibility ---
  // Add skip to main content link for keyboard users
  const addSkipToContentLink = () => {
    if (document.getElementById('skip-to-main')) return;
    const skipLink = document.createElement('a');
    skipLink.id = 'skip-to-main';
    skipLink.href = '#main-content';
    skipLink.className = 'skip-link visually-hidden-focusable';
    skipLink.textContent = 'Skip to main content';
    body.insertBefore(skipLink, body.firstChild);
  };

  // Focus main content on page load for screen reader users
  const focusMainContent = () => {
    const mainContent = document.getElementById('main-content');
    if (mainContent) {
      mainContent.setAttribute('tabindex', '-1');
      mainContent.focus();
    }
  };

  // --- Form validation enhancement ---

  // Validate forms on submit, show native UI and improve aria-invalid attributes
  const enhanceFormValidation = () => {
    try {
      const forms = document.querySelectorAll('form');
      forms.forEach(form => {
        form.addEventListener('submit', e => {
          if (!form.checkValidity()) {
            e.preventDefault();
            form.reportValidity();
          }
        });

        // Update aria-invalid on inputs based on validity on input
        form.querySelectorAll('input, textarea, select').forEach(input => {
          const updateAriaInvalid = () => {
            input.setAttribute('aria-invalid', input.checkValidity() ? 'false' : 'true');
          };
          input.addEventListener('input', updateAriaInvalid);
          updateAriaInvalid(); // initial
        });
      });
    } catch (error) {
      console.error('Error enhancing form validation:', error);
    }
  };
// --- Smooth scrolling ---
  const setupSmoothScrolling = () => {
    try {
      document.addEventListener('click', e => {
        if (e.target.tagName !== 'A') return;
        const href = e.target.getAttribute('href');
        if (!href || !href.startsWith('#') || href === '#') return;

        const target = document.querySelector(href);
        if (target) {
          e.preventDefault();
          smoothScrollTo(target);
          // Make focusable for screen readers
          target.setAttribute('tabindex', '-1');
          target.focus({ preventScroll: true });
        }
      });
    } catch (error) {
      console.error('Error setting up smooth scrolling:', error);
    }
  };
// --- Lazy load images ---
  const lazyLoadImages = () => {
    try {
      const images = document.querySelectorAll('img[data-src]');
      if ('loading' in HTMLImageElement.prototype) {
        images.forEach(img => {
          if (!img.src) {
            img.src = img.dataset.src;
            img.removeAttribute('data-src');
          }
        });
      } else if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver((entries, observer) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const img = entry.target;
              img.src = img.dataset.src;
              img.removeAttribute('data-src');
              observer.unobserve(img);
            }
          });
        });
        images.forEach(img => observer.observe(img));
      } else {
        // Fallback load all images immediately
        images.forEach(img => {
          img.src = img.dataset.src;
          img.removeAttribute('data-src');
        });
      }
    } catch (error) {
      console.warn('Lazy loading images failed:', error);
    }
  };
// --- Example of interactive UI component: expandable content toggles ---
  const setupExpandableSections = () => {
    try {
      document.body.addEventListener('click', e => {
        const toggle = e.target.closest('[data-toggle="expandable"]');
        if (!toggle) return;

        e.preventDefault();
        const targetSelector = toggle.getAttribute('data-target');
        if (!targetSelector) return;
        const content = document.querySelector(targetSelector);
        if (!content) return;

        const expanded = toggle.getAttribute('aria-expanded') === 'true';
        toggle.setAttribute('aria-expanded', String(!expanded));
        content.hidden = expanded;
      });
    } catch (error) {
      console.error('Error setting up expandable sections:', error);
    }
  };
// --- Initialize all functionality ---
  const init = () => {
    highlightActiveNav();
    createMobileNavToggle();
    enhanceNavKeyboard();
    addSkipToContentLink();
    focusMainContent();
    enhanceFormValidation();
    setupSmoothScrolling();
    lazyLoadImages();
    setupExpandableSections();

    // Responsive behavior: close mobile nav if resizing to desktop
    window.addEventListener('resize', debounce(() => {
      if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      }
    }, 250));
  };

  document.addEventListener('DOMContentLoaded', init);
})();

//# sourceURL=main.js