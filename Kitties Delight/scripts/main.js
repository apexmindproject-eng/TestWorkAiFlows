/* main.js - Core JavaScript for Kitties Delight Site
 * Handles navigation, global features, form validation, accessibility, and utility functions
 * Applies to all pages: index, gallery, care-tips, breeds, contact
 */

(() => {
  'use strict';

  // Utility selector helpers
  const select = (selector, scope = document) => scope.querySelector(selector);
  const selectAll = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

  // Debounce utility to throttle resize or scroll
  const debounce = (fn, delay) => {
    let timer = null;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn(...args), delay);
    };
  };

  // Mobile menu toggle
  const initMobileMenuToggle = () => {
    const toggleBtn = select('.mobile-menu-toggle');
    const navMenu = select('.nav-menu');

    if (!toggleBtn || !navMenu) return;

    toggleBtn.setAttribute('aria-expanded', 'false');

    toggleBtn.addEventListener('click', () => {
      try {
        const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
        toggleBtn.setAttribute('aria-expanded', String(!expanded));
        navMenu.classList.toggle('nav-menu-active');
        toggleBtn.classList.toggle('active');
      } catch (err) {
        console.error('Error toggling mobile menu:', err);
      }
    });
  };

  // Set active nav link based on current URL path
  const setActiveNavLink = () => {
    const navLinks = selectAll('.nav-menu .nav-link');
    if (!navLinks.length) return;

    // Normalize current location path (strip directory prefixes)
    const currentPath = window.location.pathname.replace(/^\/pages\//, '').replace(/\/$/, '').toLowerCase();

    navLinks.forEach(link => {
      try {
        const href = link.getAttribute('href') || '';
        const linkPath = href.replace(/^\.\//, '').replace(/^\/pages\//, '').replace(/\/$/, '').toLowerCase();

        // Sometimes href might be a full URL, only compare path
        const url = new URL(href, window.location.origin);
        const urlPath = url.pathname.replace(/^\/pages\//, '').replace(/\/$/, '').toLowerCase();

        if (linkPath === currentPath || urlPath === currentPath) {
          link.classList.add('active');
        } else {
          link.classList.remove('active');
        }
      } catch (e) {
        // skip invalid href or errors
      }
    });
  };
// Smooth scroll for internal anchor links
  const initSmoothScrolling = () => {
    document.body.addEventListener('click', (event) => {
      let target = event.target;
      while (target && target !== document.body) {
        if (target.tagName === 'A' && target.getAttribute('href')?.startsWith('#')) {
          const id = target.getAttribute('href').substring(1);
          const el = select(`#${id}`);
          if (el) {
            event.preventDefault();
            el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            // Update URL hash without jumping
            history.pushState(null, '', `#${id}`);
          }
          break;
        }
        target = target.parentElement;
      }
    });
  };
// Scroll-to-top button functionality
  const initScrollToTop = () => {
    const btn = document.createElement('button');
    btn.className = 'scroll-to-top';
    btn.setAttribute('aria-label', 'Scroll to top');
    btn.title = 'Scroll to top';
    btn.innerHTML = '&#8679;'; // Up arrow
    btn.style.opacity = '0';
    btn.style.pointerEvents = 'none';
    btn.style.position = 'fixed';
    btn.style.bottom = '40px';
    btn.style.right = '40px';
    btn.style.width = '45px';
    btn.style.height = '45px';
    btn.style.fontSize = '24px';
    btn.style.border = 'none';
    btn.style.borderRadius = '50%';
    btn.style.backgroundColor = '#444';
    btn.style.color = '#fff';
    btn.style.cursor = 'pointer';
    btn.style.zIndex = '1000';
    btn.style.transition = 'opacity 0.3s ease';

    document.body.appendChild(btn);

    const toggleVisibility = debounce(() => {
      if (window.scrollY > 300) {
        btn.style.opacity = '1';
        btn.style.pointerEvents = 'auto';
      } else {
        btn.style.opacity = '0';
        btn.style.pointerEvents = 'none';
      }
    }, 150);

    window.addEventListener('scroll', toggleVisibility);

    btn.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  };

  // Update footer year dynamically
  const updateFooterYear = () => {
    try {
      const footer = select('footer');
      if (!footer) return;
      const p = footer.querySelector('p');
      if (!p) return;
      const year = new Date().getFullYear();
      p.innerHTML = p.innerHTML.replace(/\d{4}/, year);
    } catch (e) {
      // ignore errors
    }
  };

  // Basic contact form validation
  const initContactFormValidation = () => {
    const form = select('form#contact-form');
    if (!form) return;

    form.addEventListener('submit', event => {
      const errors = [];
      try {
        // Basic validation - required fields
        const nameInput = form.querySelector('input[name="name"]');
        const emailInput = form.querySelector('input[name="email"]');
        const textarea = form.querySelector('textarea[name="message"]');

        if (!nameInput || !nameInput.value.trim()) {
          errors.push('Please enter your name.');
        }

        if (!emailInput || !validateEmail(emailInput.value.trim())) {
          errors.push('Please enter a valid email address.');
        }

        if (!textarea || !textarea.value.trim()) {
          errors.push('Please enter your message.');
        }

        if (errors.length > 0) {
          event.preventDefault();
          alert(errors.join('\n'));
        }
      } catch (e) {
        // log and allow form to submit if error occurs
        console.error('Error validating form:', e);
      }
    });
  };

  // Email validation regex
  const validateEmail = email => {
    const re = /^[\w-.]+@[\w-]+\.[a-z]{2,}$/i;
    return re.test(email);
  };

  // Keyboard accessibility enhancements for nav menu
  const initKeyboardNavAccessibility = () => {
    const navMenu = select('.nav-menu');
    if (!navMenu) return;

    navMenu.addEventListener('keydown', (e) => {
      const focusableSelectors = 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
      const focusable = selectAll(focusableSelectors, navMenu);
      const currentIndex = focusable.indexOf(document.activeElement);
if (['ArrowDown', 'ArrowRight'].includes(e.key)) {
        e.preventDefault();
        const nextIndex = (currentIndex + 1) % focusable.length;
        focusable[nextIndex].focus();
      } else if (['ArrowUp', 'ArrowLeft'].includes(e.key)) {
        e.preventDefault();
        const prevIndex = (currentIndex - 1 + focusable.length) % focusable.length;
        focusable[prevIndex].focus();
      }
    });
  };

  // Initialize lazy loading for images with data-src attribute
  const initLazyLoadImages = () => {
    if (!('IntersectionObserver' in window)) {
      // Fallback to loading all images immediately
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

  // Global error handlers
  const initGlobalErrorHandling = () => {
    window.addEventListener('error', e => {
      console.error('Global JS Error:', e.message, 'at', e.filename + ':' + e.lineno + ':' + e.colno);
    });

    window.addEventListener('unhandledrejection', e => {
      console.error('Unhandled Promise Rejection:', e.reason);
    });
  };

  // Initialize tooltip for elements with data-tooltip attribute
  const initTooltips = () => {
    let tooltipEl = null;

    const showTooltip = (event) => {
      const target = event.target.closest('[data-tooltip]');
      if (!target) return;
      const text = target.getAttribute('data-tooltip');
      if (!text) return;

      if (!tooltipEl) {
        tooltipEl = document.createElement('div');
        tooltipEl.className = 'tooltip';
        document.body.appendChild(tooltipEl);
      }

      tooltipEl.textContent = text;
      tooltipEl.style.opacity = '1';

      const rect = target.getBoundingClientRect();
      tooltipEl.style.top = `${rect.top - tooltipEl.offsetHeight - 8 + window.scrollY}px`;
      tooltipEl.style.left = `${rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2 + window.scrollX}px`;
    };

    const hideTooltip = () => {
      if (tooltipEl) {
        tooltipEl.style.opacity = '0';
      }
    };

    document.body.addEventListener('mouseover', showTooltip);
    document.body.addEventListener('mouseout', hideTooltip);
  };

  // Initialization
  document.addEventListener('DOMContentLoaded', () => {
    try {
      initMobileMenuToggle();
      setActiveNavLink();
      initSmoothScrolling();
      initScrollToTop();
      updateFooterYear();
      initContactFormValidation();
      initKeyboardNavAccessibility();
      initLazyLoadImages();
      initGlobalErrorHandling();
      initTooltips();
    } catch (e) {
      console.error('Error initializing main.js:', e);
    }
  });

})();

// End of main.js