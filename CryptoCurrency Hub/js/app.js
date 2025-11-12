// app.js - Core JavaScript for CryptoCurrency Hub
// Handles navigation, active page detection, mobile toggling, and form validation across all pages

// IIFE to avoid polluting global namespace
(() => {
  'use strict';

  // Cache DOM selectors used across pages
  const body = document.body;
  const siteHeader = document.getElementById('site-header');
  const mainNav = document.getElementById('main-navigation');

  // Create a mobile navigation toggle button dynamically if not present
  const createMobileNavToggle = () => {
    try {
      // Check if toggle already exists
      if (document.getElementById('mobile-nav-toggle')) return;

      const btn = document.createElement('button');
      btn.id = 'mobile-nav-toggle';
      btn.setAttribute('aria-label', 'Toggle navigation menu');
      btn.setAttribute('aria-expanded', 'false');
      btn.className = 'mobile-nav-toggle';
      btn.innerHTML = '&#9776;'; // Hamburger icon
if (!siteHeader) return;
      // Insert toggle button after logo-link
      const logoLink = siteHeader.querySelector('.logo-link');
      if (logoLink) {
        logoLink.insertAdjacentElement('afterend', btn);
      } else {
        siteHeader.insertBefore(btn, mainNav);
      }
    } catch (error) {
      console.error('Error creating mobile nav toggle:', error);
    }
  };

  // Toggle mobile menu open/close
  const toggleMobileMenu = (event) => {
    try {
      const btn = event.target.closest('#mobile-nav-toggle');
      if (!btn) return;

      const expanded = btn.getAttribute('aria-expanded') === 'true';
      btn.setAttribute('aria-expanded', String(!expanded));
      mainNav.classList.toggle('nav-open');
      body.classList.toggle('no-scroll');
    } catch (error) {
      console.error('Error toggling mobile menu:', error);
    }
  };
// Close mobile menu (useful for link clicks)
  const closeMobileMenu = () => {
    try {
      const btn = document.getElementById('mobile-nav-toggle');
      if (btn) {
        btn.setAttribute('aria-expanded', 'false');
      }
      if (mainNav) {
        mainNav.classList.remove('nav-open');
      }
      body.classList.remove('no-scroll');
    } catch (error) {
      console.error('Error closing mobile menu:', error);
    }
  };

  // Set active navigation link based on current page URL
  const setActiveNavLink = () => {
    try {
      if (!mainNav) return;

      const navLinks = mainNav.querySelectorAll('.nav-link');
      if (!navLinks.length) return;

      // Normalize pathname to compare relative paths
      const currentPath = window.location.pathname.split('/').pop() || 'index.html';

      navLinks.forEach(link => {
        // Remove active and aria-current from all
        link.classList.remove('active');
        link.removeAttribute('aria-current');
navLinks.forEach(link => {
        // Remove active and aria-current from all
        link.classList.remove('active');
        link.removeAttribute('aria-current');

        // Also handle possible relative or absolute links
        const linkPathName = link.getAttribute('href').split('/').pop();

        if (linkPathName === currentPath) {
          link.classList.add('active');
          link.setAttribute('aria-current', 'page');
        }
      });
    } catch (error) {
      console.error('Error setting active navigation link:', error);
    }
  };

  // Form validation for the contact form on contact.html
  const handleContactForm = () => {
    try {
      const form = document.getElementById('contact-form');
      if (!form) return; // Not on contact page or no form

      // Utility: email regex (simple)
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
// Utility: email regex (simple)
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;

      const showError = (input, message) => {
        try {
          const formGroup = input.closest('.form-group');
          if (!formGroup) return;

          // Remove existing error
          let errorElem = formGroup.querySelector('.error-message');
          if (!errorElem) {
            errorElem = document.createElement('div');
            errorElem.className = 'error-message';
            formGroup.appendChild(errorElem);
          }
          errorElem.textContent = message;
          input.classList.add('input-error');
          input.setAttribute('aria-invalid', 'true');
        } catch (e) {
          console.error('Error showing input error:', e);
        }
      };
const clearError = (input) => {
        try {
          const formGroup = input.closest('.form-group');
          if (!formGroup) return;
          const errorElem = formGroup.querySelector('.error-message');
          if (errorElem) {
            errorElem.textContent = '';
          }
          input.classList.remove('input-error');
          input.removeAttribute('aria-invalid');
        } catch (e) {
          console.error('Error clearing input error:', e);
        }
      };

      const validateField = (input) => {
        try {
          clearError(input);
          const { id, value } = input;
          if (!value.trim()) {
            showError(input, 'This field is required.');
            return false;
          }

          if (id === 'email') {
            if (!emailRegex.test(value.trim())) {
              showError(input, 'Please enter a valid email address.');
              return false;
            }
          }
if (id === 'message') {
            // Optional additional checks (min length)
            if (value.trim().length < 10) {
              showError(input, 'Message should be at least 10 characters.');
              return false;
            }
          }

          return true;
        } catch (e) {
          console.error('Error validating field:', e);
          return false;
        }
      };

      // Validate all inputs on submit
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        try {
          const inputs = form.querySelectorAll('input, textarea');
          let allValid = true;
          inputs.forEach(input => {
            const isValid = validateField(input);
            if (!isValid) allValid = false;
          });
if (!allValid) {
            // Focus on first invalid element
            const firstInvalid = form.querySelector('.input-error');
            if (firstInvalid) firstInvalid.focus();
            return;
          }

          // Form is valid; simulate form submission or send via AJAX
          submitContactForm(form);
        } catch (error) {
          console.error('Error during form submit:', error);
        }
      });

      // Live validation on input blur
      form.addEventListener('blur', (e) => {
        try {
          if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
            validateField(e.target);
          }
        } catch (error) {
          console.error('Error in blur validation:', error);
        }
      }, true);
// Simulated form submission
      const submitContactForm = (form) => {
        try {
          const submitButton = form.querySelector('[type="submit"]');
          if (submitButton) {
            submitButton.disabled = true;
            submitButton.textContent = 'Sending...';
          }

          // Simulate network delay
          setTimeout(() => {
            alert('Thank you for contacting CryptoCurrency Hub! We will get back to you soon.');
            form.reset();
            if (submitButton) {
              submitButton.disabled = false;
              submitButton.textContent = 'Send Message';
            }
          }, 1500);
        } catch (e) {
          console.error('Error submitting contact form:', e);
          alert('Sorry, there was an error sending your message. Please try again later.');
        }
      };
    } catch (error) {
      console.error('Error initializing contact form handler:', error);
    }
  };
// Utility to mark external links with target=_blank and rel attributes for safety
  const enhanceExternalLinks = () => {
    try {
      const links = document.querySelectorAll('a[href^="http"]');
      links.forEach(link => {
        const href = link.getAttribute('href');
        if (!href) return;
        const url = new URL(href, window.location.href);
        if (url.hostname !== window.location.hostname) {
          link.setAttribute('target', '_blank');
          link.setAttribute('rel', 'noopener noreferrer');
        }
      });
    } catch (error) {
      console.error('Error enhancing external links:', error);
    }
  };

  // Keyboard accessibility: Close mobile menu on ESC key
  const handleKeyDown = (event) => {
    try {
      if (event.key === 'Escape') {
        closeMobileMenu();
      }
    } catch (error) {
      console.error('Error handling keydown event:', error);
    }
  };
// Delegated click handler: Used for mobile nav toggle & other global click interactions
  const globalClickHandler = (event) => {
    try {
      // Mobile nav toggle button
      if (event.target.closest('#mobile-nav-toggle')) {
        toggleMobileMenu(event);
        return;
      }

      // Close mobile menu on nav link click
      if (event.target.closest('#main-navigation a.nav-link')) {
        closeMobileMenu();
      }

      // Handle any "Read more" links on news page for future enhancement
      // Currently default link behavior (href="#")
    } catch (error) {
      console.error('Error in global click handler:', error);
    }
  };

  // Initialize sticky header on scroll
  const initStickyHeader = () => {
    try {
      if (!siteHeader) return;

      let lastScrollY = window.scrollY;
      const headerHeight = siteHeader.offsetHeight;
let lastScrollY = window.scrollY;
      const headerHeight = siteHeader.offsetHeight;

      window.addEventListener('scroll', () => {
        try {
          const currentScrollY = window.scrollY;
          if (currentScrollY > headerHeight) {
            siteHeader.classList.add('header-sticky');
          } else {
            siteHeader.classList.remove('header-sticky');
          }
          lastScrollY = currentScrollY;
        } catch (err) {
          console.error('Error in scroll event:', err);
        }
      }, { passive: true });
    } catch (error) {
      console.error('Error initializing sticky header:', error);
    }
  };

  // Initialization function
  const init = () => {
    try {
      createMobileNavToggle();
      setActiveNavLink();
      handleContactForm();
      enhanceExternalLinks();
      initStickyHeader();
document.addEventListener('click', globalClickHandler);
      document.addEventListener('keydown', handleKeyDown);
    } catch (error) {
      console.error('Error in app initialization:', error);
    }
  };

  // Run init on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', init);

})();