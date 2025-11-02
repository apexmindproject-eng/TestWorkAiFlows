/*
 * main.js
 * Core JavaScript for Stock Market Predictor and Portfolio Advisor
 * Handles navigation, global UI features, active link management,
 * form validation orchestration, accessibility enhancements,
 * and performance optimizations across all 4 main pages.
 *
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 // Shortcuts
 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility
 const debounce = (fn, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => fn(...args), wait);
 };
 };

 /////////////////////////
 // Active Navigation Link Handling
 const highlightActiveNavLink = () => {
 try {
 const navLinks = qsa('.nav-link');
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 // Normalize href path
 const normalizedHref = href.replace(/^\.\.\//, '').replace(/\/g, '/');
 if (normalizedHref.endsWith(currentPath) ||
 (currentPath === '' && normalizedHref === 'index.html')) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (err) {
 console.error('Error highlighting nav link:', err);
 }
 };

 /////////////////////////
 // Mobile Navigation Toggle
 const setupMobileNavToggle = () => {
 try {
 // Determine header container (different ids on pages)
 const headers = ['?id^="site-header"', '?id^="portfolio-header"', '?id^="prediction-header"', '?id^="about-header"'];
 let header = null;
 for (const idSelector of headers) {
 header = qs(idSelector);
 if (header) break;
 }
 if (!header) return;

 // Check or create toggle button
 let toggleBtn = qs('#mobile-nav-toggle', header);
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.type = 'button';
 toggleBtn.innerHTML = '&#9776;';
 
 // Prefer inserting before nav
 const nav = qs('.navigation', header);
 if (nav) {
 header.insertBefore(toggleBtn, nav);
 } else {
 header.appendChild(toggleBtn);
 }
 }

 const nav = qs('.navigation', header);
 if (!nav) return;

 // Toggle menu handler
 const toggleMenu = () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 nav.classList.toggle('nav-open', !expanded);

 if (!expanded) {
 nav.setAttribute('tabindex', '-1');
 nav.focus();
 } else {
 nav.removeAttribute('tabindex');
 }
 };

 toggleBtn.addEventListener('click', toggleMenu);

 // Close nav if clicking outside or on a nav link
 document.body.addEventListener('click', e => {
 if (!nav.contains(e.target) && !toggleBtn.contains(e.target) && nav.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.classList.remove('nav-open');
 nav.removeAttribute('tabindex');
 }
 if (nav.contains(e.target) && e.target.classList.contains('nav-link') && nav.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.classList.remove('nav-open');
 nav.removeAttribute('tabindex');
 }
 });

 // On viewport resize, close nav menu if expanded and width large
 window.addEventListener('resize', debounce(() => {
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.removeAttribute('tabindex');
 }
 }, 200));

 } catch (err) {
 console.error('Error setting up mobile nav toggle:', err);
 }
 };

 /////////////////////////
 // Smooth Internal Link Scrolling
 const setupSmoothScroll = () => {
 try {
 document.body.addEventListener('click', e => {
 const anchor = e.target.closest('a[href^="#"]');
 if (!anchor) return;
 const href = anchor.getAttribute('href');
 if (!href) return;

 const targetId = href.slice(1);
 if (!targetId) return;

 const target = qs(`#${targetId}`);
 if (!target) return;

 e.preventDefault();

 target.scrollIntoView({ behavior: 'smooth', block: 'start' });

 // Set focus for accessibility after scroll
 target.setAttribute('tabindex', '-1');
 target.focus({ preventScroll: true });
 });
 } catch (err) {
 console.error('Error setting up smooth scroll:', err);
 }
 };

 /////////////////////////
 // Accessibility: Manage focus ring for keyboard navigation only
 const setupFocusOutlineManagement = () => {
 try {
 let keyboardUser = false;
 const body = document.body;

 const handleFirstTab = e => {
 if (e.key === 'Tab' || e.keyCode === 9) {
 if (!keyboardUser) {
 body.classList.add('user-is-tabbing');
 keyboardUser = true;
 }
 window.removeEventListener('keydown', handleFirstTab);
 window.addEventListener('mousedown', handleMouseDown);
 }
 };

 const handleMouseDown = () => {
 if (keyboardUser) {
 body.classList.remove('user-is-tabbing');
 keyboardUser = false;
 }
 window.removeEventListener('mousedown', handleMouseDown);
 window.addEventListener('keydown', handleFirstTab);
 };

 window.addEventListener('keydown', handleFirstTab);
 } catch (err) {
 console.error('Error setting up focus outline management:', err);
 }
 };

 /////////////////////////
 // Form Validation Setup
 // We detect existence of portfolio and prediction forms and attach client validation
 const setupFormsValidation = () => {
 try {
 // Portfolio form validation
 const portfolioForm = qs('#portfolio-form');
 if (portfolioForm) {
 portfolioForm.addEventListener('submit', e => {
 e.preventDefault();
 if (validatePortfolioForm(portfolioForm)) {
 portfolioForm.querySelector('#submit-portfolio').disabled = true;
 // Trigger custom event or handle submission here
 // For now, simple success message or processing can be added
 alert('Portfolio preferences accepted. Processing recommendations...');
 // Re-enable button after processing simulation
 setTimeout(() => {
 portfolioForm.querySelector('#submit-portfolio').disabled = false;
 }, 1500);
 }
 });
 }

 // Prediction form validation
 const predictionForm = qs('#prediction-form');
 if (predictionForm) {
 predictionForm.addEventListener('submit', e => {
 e.preventDefault();
 if (validatePredictionForm(predictionForm)) {
 predictionForm.querySelector('#submit-prediction').disabled = true;
 alert('Prediction request submitted. Please wait...');
 setTimeout(() => {
 predictionForm.querySelector('#submit-prediction').disabled = false;
 }, 1500);
 }
 });
 }
 } catch (err) {
 console.error('Error setting up form validation:', err);
 }
 };

 // Portfolio form validation rules
 const validatePortfolioForm = form => {
 try {
 const risk = form.querySelector('#risk-tolerance');
 const horizon = form.querySelector('#investment-horizon');
 const amount = form.querySelector('#investment-amount');
 let valid = true;
 let messages = [];

 if (!risk || !['low', 'medium', 'high'].includes(risk.value)) {
 valid = false;
 messages.push('Please select a valid Risk Tolerance.');
 }

 if (!horizon || !horizon.value || Number(horizon.value) < 1 || Number(horizon.value) > 50) {
 valid = false;
 messages.push('Investment Horizon must be between 1 and 50 years.');
 }

 if (!amount || !amount.value || Number(amount.value) < 1000) {
 valid = false;
 messages.push('Investment Amount must be at least $1000.');
 }

 if (!valid) {
 alert(messages.join('\n'));
 }

 return valid;
 } catch (err) {
 console.error('Error validating portfolio form:', err);
 return false;
 }
 };

 // Prediction form validation rules
 const validatePredictionForm = form => {
 try {
 const symbol = form.querySelector('#stock-symbol');
 const timeframe = form.querySelector('#timeframe');
 let valid = true;
 let messages = [];

 if (!symbol || !symbol.value.trim()) {
 valid = false;
 messages.push('Stock Symbol is required.');
 }
 if (!timeframe || !timeframe.value) {
 valid = false;
 messages.push('Please select a timeframe.');
 }

 if (!valid) {
 alert(messages.join('\n'));
 }

 return valid;
 } catch (err) {
 console.error('Error validating prediction form:', err);
 return false;
 }
 };

 /////////////////////////
 // Initialization on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 highlightActiveNavLink();
 setupMobileNavToggle();
 setupSmoothScroll();
 setupFocusOutlineManagement();
 setupFormsValidation();
 });

})();

/*
 * NOTES:
 * - This script handles critical global functionalities, including:
 * - Navigation toggling with ARIA support
 * - Active link management for all nav bars
 * - Smooth scrolling of anchor links
 * - Keyboard accessibility for focus outlines
 * - Client-side validation for existing forms on portfolio and prediction pages
 * - Designed to be robust, performant, and maintainable
 * - Defensive coding ensures no failures if elements missing on pages
 */