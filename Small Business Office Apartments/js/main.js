// main.js - Core JavaScript for Small Business Office Apartments Website
// Handles navigation, global UI features, accessibility enhancements, and shared interactive behavior

// Use strict mode for cleaner JavaScript
'use strict';

// Immediately Invoked Function Expression (IIFE) for encapsulation
(() => {
  // Cache DOM elements used globally
  const body = document.body;
  const header = document.getElementById('site-header');
  const nav = document.getElementById('main-navigation');
  const navList = nav ? nav.querySelector('.nav-list') : null;
  const heroImage = document.getElementById('hero-image');
  const viewListingsBtn = document.getElementById('view-listings-btn');
// Utility: Debounce function to limit function calls
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

  // ===== Active Navigation Link Highlighting =====
  // Sets the current page navigation link as active (aria-current="page" and CSS class)
  function highlightActiveNav() {
    try {
      if (!navList) return;
      const links = navList.querySelectorAll('.nav-link');
      const currentPath = window.location.pathname.split('/').pop() || 'index.html';
links.forEach(link => {
        const href = link.getAttribute('href');
        if (!href) return;
        if (href === currentPath) {
          link.classList.add('current');
          link.setAttribute('aria-current', 'page');
        } else {
          link.classList.remove('current');
          link.removeAttribute('aria-current');
        }
      });
    } catch (error) {
      console.error('Error setting active navigation link:', error);
    }
  }

  // ===== Mobile Navigation Toggle =====
  // Create and manage mobile nav toggle button for responsive menus
  let mobileNavToggleBtn = null;

  function createMobileNavToggle() {
    try {
      if (!nav) return;

      // Check if toggle already exists
      if (document.getElementById('mobile-nav-toggle')) return;

      mobileNavToggleBtn = document.createElement('button');
      mobileNavToggleBtn.id = 'mobile-nav-toggle';
      mobileNavToggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      mobileNavToggleBtn.className = 'mobile-nav-toggle';
      mobileNavToggleBtn.innerHTML = '<span class="hamburger-line"></span><span class="hamburger-line"></span><span class="hamburger-line"></span>';

      // Insert toggle button before nav or inside header container
      const container = header.querySelector('.container');
      if (container) {
        container.insertBefore(mobileNavToggleBtn, nav);
      } else {
        header.insertBefore(mobileNavToggleBtn, nav);
      }
// Event listener for toggle
      mobileNavToggleBtn.addEventListener('click', () => {
        const expanded = mobileNavToggleBtn.getAttribute('aria-expanded') === 'true';
        mobileNavToggleBtn.setAttribute('aria-expanded', !expanded);
        nav.classList.toggle('nav-open'); // CSS class to open/close nav
        body.classList.toggle('no-scroll'); // Prevent body scroll when nav open
      });

      // Close mobile nav when clicking outside nav or on link
      document.addEventListener('click', event => {
        if (!nav.classList.contains('nav-open')) return;
        const target = event.target;
        if (target === mobileNavToggleBtn || nav.contains(target)) return;

        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      });

    } catch (error) {
      console.error('Error creating mobile navigation toggle:', error);
    }
  }

  // ===== Smooth Scrolling for Internal Links =====
  // Enhances anchor links scrolling behavior
  function smoothScrolling() {
    try {
      document.addEventListener('click', event => {
        const target = event.target;
        if (target.tagName !== 'A') return;
        const href = target.getAttribute('href');
        if (!href || !href.startsWith('#')) return;

        const scrollTarget = document.querySelector(href);
        if (scrollTarget) {
          event.preventDefault();
          scrollTarget.scrollIntoView({behavior: 'smooth', block: 'start'});
          // Optionally focus the target for accessibility
          scrollTarget.setAttribute('tabindex', '-1');
          scrollTarget.focus({preventScroll: true});
        }
      }, false);
    } catch (error) {
      console.error('Error in smooth scrolling:', error);
    }
  }
// ===== Accessibility Enhancements =====
  // Add skip to main content link for keyboard users
  function addSkipLink() {
    if (document.getElementById('skip-to-main')) return;
    const skipLink = document.createElement('a');
    skipLink.href = '#main-content';
    skipLink.id = 'skip-to-main';
    skipLink.className = 'skip-link visually-hidden-focusable';
    skipLink.textContent = 'Skip to main content';
    body.insertBefore(skipLink, body.firstChild);
  }
// ===== Image Lazy Loading =====
  // Lazy load large images for performance
  function lazyLoadImages() {
    try {
      if ('loading' in HTMLImageElement.prototype) {
        // Native lazy loading supported
        const images = document.querySelectorAll('img[data-src]');
        images.forEach(img => {
          if (!img.src) {
            img.src = img.dataset.src;
            img.removeAttribute('data-src');
          }
        });
      } else {
        // Fallback: Intersection Observer
        const images = document.querySelectorAll('img[data-src]');
        if ('IntersectionObserver' in window) {
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
          // Last resort: load all images immediately
          images.forEach(img => {
            img.src = img.dataset.src;
            img.removeAttribute('data-src');
          });
        }
      }
    } catch (error) {
      console.error('Error in lazy loading images:', error);
    }
  }
// ===== Hero Section Enhancements =====
  // Example: Link hero image click to listings page
  function setupHeroSection() {
    try {
      if (!heroImage || !viewListingsBtn) return;
      heroImage.style.cursor = 'pointer';
      heroImage.addEventListener('click', () => {
        // Navigate to listings page on hero image click
        window.location.href = viewListingsBtn.getAttribute('href');
      });

      // Accessibility: Allow keyboard enter to trigger link
      heroImage.tabIndex = 0;
      heroImage.addEventListener('keydown', event => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          window.location.href = viewListingsBtn.getAttribute('href');
        }
      });
    } catch (error) {
      console.error('Error setting up hero section:', error);
    }
  }

  // ===== Keyboard Navigation Enhancement for Menus =====
  function enhanceKeyboardNav() {
    try {
      if (!navList) return;

      navList.addEventListener('keydown', event => {
        const links = Array.from(navList.querySelectorAll('.nav-link'));
        let index = links.indexOf(document.activeElement);
        if (index === -1) return;

        switch(event.key) {
          case 'ArrowRight':
          case 'ArrowDown':
            event.preventDefault();
            index = (index + 1) % links.length;
            links[index].focus();
            break;
          case 'ArrowLeft':
          case 'ArrowUp':
            event.preventDefault();
            index = (index - 1 + links.length) % links.length;
            links[index].focus();
            break;
          default:
            break;
        }
      });
    } catch (error) {
      console.error('Error enhancing keyboard navigation:', error);
    }
  }
