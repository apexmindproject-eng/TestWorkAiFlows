// formHandler.js
// Handles form validation, submission, and interactive form enhancements across the entire Website Builder project

(() => {
 'use strict';

 // Utility selectors
 const qs = (selector, parent = document) => parent.querySelector(selector);
 const qsa = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Email validation regex
 const emailRegex = /^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,7}$/;

 // Show error message for input
 const showError = (input, message) => {
 try {
 if (!input) return;
 input.classList.add('input-error');
 let errorElem = input.parentNode.querySelector('.error-message');
 if (!errorElem) {
 errorElem = document.createElement('span');
 errorElem.className = 'error-message';
 errorElem.setAttribute('aria-live', 'assertive');
 input.parentNode.appendChild(errorElem);
 }
 errorElem.textContent = message;
 } catch (e) {
 console.error('showError:', e);
 }
 };

 // Clear error message for input
 const clearError = (input) => {
 try {
 if (!input) return;
 input.classList.remove('input-error');
 const errorElem = input.parentNode.querySelector('.error-message');
 if (errorElem) {
 errorElem.textContent = '';
 }
 } catch (e) {
 console.error('clearError:', e);
 }
 };

 // Validate individual input
 const validateInput = (input) => {
 try {
 clearError(input);
 const value = input.value.trim();
 if (input.hasAttribute('required') && !value) {
 showError(input, 'This field is required.');
 return false;
 }

 if (input.type === 'email' && value && !emailRegex.test(value)) {
 showError(input, 'Please enter a valid email address.');
 return false;
 }

 // Additional type or pattern validations can be added here
 return true;
 } catch (e) {
 console.error('validateInput:', e);
 return false;
 }
 };

 // Validate entire form
 const validateForm = (form) => {
 if (!form) return false;
 const inputs = qsa('input, textarea, select', form);
 let valid = true;
 inputs.forEach(input => {
 if (!validateInput(input)) {
 valid = false;
 }
 });
 return valid;
 };

 // Clear all errors in a form
 const clearFormErrors = (form) => {
 if (!form) return;
 qsa('input, textarea, select', form).forEach(clearError);
 };

 // Show success message in form
 const showSuccessMessage = (form, message) => {
 try {
 let successElem = qs('.form-success-message', form);
 if (!successElem) {
 successElem = document.createElement('div');
 successElem.className = 'form-success-message';
 successElem.setAttribute('role', 'alert');
 successElem.style.color = 'green';
 successElem.style.marginTop = '1rem';
 form.appendChild(successElem);
 }
 successElem.textContent = message;
 setTimeout(() => {
 if (successElem) {
 successElem.textContent = '';
 }
 }, 7000);
 } catch (e) {
 console.error('showSuccessMessage:', e);
 }
 };

 // Handle form submit asynchronously
 const submitForm = async (form) => {
 try {
 if (!form) return false;

 let formData = new FormData(form);
 // Convert FormData to JSON object
 const data = {};
 formData.forEach((value, key) => {
 data[key] = value;
 });

 // Simulate async form submission delay
 await new Promise(resolve => setTimeout(resolve, 1000));

 // In real implementation, use fetch or XMLHttpRequest to POST data
 // Example:
 // const response = await fetch(form.action || '/submit', {
 // method: form.method || 'POST',
 // headers: {'Content-Type': 'application/json'},
 // body: JSON.stringify(data)
 // });
 // if (!response.ok) throw new Error('Network response was not ok');

 // For demo, consider success
 form.reset();
 clearFormErrors(form);
 showSuccessMessage(form, 'Thank you for your message! We will get back to you shortly.');
 return true;
 } catch (err) {
 console.error('submitForm error:', err);
 alert('An error occurred while submitting the form. Please try again later.');
 return false;
 }
 };

 // Setup real-time validation on inputs
 const setupRealtimeValidation = (form) => {
 if (!form) return;
 form.addEventListener('input', event => {
 const input = event.target;
 if (!input || !(input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement || input instanceof HTMLSelectElement)) return;
 validateInput(input);
 });

 // Blur event validation for accessibility
 form.addEventListener('blur', event => {
 const input = event.target;
 if (!input || !(input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement || input instanceof HTMLSelectElement)) return;
 validateInput(input);
 }, true);
 };

 // Handle form submit event
 const handleFormSubmit = (event) => {
 try {
 const form = event.target;
 if (!form || !(form instanceof HTMLFormElement)) return;
 event.preventDefault();
 clearFormErrors(form);
 if (validateForm(form)) {
 submitForm(form);
 } else {
 // Focus first error
 const firstError = qs('.input-error', form);
 if (firstError) firstError.focus();
 }
 } catch (e) {
 console.error('handleFormSubmit:', e);
 }
 };

 // Initialize all forms on the page
 const initForms = () => {
 try {
 const forms = qsa('form');
 if (forms.length === 0) return;
 forms.forEach(form => {
 setupRealtimeValidation(form);
 form.addEventListener('submit', handleFormSubmit);
 });
 } catch (e) {
 console.error('initForms:', e);
 }
 };

 // Initialization function
 const init = () => {
 initForms();
 };

 // Run initialization on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (e) {
 console.error('formHandler.js initialization error:', e);
 }
 });

})();

// End of formHandler.js
