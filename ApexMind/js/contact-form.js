// contact-form.js - Handles all contact form related functionalities across ApexMind website
// Includes validation, submission, feedback, error handling, and progressive enhancement

'use strict';

(() => {
  // Cache references
  const formsSelector = 'form'; // Global selector for forms; can refine if needed

  // Helper: debounce
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

  // Helper: Sanitize input to prevent XSS or invalid characters
  const sanitizeInput = (value) => {
    const div = document.createElement('div');
    div.textContent = value;
    return div.innerHTML.trim();
  };
// Show form status message below form
  const showFormMessage = (form, message, isSuccess = true) => {
    if (!form) return;
    let messageEl = form.querySelector('.form-status-message');
    if (!messageEl) {
      messageEl = document.createElement('div');
      messageEl.className = 'form-status-message';
      messageEl.setAttribute('aria-live', 'polite');
      form.appendChild(messageEl);
    }
    messageEl.textContent = message;
    messageEl.style.color = isSuccess ? 'var(--color-success, #28a745)' : 'var(--color-error, #dc3545)';
  };

  // Clear form status message
  const clearFormMessage = (form) => {
    if (!form) return;
    const messageEl = form.querySelector('.form-status-message');
    if (messageEl) {
      messageEl.textContent = '';
    }
  };

  // Validate input element
  const validateInput = (input) => {
    if (!input) return true;

    // Basic required validation
    if (input.hasAttribute('required') && !input.value.trim()) {
      return false;
    }
    // Additional HTML5 validation (pattern, type, etc.)
    if (!input.checkValidity()) {
      return false;
    }
    return true;
  };

  // Validate entire form; returns boolean and focuses first invalid input
  const validateForm = (form) => {
    if (!form) return false;

    const inputs = Array.from(form.querySelectorAll('input, textarea, select'));
    let isValid = true;
    for (const input of inputs) {
      const valid = validateInput(input);
      if (!valid) {
        isValid = false;
        input.setAttribute('aria-invalid', 'true');
        input.focus();
        break;
      } else {
        input.removeAttribute('aria-invalid');
      }
    }
    return isValid;
  };
// Prepare form data object sanitized for submission
  const prepareFormData = (form) => {
    const data = {};
    if (!form) return data;

    const elements = Array.from(form.elements).filter(el => el.name && !el.disabled);

    elements.forEach(el => {
      if (el.type === 'checkbox') {
        data[el.name] = el.checked;
      } else if (el.type === 'radio') {
        if (el.checked) data[el.name] = sanitizeInput(el.value);
      } else if (el.tagName.toLowerCase() === 'select') {
        data[el.name] = sanitizeInput(el.options[el.selectedIndex]?.value || '');
      } else {
        data[el.name] = sanitizeInput(el.value);
      }
    });
    return data;
  };
// Simulated async form submission
  // Replace or extend this with actual API call via fetch or XMLHttpRequest
  const submitFormData = (data) => {
    return new Promise((resolve, reject) => {
      // Simulate network latency and random success/failure
      setTimeout(() => {
        // For demo: success 90%, error 10%
        if (Math.random() < 0.9) {
          resolve({ status: 'success', data });
        } else {
          reject(new Error('Network error: submission failed'));
        }
      }, 1200);
    });
  };

  // Disable form controls during submission
  const disableForm = (form, disable = true) => {
    if (!form) return;
    const elements = form.querySelectorAll('input, textarea, select, button');
    elements.forEach(el => el.disabled = disable);
  };

  // Handle form submission event
  const handleFormSubmit = async (event) => {
    event.preventDefault();
    const form = event.target;
    clearFormMessage(form);

    if (!validateForm(form)) {
      showFormMessage(form, 'Please complete all required fields correctly.', false);
      return;
    }

    disableForm(form, true);
    showFormMessage(form, 'Sending your message...');

    const formData = prepareFormData(form);

    try {
      const response = await submitFormData(formData);
      showFormMessage(form, 'Thank you! Your message has been sent.');
      form.reset();
    } catch (error) {
      console.error('Form submission error:', error);
      showFormMessage(form, 'Oops! Something went wrong. Please try again later.', false);
    } finally {
      disableForm(form, false);
    }
  };
// Real-time validation for inputs to set aria-invalid
  const setupInputValidation = (form) => {
    if (!form) return;
    form.querySelectorAll('input, textarea, select').forEach(input => {
      input.addEventListener('input', () => {
        if (validateInput(input)) {
          input.removeAttribute('aria-invalid');
        } else {
          input.setAttribute('aria-invalid', 'true');
        }
      });
    });
  };

  // Initialize all contact forms on page
  const initContactForms = () => {
    try {
      const forms = document.querySelectorAll('form.contact-form');
      if (!forms.length) return;

      forms.forEach(form => {
        setupInputValidation(form);
        form.addEventListener('submit', handleFormSubmit);
      });

    } catch (error) {
      console.error('Error initializing contact forms:', error);
    }
  };

  // Initialization
  const init = () => {
    initContactForms();
  };

  document.addEventListener('DOMContentLoaded', init);

})();

//# sourceURL=contact-form.js