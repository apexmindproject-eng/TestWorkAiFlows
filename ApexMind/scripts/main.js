// main.js - Core JavaScript for ApexMind Web Application
// Provides global navigation, form validation, UI behaviors, accessibility, and performance optimizations

'use strict';

(() => {
  // --- Cache global DOM references ---
  const body = document.body;
  const header = document.getElementById('site-header');
  const nav = document.getElementById('main-navigation');
  const navList = nav ? nav.querySelector('.nav-list') : null;

  // --- Utility Functions ---

  // Debounce to limit frequency of function calls
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
// Smooth scroll to element
  const smoothScrollTo = (target) => {
    if (!target) return;
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  // Check if element exists
  const exists = (el) => el !== null && el !== undefined;

  // Set ARIA-invalid attribute on inputs based on validity
  const setInputValidity = (input) => {
    if (!exists(input)) return;
    input.setAttribute('aria-invalid', input.checkValidity() ? 'false' : 'true');
  };

  // --- Navigation ---

  // Highlights the current page link in the nav
  const highlightActiveNav = () => {
    try {
      if (!navList) return;
      const currentPath = window.location.pathname.split('/').pop() || 'homepage.html';
navList.querySelectorAll('.nav-link').forEach(link => {
        // Normalize link href to filename
        const href = link.getAttribute('href').replace(/\s+/g, ' ').trim();
        if (href === currentPath) {
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

  // Mobile navigation toggle button creation and management
  let mobileNavToggleBtn = null;
  const createMobileNavToggle = () => {
    try {
      if (!nav || document.getElementById('mobile-nav-toggle')) return;
mobileNavToggleBtn = document.createElement('button');
      mobileNavToggleBtn.id = 'mobile-nav-toggle';
      mobileNavToggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      mobileNavToggleBtn.className = 'mobile-nav-toggle';
      // Hamburger icon markup
      mobileNavToggleBtn.innerHTML = '<span class="hamburger-line"></span><span class="hamburger-line"></span><span class="hamburger-line"></span>';

      const container = header.querySelector('.container') || header;
      container.insertBefore(mobileNavToggleBtn, nav);

      mobileNavToggleBtn.addEventListener('click', () => {
        const expanded = mobileNavToggleBtn.getAttribute('aria-expanded') === 'true';
        mobileNavToggleBtn.setAttribute('aria-expanded', String(!expanded));
        nav.classList.toggle('nav-open');
        body.classList.toggle('no-scroll');
      });
// Close nav when clicking outside
      document.addEventListener('click', e => {
        if (!nav.classList.contains('nav-open')) return;
        if (e.target === mobileNavToggleBtn || nav.contains(e.target)) return;

        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      });

      // Close nav on Esc key
      document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && nav.classList.contains('nav-open')) {
          nav.classList.remove('nav-open');
          body.classList.remove('no-scroll');
          if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
          mobileNavToggleBtn.focus();
        }
      });

    } catch (error) {
      console.error('Error creating mobile nav toggle:', error);
    }
  };

  // --- Accessibility Features ---

  // Insert skip link for keyboard users
  const addSkipToMainLink = () => {
    if (document.getElementById('skip-to-main')) return;
    const skipLink = document.createElement('a');
    skipLink.id = 'skip-to-main';
    skipLink.href = '#main-content';
    skipLink.className = 'skip-link visually-hidden-focusable';
    skipLink.textContent = 'Skip to main content';
    body.insertBefore(skipLink, body.firstChild);
  };

  // Keyboard nav enhancement for nav links
  const enhanceNavKeyboardSupport = () => {
    if (!navList) return;
    navList.addEventListener('keydown', e => {
      const links = Array.from(navList.querySelectorAll('.nav-link'));
      let currentIndex = links.indexOf(document.activeElement);
      if (currentIndex === -1) return;
if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault();
        const nextIndex = (currentIndex + 1) % links.length;
        links[nextIndex].focus();
      } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        e.preventDefault();
        const prevIndex = (currentIndex - 1 + links.length) % links.length;
        links[prevIndex].focus();
      }
    });
  };

  // --- Form Validation Enhancements ---

  // Generic function to validate forms and enhance UX
  const enhanceFormValidation = () => {
    try {
      const forms = document.querySelectorAll('form');

      forms.forEach(form => {
        // Validate on submit
        form.addEventListener('submit', e => {
          if (!form.checkValidity()) {
            e.preventDefault();
            form.reportValidity();
          }
        });
// Input real-time validation
        const inputs = form.querySelectorAll('input, textarea, select');
        inputs.forEach(input => {
          input.addEventListener('input', () => {
            setInputValidity(input);
          });

          // Initialize ARIA-invalid
          setInputValidity(input);
        });
      });
    } catch (error) {
      console.error('Error enhancing form validation:', error);
    }
  };

  // --- Smooth Scrolling Support for anchor links ---
  const setupSmoothScrolling = () => {
    try {
      document.addEventListener('click', e => {
        if (e.target.tagName !== 'A') return;
        const href = e.target.getAttribute('href') || '';
        if (!href.startsWith('#') || href === '#') return;
const target = document.querySelector(href);
        if (target) {
          e.preventDefault();
          smoothScrollTo(target);
          target.setAttribute('tabindex', '-1');
          target.focus({ preventScroll: true });
        }
      });
    } catch (error) {
      console.error('Error setting up smooth scrolling:', error);
    }
  };

  // --- Focus Main Content after load for accessibility ---
  const focusMainContent = () => {
    const main = document.getElementById('main-content');
    if (main) {
      main.setAttribute('tabindex', '-1');
      main.focus();
    }
  };
// --- Lazy Loading Images for Performance ---
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
        images.forEach(img => {
          img.src = img.dataset.src;
          img.removeAttribute('data-src');
        });
      }
    } catch (error) {
      console.warn('Lazy loading not supported or failed:', error);
    }
  };
// --- Manage interactive UI components globally ---

  // Example: Collapsible section toggle logic
  const setupCollapsibleSections = () => {
    try {
      document.body.addEventListener('click', e => {
        const toggleBtn = e.target.closest('[data-toggle="collapsible"]');
        if (toggleBtn) {
          e.preventDefault();
          const targetSelector = toggleBtn.getAttribute('data-target');
          if (!targetSelector) return;
          const content = document.querySelector(targetSelector);
          if (!content) return;
          const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
          toggleBtn.setAttribute('aria-expanded', String(!expanded));
          content.hidden = expanded;
        }
      });
    } catch (error) {
      console.error('Error setting up collapsible sections:', error);
    }
  };
// --- Initialization ---
  const init = () => {
    highlightActiveNav();
    createMobileNavToggle();
    addSkipToMainLink();
    enhanceNavKeyboardSupport();
    enhanceFormValidation();
    setupSmoothScrolling();
    lazyLoadImages();
    setupCollapsibleSections();
    focusMainContent();

    // Responsive cleanup
    window.addEventListener('resize', debounce(() => {
      if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      }
    }, 250));
  };

  // Activate on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', init);

})();

//# sourceURL=main.js