// app.js - Core global functionalities for CryptoCurrency Hub
// Covers all pages: navigation toggle, active link, forms, UI interactions, optimizations

(() => {
  'use strict';

  // Utility selectors
  const select = (selector, parent = document) => parent.querySelector(selector);
  const selectAll = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

  // Debounce utility to limit frequent calls
  const debounce = (func, delay = 250) => {
    let timeoutId = null;
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => func.apply(null, args), delay);
    };
  };

  // Mobile Navigation Toggle: Inject hamburger button and handle toggling nav visibility
  const initMobileNavToggle = () => {
    try {
      const nav = select('#main-nav');
      if (!nav) return;
if (!select('.nav-toggle')) {
        const button = document.createElement('button');
        button.className = 'nav-toggle';
        button.type = 'button';
        button.setAttribute('aria-label', 'Toggle navigation menu');
        button.setAttribute('aria-expanded', 'false');
        button.innerHTML = '&#9776;'; // hamburger icon

        nav.parentNode.insertBefore(button, nav);

        button.addEventListener('click', () => {
          const expanded = button.getAttribute('aria-expanded') === 'true';
          button.setAttribute('aria-expanded', String(!expanded));
          nav.classList.toggle('nav-open');
        });
      }
    } catch (error) {
      console.error('Mobile nav toggle init error:', error);
    }
  };

  // Set Active Nav Link based on URL pathname (handles relative and absolute links)
  const setActiveNavLink = () => {
    try {
      const navLinks = selectAll('#main-nav .nav-link');
      if (!navLinks.length) return;
// Normalize current path
      const currentPath = window.location.pathname.replace(/\/g, '/').replace(/^\/|\/$/g, '').toLowerCase();

      navLinks.forEach(link => {
        try {
          let href = link.getAttribute('href') || '';
          href = href.replace(/\/g, '/').replace(/^\/|\/$/g, '').toLowerCase();

          // Exact filename or index matches set active
          let isActive = false;

          if (href === currentPath || (href.endsWith('index.html') && currentPath === '')) {
            isActive = true;
          } else {
            // Also check includes for nested pages (e.g. pages/about.html)
            if (currentPath.endsWith(href)) {
              isActive = true;
            }
          }
if (isActive) {
            link.classList.add('active');
            link.setAttribute('aria-current', 'page');
          } else {
            link.classList.remove('active');
            link.removeAttribute('aria-current');
          }
        } catch (e) {
          // Ignore per-link errors
        }
      });
    } catch (error) {
      console.error('setActiveNavLink error:', error);
    }
  };

  // Smooth scroll for anchor links within the page
  const initSmoothScroll = () => {
    try {
      if (!('scrollBehavior' in document.documentElement.style)) return; // No native support

      document.body.addEventListener('click', e => {
        const target = e.target.closest('a[href^="#"]');
        if (!target) return;

        const href = target.getAttribute('href');
        if (!href || href.length < 2) return;
const href = target.getAttribute('href');
        if (!href || href.length < 2) return;

        const destElem = select(href);
        if (destElem) {
          e.preventDefault();
          destElem.scrollIntoView({ behavior: 'smooth', block: 'start' });
          // Update URL hash without jumping
          history.pushState(null, '', href);
        }
      });
    } catch (error) {
      console.error('Smooth scroll init error:', error);
    }
  };

  // Contact Form Validation and Submission
  const initContactForm = () => {
    try {
      const form = select('#contact-form');
      if (!form) return;

      const inputs = {
        name: select('#name', form),
        email: select('#email', form),
        subject: select('#subject', form),
        message: select('#message', form)
      };
const inputs = {
        name: select('#name', form),
        email: select('#email', form),
        subject: select('#subject', form),
        message: select('#message', form)
      };

      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      
      // Clear previous errors
      const clearErrors = () => {
        selectAll('.form-error', form).forEach(errEl => errEl.remove());
        Object.values(inputs).forEach(input => {
          if (input) {
            input.removeAttribute('aria-invalid');
            input.removeAttribute('aria-describedby');
          }
        });
      };

      // Show error message below input field
      const showError = (input, message) => {
        clearErrors(); // Clear all errors for fresh show
        if (!input) return;
// Show error message below input field
      const showError = (input, message) => {
        clearErrors(); // Clear all errors for fresh show
        if (!input) return;

        const errorDiv = document.createElement('div');
        errorDiv.className = 'form-error';
        errorDiv.style.color = '#d93025';
        errorDiv.style.fontSize = '0.875rem';
        errorDiv.textContent = message;

        input.setAttribute('aria-invalid', 'true');
        const errorId = `error-for-${input.id}`;
        input.setAttribute('aria-describedby', errorId);
        errorDiv.id = errorId;

        input.parentNode.appendChild(errorDiv);
      };

      // Validate all inputs
      const validate = () => {
        clearErrors();
        let isValid = true;

        if (!inputs.name || inputs.name.value.trim().length < 2) {
          showError(inputs.name, 'Please enter your name (at least 2 characters).');
          isValid = false;
        }
if (!inputs.name || inputs.name.value.trim().length < 2) {
          showError(inputs.name, 'Please enter your name (at least 2 characters).');
          isValid = false;
        }

        if (!inputs.email || !emailRegex.test(inputs.email.value.trim())) {
          showError(inputs.email, 'Please enter a valid email address.');
          isValid = false;
        }

        if (!inputs.subject || inputs.subject.value.trim().length < 3) {
          showError(inputs.subject, 'Please enter a subject (at least 3 characters).');
          isValid = false;
        }

        if (!inputs.message || inputs.message.value.trim().length < 10) {
          showError(inputs.message, 'Please enter a message (at least 10 characters).');
          isValid = false;
        }

        return isValid;
      };

      const onSubmit = async event => {
        event.preventDefault();
        try {
          if (!validate()) return;
return isValid;
      };

      const onSubmit = async event => {
        event.preventDefault();
        try {
          if (!validate()) return;

          // Simulated async submission delay
          const submitBtn = select('button[type="submit"]', form);
          if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.textContent = 'Sending...';
          }

          await new Promise(resolve => setTimeout(resolve, 1200)); // Emulate submit delay

          form.reset();

          if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Send Message';
          }

          alert('Thank you for contacting CryptoCurrency Hub. We will get back to you shortly.');

        } catch (error) {
          console.error('Form submission error:', error);
          alert('There was an error sending your message. Please try again later.');
        }
      };
} catch (error) {
          console.error('Form submission error:', error);
          alert('There was an error sending your message. Please try again later.');
        }
      };

      form.addEventListener('submit', onSubmit);
    } catch (error) {
      console.error('Contact form init error:', error);
    }
  };

  // Homepage Hero Animation
  const initHeroImageCycle = () => {
    try {
      if (!document.body.id.includes('index-page')) return;

      const images = selectAll('.hero-images .crypto-img');
      if (!images.length) return;

      let currentIndex = 0;
      const visibleClass = 'visible';

      const cycle = () => {
        images.forEach((img, idx) => {
          img.classList.toggle(visibleClass, idx === currentIndex);
        });
        currentIndex = (currentIndex + 1) % images.length;
      };

      cycle();
      setInterval(cycle, 4000);

    } catch (error) {
      console.error('Hero image cycle init error:', error);
    }
  };
