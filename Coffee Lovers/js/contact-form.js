// contact-form.js - Handles contact form validation and submission for Coffee Lovers website

(() => {
 'use strict';

 // Cache DOM elements used in the form
 const domCache = {
 form: null,
 nameInput: null,
 emailInput: null,
 messageInput: null,
 submitBtn: null,
 errorSummary: null,
 };

 // Regex for email validation (RFC 5322 simplified)
 const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

 // Create an element to show error summary or messages near the form
 const createErrorSummary = () => {
 const container = document.createElement('div');
 container.className = 'error-summary';
 container.setAttribute('role', 'alert');
 container.setAttribute('aria-live', 'assertive');
 container.style.display = 'none';
 if (domCache.form) {
 domCache.form.insertBefore(container, domCache.form.firstChild);
 }
 return container;
 };

 // Clear previous validation messages and states
 const clearValidation = () => {
 if (!domCache.form) return;
 const formControls = domCache.form.querySelectorAll('.form-control');
 formControls.forEach(input => {
 input.classList.remove('input-error');
 // Remove aria-invalid attribute when valid
 input.removeAttribute('aria-invalid');
 // Remove error message if any
 const existingError = input.parentNode.querySelector('.error-message');
 if (existingError) {
 existingError.remove();
 }
 });
 if (domCache.errorSummary) {
 domCache.errorSummary.style.display = 'none';
 domCache.errorSummary.innerHTML = '';
 }
 };

 // Show error message for a form control
 const showError = (input, message) => {
 if (!input) return;

 input.classList.add('input-error');
 input.setAttribute('aria-invalid', 'true');

 // Show message after input
 let errorMessage = document.createElement('p');
 errorMessage.className = 'error-message';
 errorMessage.textContent = message;
 errorMessage.setAttribute('aria-live', 'polite');
 input.parentNode.appendChild(errorMessage);
 };

 // Validate form fields manually
 const validateForm = () => {
 clearValidation();
 if (!domCache.form) return false;

 let isValid = true;
 const errors = [];

 // Validate name
 const nameVal = domCache.nameInput ? domCache.nameInput.value.trim() : '';
 if (!nameVal) {
 isValid = false;
 errors.push('Name is required.');
 showError(domCache.nameInput, 'Please enter your name.');
 } else if (nameVal.length < 2) {
 isValid = false;
 errors.push('Name must be at least 2 characters long.');
 showError(domCache.nameInput, 'Name must be at least 2 characters.');
 }

 // Validate email
 const emailVal = domCache.emailInput ? domCache.emailInput.value.trim() : '';
 if (!emailVal) {
 isValid = false;
 errors.push('Email is required.');
 showError(domCache.emailInput, 'Please enter your email.');
 } else if (!emailRegex.test(emailVal)) {
 isValid = false;
 errors.push('Email format is invalid.');
 showError(domCache.emailInput, 'Please enter a valid email address.');
 }

 // Validate message
 const messageVal = domCache.messageInput ? domCache.messageInput.value.trim() : '';
 if (!messageVal) {
 isValid = false;
 errors.push('Message is required.');
 showError(domCache.messageInput, 'Please enter your message.');
 } else if (messageVal.length < 10) {
 isValid = false;
 errors.push('Message must be at least 10 characters long.');
 showError(domCache.messageInput, 'Message must be at least 10 characters.');
 }

 // Show error summary if errors exist
 if (!isValid && domCache.errorSummary) {
 domCache.errorSummary.style.display = 'block';
 const ul = document.createElement('ul');
 errors.forEach(err => {
 const li = document.createElement('li');
 li.textContent = err;
 ul.appendChild(li);
 });
 domCache.errorSummary.innerHTML = '';
 domCache.errorSummary.appendChild(ul);
 // Focus on summary for accessibility
 domCache.errorSummary.focus();
 }

 return isValid;
 };

 // Disable form controls during processing
 const setFormEnabledState = (enabled = true) => {
 if (!domCache.form) return;
 const controls = domCache.form.querySelectorAll('input, textarea, button');
 controls.forEach(control => {
 control.disabled = !enabled;
 });
 };

 // Simulate form submission (since no backend is specified)
 const submitForm = () => {
 return new Promise((resolve) => {
 // Simulate network delay
 setTimeout(() => {
 resolve({ success: true });
 }, 1000);
 });
 };

 // Clear form inputs after successful submission
 const clearForm = () => {
 if (!domCache.form) return;
 domCache.form.reset();
 };

 // Display a success message after submission
 const showSuccessMessage = () => {
 if (!domCache.errorSummary) return;
 domCache.errorSummary.style.display = 'block';
 domCache.errorSummary.classList.add('success-message');
 domCache.errorSummary.textContent = 'Thank you for reaching out! Your message has been sent.';
 };

 // Remove success message styling when form edits
 const removeSuccessMessage = () => {
 if (!domCache.errorSummary) return;
 domCache.errorSummary.classList.remove('success-message');
 domCache.errorSummary.textContent = '';
 domCache.errorSummary.style.display = 'none';
 };

 // Set up event listeners on form
 const initFormListeners = () => {
 if (!domCache.form) return;

 domCache.form.addEventListener('submit', async (e) => {
 e.preventDefault();
 removeSuccessMessage();

 if (!validateForm()) {
 return;
 }

 // Disable form while processing
 setFormEnabledState(false);

 try {
 const response = await submitForm();
 if (response && response.success) {
 clearForm();
 showSuccessMessage();
 domCache.nameInput.focus();
 } else {
 throw new Error('Submission failed. Please try again.');
 }
 } catch (error) {
 if (domCache.errorSummary) {
 domCache.errorSummary.style.display = 'block';
 domCache.errorSummary.textContent = error.message || 'An error occurred. Please try again later.';
 domCache.errorSummary.classList.remove('success-message');
 domCache.errorSummary.classList.add('error-message');
 }
 } finally {
 setFormEnabledState(true);
 }
 });

 // Remove success/error messages when user starts typing again
 ['input', 'change'].forEach(evtName => {
 domCache.form.addEventListener(evtName, (e) => {
 if (e.target && (e.target.matches('input') || e.target.matches('textarea'))) {
 removeSuccessMessage();
 // Also remove error under the input if present
 const siblingError = e.target.parentNode.querySelector('.error-message');
 if (siblingError) {
 siblingError.remove();
 e.target.classList.remove('input-error');
 e.target.removeAttribute('aria-invalid');
 }

 if (domCache.errorSummary) {
 domCache.errorSummary.style.display = 'none';
 domCache.errorSummary.innerHTML = '';
 }
 }
 });
 });
 };

 // Public initialization
 const initContactForm = () => {
 try {
 domCache.form = document.getElementById('contact-form');
 if (!domCache.form) return; // No form on page

 domCache.nameInput = domCache.form.querySelector('#name');
 domCache.emailInput = domCache.form.querySelector('#email');
 domCache.messageInput = domCache.form.querySelector('#message');
 domCache.submitBtn = domCache.form.querySelector('.btn-submit');

 domCache.errorSummary = createErrorSummary();

 initFormListeners();
 } catch (error) {
 console.error('Error initializing contact form:', error);
 }
 };

 // DOMContentLoaded event
 document.addEventListener('DOMContentLoaded', () => {
 // Only initialize form script if on contact page or form exists
 if (document.body.id === 'contact-page' || document.getElementById('contact-form')) {
 initContactForm();
 }
 });

})();

//# sourceURL=contact-form.js
