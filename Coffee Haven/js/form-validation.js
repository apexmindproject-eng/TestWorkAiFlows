// form-validation.js - Handles all form validation and submission for Coffee Haven

(() => {
 'use strict';

 /**
 * Utility function: Check if element is valid HTMLElement
 * @param {any} el
 * @returns {boolean}
 */
 const isValidElement = (el) => el instanceof HTMLElement;

 /**
 * Utility function: Create and insert an ARIA live region for announcing validation messages
 * @returns {HTMLElement} liveRegion
 */
 const createLiveRegion = () => {
 let liveRegion = document.getElementById('form-validation-live-region');
 if (liveRegion) return liveRegion;

 liveRegion = document.createElement('div');
 liveRegion.id = 'form-validation-live-region';
 liveRegion.setAttribute('aria-live', 'assertive');
 liveRegion.setAttribute('aria-atomic', 'true');
 liveRegion.style.position = 'absolute';
 liveRegion.style.width = '1px';
 liveRegion.style.height = '1px';
 liveRegion.style.margin = '-1px';
 liveRegion.style.border = '0';
 liveRegion.style.padding = '0';
 liveRegion.style.overflow = 'hidden';
 liveRegion.style.clip = 'rect(0 0 0 0)';
 liveRegion.style.clipPath = 'inset(50%)';

 document.body.appendChild(liveRegion);
 return liveRegion;
 };

 const liveRegion = createLiveRegion();

 /**
 * Validate email format with RFC 5322 official standard regex simplified
 * @param {string} email
 * @returns {boolean}
 */
 const isValidEmail = (email) => {
 const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
 return emailRegex.test(email);
 };

 /**
 * Validate form fields according to requirements
 * @param {HTMLFormElement} form
 * @returns {boolean} true if valid, false if invalid fields
 */
 const validateForm = (form) => {
 if (!isValidElement(form)) return false;

 let isFormValid = true;
 const formElements = form.elements;
 const validationMessages = [];

 // Clear previous error states
 form.querySelectorAll('.input-error').forEach(el => el.classList.remove('input-error'));
 form.querySelectorAll('.error-message').forEach(el => el.remove());

 // Helper: Add error message after input
 const addErrorMessage = (input, message) => {
 if (!isValidElement(input)) return;
 input.classList.add('input-error');
 const errorEl = document.createElement('div');
 errorEl.className = 'error-message';
 errorEl.setAttribute('role', 'alert');
 errorEl.textContent = message;
 input.parentNode.insertBefore(errorEl, input.nextSibling);
 };

 // Validate required fields and specific constraints
 for (let i = 0; i < formElements.length; i++) {
 const element = formElements[i];

 if (!isValidElement(element) || element.disabled) continue;

 // Only validate inputs, textareas, selects
 if (!['INPUT', 'TEXTAREA', 'SELECT'].includes(element.tagName)) continue;

 const isRequired = element.hasAttribute('required') || element.getAttribute('aria-required') === 'true';

 // Check required
 if (isRequired) {
 if (!element.value || element.value.trim() === '') {
 addErrorMessage(element, `Please fill out the ${element.name || 'field'}.`);
 validationMessages.push(`Missing value for ${element.name || 'field'}`);
 isFormValid = false;
 continue;
 }
 }

 // Additional validation for specific types
 if (element.type === 'email' && element.value) {
 if (!isValidEmail(element.value.trim())) {
 addErrorMessage(element, 'Please enter a valid email address.');
 validationMessages.push('Invalid email format');
 isFormValid = false;
 continue;
 }
 }

 // Optional: Longer validation rules can be added here
 }

 // Announce error summary if invalid
 if (!isFormValid && validationMessages.length > 0) {
 liveRegion.textContent = `Form contains errors: ${validationMessages.join(', ')}.`;
 } else {
 liveRegion.textContent = '';
 }

 return isFormValid;
 };

 /**
 * Clear all validation errors from form
 * @param {HTMLFormElement} form
 */
 const clearValidationErrors = (form) => {
 if (!isValidElement(form)) return;
 form.querySelectorAll('.input-error').forEach(el => el.classList.remove('input-error'));
 form.querySelectorAll('.error-message').forEach(el => el.remove());
 liveRegion.textContent = '';
 };

 /**
 * Handle form submission with validation
 * @param {Event} event
 */
 const handleFormSubmit = (event) => {
 try {
 const form = event.target;
 if (!(form instanceof HTMLFormElement)) return;
 event.preventDefault();

 clearValidationErrors(form);

 const isValid = validateForm(form);

 if (!isValid) {
 // Focus first error
 const firstError = form.querySelector('.input-error');
 if (firstError) firstError.focus();
 return;
 }

 // Simulate form submission
 // Here you would typically use fetch() with form data or other APIs
 submitFormData(form);

 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Error during form submission:', error);
 }
 };

 /**
 * Simulate async form submission with feedback to user
 * @param {HTMLFormElement} form
 */
 const submitFormData = (form) => {
 if (!isValidElement(form)) return;

 // Disable submit button to prevent multiple submissions
 const submitBtn = form.querySelector('[type="submit"]');
 if (submitBtn) {
 submitBtn.disabled = true;
 submitBtn.textContent = 'Sending...';
 }

 const formData = new FormData(form);

 // Simulated async submission (as no backend endpoint is provided)
 setTimeout(() => {
 // On success
 try {
 if (submitBtn) {
 submitBtn.disabled = false;
 submitBtn.textContent = 'Submit';
 }

 // Clear form fields
 form.reset();

 // Provide success announcement
 liveRegion.textContent = 'Your message has been sent successfully. Thank you!';

 // Show user success notification (could be a modal or inline message)
 showSuccessMessage(form);
 } catch (err) {
 // eslint-disable-next-line no-console
 console.error('Error after form submission:', err);
 }
 }, 1500);
 };

 /**
 * Show a non-intrusive success message below the form
 * @param {HTMLFormElement} form
 */
 const showSuccessMessage = (form) => {
 if (!isValidElement(form)) return;

 // Remove previous success messages
 const prevSuccess = form.querySelector('.form-success-message');
 if (prevSuccess) prevSuccess.remove();

 const successMessage = document.createElement('div');
 successMessage.className = 'form-success-message';
 successMessage.setAttribute('role', 'alert');
 successMessage.textContent = 'Thank you for contacting us! We will get back to you soon.';
 successMessage.style.marginTop = '1em';
 successMessage.style.color = 'green';

 form.appendChild(successMessage);

 // Automatically remove success message after 5 seconds
 setTimeout(() => {
 if (successMessage.parentNode) {
 successMessage.parentNode.removeChild(successMessage);
 }
 }, 5000);
 };

 /**
 * Initialize form event listeners for all forms on page
 */
 const initFormValidation = () => {
 try {
 // Use event delegation at document level for forms
 document.addEventListener('submit', (event) => {
 const target = event.target;
 if (!(target instanceof HTMLFormElement)) return;

 // Only bind to forms that require validation
 if (target.classList.contains('contact-form') || target.tagName === 'FORM') {
 handleFormSubmit(event);
 }
 });
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Form validation initialization failed:', error);
 }
 };

 /**
 * Accessibility enhancement: Focus first invalid field on page load if URL hash indicates error
 * Use case: if server-side validation returns errors and anchors to invalid fields
 */
 const focusFirstInvalidFieldOnLoad = () => {
 try {
 window.setTimeout(() => {
 const invalidField = document.querySelector('.input-error, :invalid');
 if (invalidField) invalidField.focus();
 }, 200);
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Accessibility focus enhancement failed:', error);
 }
 };

 /**
 * Validate individual input on blur for instant feedback
 * @param {Event} event
 */
 const validateOnInputBlur = (event) => {
 try {
 const target = event.target;
 if (!(target instanceof HTMLElement)) return;

 // Remove previous error
 const form = target.closest('form');
 if (!isValidElement(form)) return;

 // Only validate relevant input types
 if (!['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;

 // Clear previous error for this input
 const prevError = target.parentNode.querySelector('.error-message');
 if (prevError) prevError.remove();
 target.classList.remove('input-error');

 // Re-validate this field
 const isRequired = target.hasAttribute('required') || target.getAttribute('aria-required') === 'true';
 const value = target.value.trim();
 if (isRequired && value === '') {
 target.classList.add('input-error');
 const errorEl = document.createElement('div');
 errorEl.className = 'error-message';
 errorEl.setAttribute('role', 'alert');
 errorEl.textContent = `Please fill out the ${target.name || 'field'}.`;
 target.parentNode.insertBefore(errorEl, target.nextSibling);
 return;
 }
 if (target.type === 'email' && value !== '' && !isValidEmail(value)) {
 target.classList.add('input-error');
 const errorEl = document.createElement('div');
 errorEl.className = 'error-message';
 errorEl.setAttribute('role', 'alert');
 errorEl.textContent = 'Please enter a valid email address.';
 target.parentNode.insertBefore(errorEl, target.nextSibling);
 }
 } catch (error) {
 // eslint-disable-next-line no-console
 console.error('Input blur validation error:', error);
 }
 };

 document.addEventListener('DOMContentLoaded', () => {
 initFormValidation();
 focusFirstInvalidFieldOnLoad();

 // Event delegation for realtime validation on blur for better UX
 document.body.addEventListener('blur', validateOnInputBlur, true);
 });

})();

/*
 NOTES:
 - This script strictly handles form validation and submission only.
 - Validation messages use ARIA alerts for screen reader announcements.
 - Validation operates on the contact form present only on the contact page,
 but code is written generically to support any forms with class .contact-form.
 - Uses event delegation to minimize event listeners.
 - Defensive coding and thorough error handling included.
 - Simulated submission replaces actual backend API call (sites without backend).
 - Instant feedback on individual fields on blur improves user experience.
*/