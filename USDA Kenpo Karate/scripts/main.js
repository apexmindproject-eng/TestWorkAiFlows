// main.js - Core functionality and global features for USDA Kenpo Karate website

(() => {
 'use strict';

 // Cache DOM elements for reuse
 const domCache = {
 navList: null,
 navLinks: null,
 navToggleBtn: null,
 mainContent: null,
 heroImage: null,
 logoImage: null,
 contactForm: null,
 formControls: [],
 formErrorSummary: null
 };

 // Utility: Safe selector helper
 const getEl = (selector, parent = document) => parent.querySelector(selector);
 const getAllEls = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Debounce utility for performance optimization
 const debounce = (fn, delay = 200) => {
 let timer = null;
 return (...args) => {
 clearTimeout(timer);
 timer = setTimeout(() => fn.apply(this, args), delay);
 };
 };

 // Set active navigation link based on current URL
 const setActiveNavLink = () => {
 try {
 if (!domCache.navLinks) return;
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';

 domCache.navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 const linkPage = href.split('/').pop();
 if (linkPage === currentPath) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('Error setting active navigation link:', error);
 }
 };

 // Mobile Navigation Toggle
 const initMobileNavToggle = () => {
 try {
 if (!domCache.navList) return;

 // Create toggle button if not present
 let toggleBtn = getEl('.nav-toggle');
 if (!toggleBtn) {
 const navContainer = domCache.navList.parentNode;
 toggleBtn = document.createElement('button');
 toggleBtn.className = 'nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '<span class="hamburger"></span>';
 navContainer.insertBefore(toggleBtn, domCache.navList);
 }

 domCache.navToggleBtn = toggleBtn;

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 domCache.navList.classList.toggle('nav-open');
 });

 // Close nav when link clicked (for mobile usability)
 domCache.navList.addEventListener('click', (e) => {
 if (e.target && e.target.matches('a.nav-link')) {
 if (domCache.navList.classList.contains('nav-open')) {
 domCache.navList.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 }
 });

 // Close nav on Escape key
 document.addEventListener('keydown', (e) => {
 if (e.key === 'Escape' && domCache.navList.classList.contains('nav-open')) {
 domCache.navList.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.focus();
 }
 });
 } catch (error) {
 console.error('Error initializing mobile nav toggle:', error);
 }
 };

 // Smooth scroll for internal anchor links
 const initSmoothScrolling = () => {
 try {
 document.addEventListener('click', (e) => {
 const anchor = e.target.closest('a[href^="#"]');
 if (!anchor) return;

 const href = anchor.getAttribute('href');
 if (href === '#' || href === '') return;

 const target = getEl(href);
 if (target) {
 e.preventDefault();
 target.scrollIntoView({ behavior: 'smooth' });
 // Set focus for accessibility
 target.setAttribute('tabindex', '-1');
 target.focus({ preventScroll: true });
 }
 });
 } catch (error) {
 console.error('Error initializing smooth scrolling:', error);
 }
 };

 // Hero image fade-in animation on home page
 const initHeroImageAnimation = () => {
 try {
 if (!domCache.heroImage) return;
 domCache.heroImage.style.opacity = '0';
 domCache.heroImage.style.transition = 'opacity 1.5s ease-in-out';
 window.requestAnimationFrame(() => {
 domCache.heroImage.style.opacity = '1';
 });
 } catch (error) {
 console.error('Error with hero image animation:', error);
 }
 };

 // Scroll reveal animation for sections
 const initScrollReveal = () => {
 try {
 const reveals = getAllEls('section, article');
 if (!reveals.length) return;
 const revealClass = 'reveal-visible';

 const observer = new IntersectionObserver((entries, obs) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 entry.target.classList.add(revealClass);
 obs.unobserve(entry.target);
 }
 });
 }, {
 rootMargin: '0px 0px -100px 0px',
 threshold: 0.1
 });

 reveals.forEach(el => {
 if (!el.classList.contains(revealClass)) {
 observer.observe(el);
 }
 });
 } catch (error) {
 console.error('Error initializing scroll reveal:', error);
 }
 };

 // Navigation keyboard accessibility for arrow key navigation
 const initNavKeyboardAccessibility = () => {
 try {
 if (!domCache.navList) return;
 domCache.navList.addEventListener('keydown', (e) => {
 if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
 e.preventDefault();
 const links = domCache.navLinks;
 if (!links.length) return;

 const currentIndex = links.indexOf(document.activeElement);
 if (currentIndex === -1) return;

 let nextIndex = currentIndex;
 if (e.key === 'ArrowRight') {
 nextIndex = (currentIndex + 1) % links.length;
 } else if (e.key === 'ArrowLeft') {
 nextIndex = (currentIndex - 1 + links.length) % links.length;
 }

 links[nextIndex].focus();
 }
 });
 } catch (error) {
 console.error('Error with nav keyboard accessibility:', error);
 }
 };

 // Form validation for contact form (basic client-side validation)
 const initContactFormValidation = () => {
 try {
 domCache.contactForm = getEl('#contact-form');
 if (!domCache.contactForm) return;

 domCache.formControls = getAllEls('#contact-form input, #contact-form textarea');

 // Create error summary container
 let errorSummary = getEl('.error-summary');
 if (!errorSummary) {
 errorSummary = document.createElement('div');
 errorSummary.className = 'error-summary';
 errorSummary.setAttribute('role', 'alert');
 errorSummary.setAttribute('aria-live', 'assertive');
 errorSummary.style.display = 'none';
 domCache.contactForm.insertBefore(errorSummary, domCache.contactForm.firstChild);
 }
 domCache.formErrorSummary = errorSummary;

 domCache.contactForm.addEventListener('submit', e => {
 e.preventDefault();
 clearFormValidation();

 const errors = [];

 const nameInput = getEl('#name');
 const emailInput = getEl('#email');
 const messageInput = getEl('#message');

 if (!nameInput || nameInput.value.trim().length < 2) {
 errors.push({ el: nameInput, message: 'Please enter your name (at least 2 characters).' });
 }

 if (!emailInput || !/^\S+@\S+\.\S+$/.test(emailInput.value.trim())) {
 errors.push({ el: emailInput, message: 'Please enter a valid email address.' });
 }

 if (!messageInput || messageInput.value.trim().length < 10) {
 errors.push({ el: messageInput, message: 'Please enter your message (at least 10 characters).' });
 }

 if (errors.length > 0) {
 showFormErrors(errors);
 return;
 }

 // If validated, simulate form submission
 simulateFormSubmission().then(() => {
 showSuccessMessage();
 domCache.contactForm.reset();
 nameInput.focus();
 }).catch(() => {
 showSubmissionError();
 });
 });

 // Clear error messages when user edits inputs
 domCache.contactForm.addEventListener('input', e => {
 if (e.target && domCache.formControls.includes(e.target)) {
 removeErrorMessage(e.target);
 if (domCache.formErrorSummary) {
 domCache.formErrorSummary.innerHTML = '';
 domCache.formErrorSummary.style.display = 'none';
 }
 }
 });

 } catch (error) {
 console.error('Error initializing contact form validation:', error);
 }
 };

 const clearFormValidation = () => {
 domCache.formControls.forEach(input => {
 input.classList.remove('input-error');
 input.removeAttribute('aria-invalid');
 const errorMsg = input.parentNode.querySelector('.error-message');
 if (errorMsg) errorMsg.remove();
 });
 if (domCache.formErrorSummary) {
 domCache.formErrorSummary.innerHTML = '';
 domCache.formErrorSummary.style.display = 'none';
 }
 };

 const showFormErrors = (errors) => {
 if (!domCache.formErrorSummary) return;

 domCache.formErrorSummary.style.display = 'block';
 const ul = document.createElement('ul');
 errors.forEach(({ el, message }) => {
 if (el) {
 el.classList.add('input-error');
 el.setAttribute('aria-invalid', 'true');
 let errorEl = el.parentNode.querySelector('.error-message');
 if (!errorEl) {
 errorEl = document.createElement('p');
 errorEl.className = 'error-message';
 el.parentNode.appendChild(errorEl);
 }
 errorEl.textContent = message;
 }
 const li = document.createElement('li');
 li.textContent = message;
 ul.appendChild(li);
 });
 domCache.formErrorSummary.innerHTML = '';
 domCache.formErrorSummary.appendChild(ul);
 domCache.formErrorSummary.focus();
 };

 const removeErrorMessage = (input) => {
 if (!input) return;
 input.classList.remove('input-error');
 input.removeAttribute('aria-invalid');

 const errorMsg = input.parentNode.querySelector('.error-message');
 if (errorMsg) {
 errorMsg.remove();
 }
 };

 // Simulated async form submission (placeholder for backend integration)
 const simulateFormSubmission = () => {
 return new Promise((resolve) => {
 setTimeout(() => {
 resolve(true);
 }, 1000);
 });
 };

 const showSuccessMessage = () => {
 if (!domCache.formErrorSummary) return;
 domCache.formErrorSummary.style.display = 'block';
 domCache.formErrorSummary.classList.remove('error-message');
 domCache.formErrorSummary.classList.add('success-message');
 domCache.formErrorSummary.textContent = 'Thank you for contacting us! Your message has been sent.';
 };

 const showSubmissionError = () => {
 if (!domCache.formErrorSummary) return;
 domCache.formErrorSummary.style.display = 'block';
 domCache.formErrorSummary.classList.remove('success-message');
 domCache.formErrorSummary.classList.add('error-message');
 domCache.formErrorSummary.textContent = 'An error occurred while sending your message. Please try again.';
 };

 // Initialize all global features
 const initGlobalFeatures = () => {
 try {
 domCache.navList = getEl('.nav-list');
 if (domCache.navList) {
 domCache.navLinks = getAllEls('.nav-list .nav-link');
 }
 domCache.heroImage = getEl('#dojo-image');
 domCache.logoImage = getEl('#logo');
 domCache.mainContent = getEl('#main-content');

 setActiveNavLink();
 initMobileNavToggle();
 initSmoothScrolling();
 initScrollReveal();
 initNavKeyboardAccessibility();

 // Animate hero image only on home page
 if (document.body.id === 'home' && domCache.heroImage) {
 initHeroImageAnimation();
 }

 // Initialize contact form validation if present
 if (document.body.id === 'contact-page' || getEl('#contact-form')) {
 initContactFormValidation();
 }

 } catch (error) {
 console.error('Error initializing global features:', error);
 }
 };

 // Document Ready
 document.addEventListener('DOMContentLoaded', () => {
 initGlobalFeatures();
 });

})();

//# sourceURL=main.js
