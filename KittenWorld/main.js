// main.js - Core functionality for KittenWorld across all pages

(() => {
  // Utility functions
  const select = (selector, scope = document) => scope.querySelector(selector);
  const selectAll = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

  // Debounce utility to throttle events
  const debounce = (func, wait) => {
    let timeout;
    return (...args) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(null, args), wait);
    };
  };

  // Check if element exists before applying an operation
  const safeQuery = (selector, scope = document) => {
    try {
      const el = select(selector, scope);
      return el || null;
    } catch (e) {
      console.error(`Failed to select element ${selector}: `, e);
      return null;
    }
  };

  // Handle mobile menu toggle
  const initMobileMenuToggle = () => {
    const toggleBtn = safeQuery('.mobile-menu-toggle');
    const navMenu = safeQuery('.nav-menu');

    if (!toggleBtn || !navMenu) return;

    toggleBtn.addEventListener('click', () => {
      try {
        const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
        toggleBtn.setAttribute('aria-expanded', String(!expanded));
        navMenu.classList.toggle('nav-menu-active');
        toggleBtn.classList.toggle('active');
      } catch (e) {
        console.error('Error toggling mobile menu:', e);
      }
    });
  };

  // Set active navigation link based on current page
  const setActiveNavLink = () => {
    const navLinks = selectAll('.nav-menu .nav-link');
    if (!navLinks.length) return;

    const currentPath = window.location.pathname.replace(/\/$/, ''); // remove trailing slash
    navLinks.forEach(link => {
      try {
        const linkHref = new URL(link.href).pathname.replace(/\/$/, '');
        if (linkHref === currentPath) {
          link.classList.add('active');
        } else {
          link.classList.remove('active');
        }
      } catch (e) {
        // skip invalid href
      }
    });
  };
// Smooth scroll for internal anchor links
  const initSmoothScrolling = () => {
    document.body.addEventListener('click', event => {
      const target = event.target;
      if (target.tagName === 'A' && target.getAttribute('href')?.startsWith('#')) {
        const id = target.getAttribute('href').substring(1);
        const targetEl = safeQuery(`#${id}`);
        if (targetEl) {
          event.preventDefault();
          targetEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      }
    });
  };

  // Scroll to top button functionality
  const initScrollToTop = () => {
    const scrollBtn = document.createElement('button');
    scrollBtn.setAttribute('aria-label', 'Scroll to top');
    scrollBtn.className = 'scroll-to-top';
    scrollBtn.innerHTML = '&#8679;';
    document.body.appendChild(scrollBtn);

    scrollBtn.style.opacity = '0';
    scrollBtn.style.pointerEvents = 'none';

    const toggleVisibility = debounce(() => {
      if (window.scrollY > 300) {
        scrollBtn.style.opacity = '1';
        scrollBtn.style.pointerEvents = 'auto';
      } else {
        scrollBtn.style.opacity = '0';
        scrollBtn.style.pointerEvents = 'none';
      }
    }, 100);

    window.addEventListener('scroll', toggleVisibility);

    scrollBtn.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  };

  // Global keyboard shortcuts (Escape key for overlays)
  const initGlobalKeyboardShortcuts = () => {
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') {
        // Close mobile menu if open
        const navMenu = safeQuery('.nav-menu');
        const toggleBtn = safeQuery('.mobile-menu-toggle');
        if (navMenu && navMenu.classList.contains('nav-menu-active') && toggleBtn) {
          navMenu.classList.remove('nav-menu-active');
          toggleBtn.classList.remove('active');
          toggleBtn.setAttribute('aria-expanded', 'false');
        }
        // Close any open dialog or modal - custom event dispatch
        const closeEvents = ['modalClose', 'lightboxClose'];
        closeEvents.forEach(eventName => {
          const event = new CustomEvent(eventName);
          document.dispatchEvent(event);
        });
      }
    });
  };
// Keyboard navigation for accessibility
  const initKeyboardNavForNavMenu = () => {
    const navMenu = safeQuery('.nav-menu');
    if (!navMenu) return;

    navMenu.addEventListener('keydown', e => {
      const focusableSelectors = 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
      const focusable = selectAll(focusableSelectors, navMenu);
      const currentIndex = focusable.indexOf(document.activeElement);

      if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
        e.preventDefault();
        const nextIndex = (currentIndex + 1) % focusable.length;
        focusable[nextIndex].focus();
      } else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
        e.preventDefault();
        const prevIndex = (currentIndex - 1 + focusable.length) % focusable.length;
        focusable[prevIndex].focus();
      }
    });
  };
// Lazy load images with data-src attribute
  const initLazyLoadImages = () => {
    if (!('IntersectionObserver' in window)) {
      // Fallback - load all images immediately
      const imgs = selectAll('img[data-src]');
      imgs.forEach(img => {
        img.src = img.getAttribute('data-src');
        img.removeAttribute('data-src');
      });
      return;
    }

    const observer = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const img = entry.target;
          const src = img.getAttribute('data-src');
          if (src) {
            img.src = src;
            img.removeAttribute('data-src');
          }
          obs.unobserve(img);
        }
      });
    }, { rootMargin: '50px 0px' });

    selectAll('img[data-src]').forEach(img => observer.observe(img));
  };

  // Update footer year dynamically
  const updateFooterYear = () => {
    const footer = safeQuery('#footer');
    if (!footer) return;
    try {
      const p = footer.querySelector('p');
      if (!p) return;
      const year = new Date().getFullYear();
      p.innerHTML = p.innerHTML.replace(/\d{4}/, year);
    } catch (e) {
      // silently fail
    }
  };

  // Initialize tooltips on elements with data-tooltip
  const initTooltips = () => {
    let tooltipElement = null;

    const showTooltip = (event) => {
      const target = event.target.closest('[data-tooltip]');
      if (!target) return;
      const text = target.getAttribute('data-tooltip');
      if (!text) return;

      if (!tooltipElement) {
        tooltipElement = document.createElement('div');
        tooltipElement.className = 'tooltip';
        document.body.appendChild(tooltipElement);
      }

      tooltipElement.textContent = text;
      tooltipElement.style.opacity = '1';

      const rect = target.getBoundingClientRect();
      tooltipElement.style.top = `${rect.top - tooltipElement.offsetHeight - 8 + window.scrollY}px`;
      tooltipElement.style.left = `${rect.left + rect.width / 2 - tooltipElement.offsetWidth / 2 + window.scrollX}px`;
    };

    const hideTooltip = () => {
      if (tooltipElement) {
        tooltipElement.style.opacity = '0';
      }
    };

    document.body.addEventListener('mouseover', showTooltip);
    document.body.addEventListener('mouseout', hideTooltip);
  };

  // Handle global error logging
  const initGlobalErrorHandling = () => {
    window.addEventListener('error', e => {
      try {
        console.error('Global JS Error:', e.message, 'at', e.filename + ':' + e.lineno + ':' + e.colno);
      } catch (ex) {
        // Avoid infinite loops
      }
    });
    window.addEventListener('unhandledrejection', e => {
      try {
        console.error('Unhandled Promise Rejection:', e.reason);
      } catch (ex) {}
    });
  };
// Initialization sequence
  document.addEventListener('DOMContentLoaded', () => {
    try {
      initMobileMenuToggle();
      setActiveNavLink();
      initSmoothScrolling();
      initScrollToTop();
      initGlobalKeyboardShortcuts();
      initKeyboardNavForNavMenu();
      initLazyLoadImages();
      updateFooterYear();
      initTooltips();
      initGlobalErrorHandling();
    } catch (e) {
      console.error('Error during initialization:', e);
    }
  });
})();

// End of main.js