cycle();
      setInterval(cycle, 4000);

    } catch (error) {
      console.error('Hero image cycle init error:', error);
    }
  };

  // News page - Expand / collapse news summaries
  const initNewsReadMoreToggle = () => {
    try {
      if (!document.body.id.includes('news-page')) return;

      const newsList = select('#news-list');
      if (!newsList) return;

      newsList.addEventListener('click', event => {
        const target = event.target;
        if (!(target instanceof HTMLAnchorElement)) return;
        if (!target.classList.contains('read-more-link')) return;

        event.preventDefault();

        const article = target.closest('.news-article');
        if (!article) return;
event.preventDefault();

        const article = target.closest('.news-article');
        if (!article) return;

        const expandedClass = 'expanded';
        if (article.classList.contains(expandedClass)) {
          article.classList.remove(expandedClass);
          target.textContent = 'Read more';
        } else {
          article.classList.add(expandedClass);
          target.textContent = 'Read less';
        }
      });
    } catch (error) {
      console.error('News read more toggle error:', error);
    }
  };

  // Market page table sorting (enabled by clicking column headers)
  const initMarketTableSorting = () => {
    try {
      if (!document.body.id.includes('market-page')) return;

      const table = select('#crypto-market-table');
      if (!table) return;

      const tbody = select('tbody', table);
      if (!tbody) return;
const table = select('#crypto-market-table');
      if (!table) return;

      const tbody = select('tbody', table);
      if (!tbody) return;

      const getCellValue = (row, idx) => {
        const cell = row.cells[idx];
        if (!cell) return '';
        return cell.textContent.trim();
      };

      const comparer = (idx, asc) => (a, b) => {
        const v1 = getCellValue(a, idx);
        const v2 = getCellValue(b, idx);

        const num1 = parseFloat(v1.replace(/[^0-9.-]+/g, ''));
        const num2 = parseFloat(v2.replace(/[^0-9.-]+/g, ''));

        if (!isNaN(num1) && !isNaN(num2)) {
          return asc ? num1 - num2 : num2 - num1;
        }
        return asc ? v1.localeCompare(v2) : v2.localeCompare(v1);
      };

      let sortDirections = {};
let sortDirections = {};

      const headers = selectAll('thead th', table);
      headers.forEach((header, idx) => {
        header.style.cursor = 'pointer';
        header.addEventListener('click', () => {
          sortDirections[idx] = !sortDirections[idx];
          const asc = sortDirections[idx];

          const rows = Array.from(tbody.rows);
          rows.sort(comparer(idx, asc));
          rows.forEach(row => tbody.appendChild(row));
        });
      });

    } catch (error) {
      console.error('Market table sorting init error:', error);
    }
  };

  // Accessibility: Control focus outlines for keyboard navigation vs mouse
  const initFocusOutlineManagement = () => {
    try {
      const onFirstTab = e => {
        if (e.key === 'Tab') {
          document.body.classList.add('user-is-tabbing');
          window.removeEventListener('keydown', onFirstTab);
          window.addEventListener('mousedown', onMouseDownOnce);
        }
      };
const onMouseDownOnce = () => {
        document.body.classList.remove('user-is-tabbing');
        window.removeEventListener('mousedown', onMouseDownOnce);
        window.addEventListener('keydown', onFirstTab);
      };

      window.addEventListener('keydown', onFirstTab);
    } catch (error) {
      console.error('Focus outline management error:', error);
    }
  };

  // Initialization on DOMContentLoaded
  const init = () => {
    initMobileNavToggle();
    setActiveNavLink();
    initSmoothScroll();
    initContactForm();
    initHeroImageCycle();
    initNewsReadMoreToggle();
    initMarketTableSorting();
    initFocusOutlineManagement();
  };

  document.addEventListener('DOMContentLoaded', () => {
    try {
      init();
    } catch (error) {
      console.error('App initialization error:', error);
    }
  });
})();
document.addEventListener('DOMContentLoaded', () => {
    try {
      init();
    } catch (error) {
      console.error('App initialization error:', error);
    }
  });
})();

/*
  Summary:
  - Adds responsive mobile nav toggle with accessible controls.
  - Detects active page nav link and marks it accordingly.
  - Enables smooth scrolling for internal anchors.
  - Validates and simulates submission of contact form.
  - Animates homepage hero crypto images.
  - Enables dynamic toggling of news article summaries.
  - Adds sorting functionality to market table.
  - Manages focus outlines for accessibility.
  - Includes extensive error handling and defensive coding.
*/