// navigation.js - Handles website navigation UI including mobile menu toggle, active link highlighting,
// keyboard navigation accessibility, and global event delegation for navigation links.

'use strict';

(() => {
  // Cache navigation elements
  const nav = document.getElementById('main-navigation');
  const navList = nav ? nav.querySelector('.nav-list') : null;
  const body = document.body;

  // Mobile navigation toggle button reference
  let mobileNavToggleBtn = null;

  // Debounce utility to limit high frequency calls
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
// Highlight the active nav link based on current pathname
  const highlightActiveNavLink = () => {
    try {
      if (!navList) return;
      const currentPage = window.location.pathname.split('/').pop() || 'index.html';
      const navLinks = navList.querySelectorAll('.nav-link');

      navLinks.forEach(link => {
        const href = link.getAttribute('href').trim();
        if (href === currentPage) {
          link.classList.add('current');
          link.setAttribute('aria-current', 'page');
        } else {
          link.classList.remove('current');
          link.removeAttribute('aria-current');
        }
      });
    } catch (err) {
      console.error('Failed to highlight active nav link:', err);
    }
  };

  // Create mobile nav toggle button and attach event handler
  const createMobileNavToggle = () => {
    try {
      if (!nav || document.getElementById('mobile-nav-toggle')) return;

      mobileNavToggleBtn = document.createElement('button');
      mobileNavToggleBtn.setAttribute('id', 'mobile-nav-toggle');
      mobileNavToggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
      mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      mobileNavToggleBtn.className = 'mobile-nav-toggle';
      mobileNavToggleBtn.innerHTML = '<span class="hamburger-line"></span><span class="hamburger-line"></span><span class="hamburger-line"></span>';

      const container = nav.parentElement || body;
      container.insertBefore(mobileNavToggleBtn, nav);

      mobileNavToggleBtn.addEventListener('click', () => {
        const expanded = mobileNavToggleBtn.getAttribute('aria-expanded') === 'true';
        mobileNavToggleBtn.setAttribute('aria-expanded', String(!expanded));
        nav.classList.toggle('nav-open');
        body.classList.toggle('no-scroll');
      });

      // Close nav on outside clicks
      document.addEventListener('click', (e) => {
        if (!nav.classList.contains('nav-open')) return;

        if (e.target === mobileNavToggleBtn || nav.contains(e.target)) return;

        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      });

      // Close nav on ESC key
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && nav.classList.contains('nav-open')) {
          nav.classList.remove('nav-open');
          body.classList.remove('no-scroll');
          if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
          mobileNavToggleBtn.focus();
        }
      });
    } catch (err) {
      console.error('Failed to create mobile nav toggle:', err);
    }
  };

  // Keyboard navigation handler for nav menu to allow arrow key movement
  const enableKeyboardNavigation = () => {
    if (!navList) return;

    navList.addEventListener('keydown', (e) => {
      try {
        const links = Array.from(navList.querySelectorAll('.nav-link'));
        let currentIndex = links.indexOf(document.activeElement);
        if (currentIndex === -1) return;
switch (e.key) {
          case 'ArrowDown':
          case 'ArrowRight':
            e.preventDefault();
            currentIndex = (currentIndex + 1) % links.length;
            links[currentIndex].focus();
            break;
          case 'ArrowUp':
          case 'ArrowLeft':
            e.preventDefault();
            currentIndex = (currentIndex - 1 + links.length) % links.length;
            links[currentIndex].focus();
            break;
          case 'Home':
            e.preventDefault();
            links[0].focus();
            break;
          case 'End':
            e.preventDefault();
            links[links.length - 1].focus();
            break;
          default:
            break;
        }
      } catch (err) {
        console.error('Error in nav keyboard navigation:', err);
      }
    });
  };
// Event delegation for nav link clicks - could be used to smooth scroll or add page transition effects
  const delegateNavClicks = () => {
    document.body.addEventListener('click', (e) => {
      const link = e.target.closest('.nav-link');
      if (!link) return;

      const href = link.getAttribute('href');
      if (!href || href.startsWith('#')) {
        // For internal anchors allow normal behavior
        return;
      }

      // Could add additional custom navigation handling here
      // For now, allow default behavior
    });
  };

  // Close mobile nav on window resize if viewport is large
  const setupResizeHandler = () => {
    window.addEventListener('resize', debounce(() => {
      if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
        nav.classList.remove('nav-open');
        body.classList.remove('no-scroll');
        if (mobileNavToggleBtn) mobileNavToggleBtn.setAttribute('aria-expanded', 'false');
      }
    }, 250));
  };
// Initialization
  const init = () => {
    highlightActiveNavLink();
    createMobileNavToggle();
    enableKeyboardNavigation();
    delegateNavClicks();
    setupResizeHandler();
  };

  document.addEventListener('DOMContentLoaded', init);
})();

//# sourceURL=navigation.js