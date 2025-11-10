// utils.js - Utility functions and form validation for Coconut Tree Info
// This module provides robust client-side form validation and submission feedback
// It also contains utility functions that can be used across all pages

'use strict';

// Wrap in IIFE to keep scope local
(() => {
 const select = (selector, parent = document) => parent.querySelector(selector);
 const selectAll = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Email regex pattern for basic validation (RFC 5322 simplified)
 const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

 // Utility: Check if string is empty or whitespace
 const isEmptyOrWhitespace = (str) => !str || !str.trim();

 // Utility: Show error message for an input element
 const showError = (inputEl, message) => {
 try {
 if (!inputEl) return;

 removeError(inputEl); // Remove existing error if any

 const errorEl = document.createElement('span');
 errorEl.className = 'input-error';
 errorEl.textContent = message;
 errorEl.setAttribute('aria-live', 'assertive');

 // Add aria-invalid attribute for accessibility
 inputEl.setAttribute('aria-invalid', 'true');

 // Insert error message immediately after the input
 if (inputEl.parentNode) {
 inputEl.parentNode.insertBefore(errorEl, inputEl.nextSibling);
 }

 // Add error class to input for styling
 inputEl.classList.add('input-error-border');
 } catch (error) {
 console.error('showError error:', error);
 }
 };

 // Utility: Remove error message and styling from input element
 const removeError = (inputEl) => {
 try {
 if (!inputEl) return;

 inputEl.removeAttribute('aria-invalid');
 inputEl.classList.remove('input-error-border');

 // Remove existing error message span if any exists
 const nextEl = inputEl.nextElementSibling;
 if (nextEl && nextEl.classList.contains('input-error')) {
 nextEl.remove();
 }
 } catch (error) {
 console.error('removeError error:', error);
 }
 };

 // Validate name field: non-empty, no digits or symbols (basic alpha with spaces allowed)
 const validateName = (name) => {
 if (isEmptyOrWhitespace(name)) {
 return 'Name is required.';
 }
 // Check for invalid characters (digits, special chars except space, dash, apostrophe)
 const invalidChars = /[^a-zA-Z\s\-']/;
 if (invalidChars.test(name)) {
 return 'Name contains invalid characters.';
 }
 if (name.length > 100) {
 return 'Name is too long.';
 }
 return null; // valid
 };

 // Validate email field with regex pattern
 const validateEmail = (email) => {
 if (isEmptyOrWhitespace(email)) {
 return 'Email is required.';
 }
 if (!emailPattern.test(email)) {
 return 'Email format is invalid.';
 }
 if (email.length > 254) { // RFC 5321 limit
 return 'Email is too long.';
 }
 return null;
 };

 // Validate message field: non-empty and reasonable length
 const validateMessage = (message) => {
 if (isEmptyOrWhitespace(message)) {
 return 'Message cannot be empty.';
 }
 if (message.length > 1000) {
 return 'Message is too long (maximum 1000 characters).';
 }
 return null;
 };

 // Validate entire contact form
 // Returns true if valid; false if errors found
 const validateContactForm = (formEl) => {
 if (!formEl) return false;

 let isFormValid = true;

 try {
 const nameInput = select('#name', formEl);
 const emailInput = select('#email', formEl);
 const messageInput = select('#message', formEl);

 removeError(nameInput);
 removeError(emailInput);
 removeError(messageInput);

 const nameError = validateName(nameInput ? nameInput.value : '');
 const emailError = validateEmail(emailInput ? emailInput.value : '');
 const messageError = validateMessage(messageInput ? messageInput.value : '');

 if (nameError && nameInput) {
 showError(nameInput, nameError);
 isFormValid = false;
 }
 if (emailError && emailInput) {
 showError(emailInput, emailError);
 isFormValid = false;
 }
 if (messageError && messageInput) {
 showError(messageInput, messageError);
 isFormValid = false;
 }
 } catch (error) {
 console.error('Error validating contact form:', error);
 isFormValid = false;
 }

 return isFormValid;
 };

 // Utility: Clear all errors in the form
 const clearFormErrors = (formEl) => {
 if (!formEl) return;
 try {
 const inputs = selectAll('input, textarea', formEl);
 inputs.forEach(input => removeError(input));
 } catch (error) {
 console.error('clearFormErrors error:', error);
 }
 };

 // Initialization to set up form validation event handling
 const initFormValidation = () => {
 try {
 const contactForm = select('#contact-form');
 if (!contactForm) return;

 // Validate inputs on input blur (real-time feedback)
 const fields = ['name', 'email', 'message'];
 fields.forEach(id => {
 const field = select(`#${id}`, contactForm);
 if (!field) return;

 field.addEventListener('blur', () => {
 // Validate the focused field only
 clearFormErrors(contactForm);
 validateContactForm(contactForm);
 });
 });

 // Prevent multiple submissions
 let isSubmitting = false;

 contactForm.addEventListener('submit', async (event) => {
 event.preventDefault();
 if (isSubmitting) return; // Prevent repeated submits

 clearFormErrors(contactForm);
 const isValid = validateContactForm(contactForm);
 if (!isValid) {
 // Focus the first invalid input
 const firstInvalid = select('.input-error-border', contactForm);
 if (firstInvalid) firstInvalid.focus();
 return;
 }

 isSubmitting = true;

 // Disable submit button and show sending state
 const submitBtn = select('#submit-button', contactForm);
 if (submitBtn) {
 submitBtn.disabled = true;
 submitBtn.textContent = 'Sending...';
 }

 // Simulate or perform async form submission here
 // Since the form action is '#', simulate success after a timeout
 try {
 await new Promise(resolve => setTimeout(resolve, 1200)); // Simulated async wait
 alert('Thank you for your message! We will get back to you soon.');
 contactForm.reset();
 clearFormErrors(contactForm);
 } catch (asyncError) {
 alert('There was a problem sending your message. Please try again later.');
 console.error('Async submission error:', asyncError);
 } finally {
 if (submitBtn) {
 submitBtn.disabled = false;
 submitBtn.textContent = 'Send Message';
 }
 isSubmitting = false;
 }
 });
 } catch (error) {
 console.error('initFormValidation error:', error);
 }
 };

 // Form enhancement to improve accessibility and usability
 // Adds ARIA roles, live regions for errors are handled in showError
 const enhanceFormAccessibility = () => {
 try {
 const contactForm = select('#contact-form');
 if (!contactForm) return;

 // Add role form for accessibility
 contactForm.setAttribute('role', 'form');

 // Add novalidate to disable native validation - we handle it ourselves
 contactForm.setAttribute('novalidate', '');

 // Label focus styles and fieldset enhancements could be added here if needed
 } catch (error) {
 console.error('enhanceFormAccessibility error:', error);
 }
 };


 // Initialize script on DOMContentLoaded
 const init = () => {
 try {
 initFormValidation();
 enhanceFormAccessibility();
 } catch (error) {
 console.error('utils.js initialization error:', error);
 }
 };

 document.addEventListener('DOMContentLoaded', init);

})();

//# sourceMappingURL=utils.js.map