// ===== Form Enhancement for all forms with client-side validation and accessibility =====
  // Note: Basic HTML5 validation assumed; JS can enhance error messaging and UX
  function enhanceForms() {
    try {
      // Select all forms
      const forms = document.querySelectorAll('form');

      forms.forEach(form => {
        // On submit prevent default if invalid and show messages
        form.addEventListener('submit', event => {
          if (!form.checkValidity()) {
            event.preventDefault();
            form.reportValidity();
          }
          // Potentially add loading states, disable buttons here
        });

        // Enhance inputs with real-time validation and ARIA
        const inputs = form.querySelectorAll('input, textarea, select');

        inputs.forEach(input => {
          // Skip inputs without constraints
          if (!input.hasAttribute('required') && !input.getAttribute('pattern') && !input.getAttribute('type')) return;

          input.addEventListener('input', () => {
            if (input.validity.valid) {
              input.setAttribute('aria-invalid', 'false');
            } else {
              input.setAttribute('aria-invalid', 'true');
            }
          });
        });
      });
    } catch (error) {
      console.error('Error enhancing form validation:', error);
    }
  }

  // ===== Focus Management on Page Load =====
  function focusMainContent() {
    const mainContent = document.getElementById('main-content');
    if (mainContent) {
      mainContent.setAttribute('tabindex', '-1');
      mainContent.focus();
    }
  }
// ===== Initialization: Called once DOM is fully loaded =====
  const init = () => {
    try {
      addSkipLink();
      highlightActiveNav();
      createMobileNavToggle();
      smoothScrolling();
      lazyLoadImages();
      setupHeroSection();
      enhanceKeyboardNav();
      enhanceForms();
      focusMainContent();

      // Responsive adaptations if needed
      window.addEventListener('resize', debounce(() => {
        // Example: close mobile nav on resize if desktop width
        if (window.innerWidth > 768 && nav && nav.classList.contains('nav-open')) {
          nav.classList.remove('nav-open');
          body.classList.remove('no-scroll');
          if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
        }
      }, 250));

    } catch (error) {
      console.error('Error during site initialization:', error);
    }
  };

  // Attach initialization to DOMContentLoaded event
  document.addEventListener('DOMContentLoaded', init);

})();

//# sourceURL=main.js