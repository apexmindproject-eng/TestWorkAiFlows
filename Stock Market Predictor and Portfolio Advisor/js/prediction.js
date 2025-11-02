/*
 * prediction.js
 * Manages prediction form interactions and dynamic UI features
 * for Stock Market Predictor and Portfolio Advisor across all pages.
 *
 * Focuses on prediction.html where form exists and enhances UX globally.
 *
 * Includes validation, accessibility improvements, event delegation,
 * efficient DOM manipulation, error handling, and maintainability.
 *
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility to optimize rapid event triggers
 const debounce = (fn, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => fn(...args), wait);
 };
 };

 /**
 * Validate prediction form inputs
 * @param {HTMLFormElement} form
 * @returns {boolean} true if valid, false otherwise
 */
 const validatePredictionForm = (form) => {
 try {
 const symbolInput = qs('#stock-symbol', form);
 const timeframeSelect = qs('#timeframe', form);
 const errors = [];

 if (!symbolInput || !symbolInput.value.trim()) {
 errors.push('Stock Symbol is required.');
 } else if (!/^[A-Za-z0-9\.\-_]{1,10}$/.test(symbolInput.value.trim())) {
 errors.push('Stock Symbol contains invalid characters.');
 }

 if (!timeframeSelect || !timeframeSelect.value) {
 errors.push('Please select a timeframe.');
 }

 if (errors.length > 0) {
 alert(errors.join('\n'));
 return false;
 }

 return true;
 } catch (error) {
 console.error('Validation error:', error);
 return false;
 }
 };

 /**
 * Simulate fetching stock prediction from API
 * In real app, replace with actual AJAX / fetch call.
 * @param {string} symbol
 * @param {string} timeframe
 * @returns {Promise<Object>}
 */
 const fetchPrediction = (symbol, timeframe) => {
 return new Promise((resolve) => {
 // Simulate network delay
 setTimeout(() => {
 // Generate fake prediction data
 const trends = ['Bullish','Bearish','Neutral','Volatile'];
 const trend = trends[Math.floor(Math.random() * trends.length)];
 const confidence = (Math.random()*50 + 50).toFixed(2); // Confidence 50-100%

 resolve({
 symbol: symbol.toUpperCase(),
 timeframe,
 trend,
 confidence: `${confidence}%`
 });
 }, 1200);
 });
 };

 /**
 * Render prediction results into the output container
 * @param {Object} prediction
 */
 const renderPredictionResults = (prediction) => {
 const output = qs('#prediction-output');
 if (!output) return;

 output.innerHTML = `
 <div class="prediction-summary">
 <p><strong>Stock Symbol:</strong> ${prediction.symbol}</p>
 <p><strong>Timeframe:</strong> ${prediction.timeframe}</p>
 <p><strong>Predicted Trend:</strong> ${prediction.trend}</p>
 <p><strong>Confidence Level:</strong> ${prediction.confidence}</p>
 </div>
 `;
 };

 /**
 * Clear prediction results UI
 */
 const clearPredictionResults = () => {
 const output = qs('#prediction-output');
 if (!output) return;
 output.innerHTML = '<p class="placeholder-text">Enter stock symbol and select a timeframe to view the prediction.</p>';
 };

 /**
 * Handle prediction form submission
 * @param {Event} e
 */
 const handlePredictionSubmit = async (e) => {
 e.preventDefault();
 const form = e.target;
 if (!validatePredictionForm(form)) return;

 const submitBtn = qs('#submit-prediction', form);
 if (submitBtn) submitBtn.disabled = true;

 try {
 const symbol = qs('#stock-symbol', form).value.trim();
 const timeframe = qs('#timeframe', form).value;

 renderLoadingIndicator();

 const prediction = await fetchPrediction(symbol, timeframe);

 renderPredictionResults(prediction);
 } catch (error) {
 console.error('Error fetching prediction:', error);
 renderError('Failed to retrieve prediction. Please try again later.');
 } finally {
 if (submitBtn) submitBtn.disabled = false;
 }
 };

 /**
 * Render loading indicator in prediction output
 */
 const renderLoadingIndicator = () => {
 const output = qs('#prediction-output');
 if (!output) return;
 output.innerHTML = '<p class="loading-text">Loading prediction, please wait...</p>';
 };

 /**
 * Render error message in prediction output
 * @param {string} message
 */
 const renderError = (message) => {
 const output = qs('#prediction-output');
 if (!output) return;
 output.innerHTML = `<p class="error-text" role="alert">${message}</p>`;
 };

 /**
 * Initialize mobile navigation toggle (in case main.js doesn't handle)
 * For redundancy and site consistency
 */
 const setupMobileNavToggle = () => {
 try {
 const header = qs('#prediction-header');
 if (!header) return;

 let toggleBtn = qs('#mobile-nav-toggle', header);
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.type = 'button';
 toggleBtn.innerHTML = '&#9776;';
 const nav = qs('.navigation', header);
 if (nav) {
 header.insertBefore(toggleBtn, nav);
 } else {
 header.appendChild(toggleBtn);
 }
 }

 const nav = qs('.navigation', header);
 if (!nav) return;

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

 window.addEventListener('resize', debounce(() => {
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.removeAttribute('tabindex');
 }
 }, 200));
 } catch (error) {
 console.error('Error setting up mobile nav toggle:', error);
 }
 };

 /**
 * Accessibility: Trap focus within prediction form section when open
 * Ensures keyboard users do not lose context
 */
 const trapFocusWithinForm = (form) => {
 const focusableSelectors = 'a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])';
 const focusableElements = qsa(focusableSelectors, form).filter(el => !el.disabled && el.offsetParent !== null);

 if (focusableElements.length === 0) return;

 const firstEl = focusableElements[0];
 const lastEl = focusableElements[focusableElements.length - 1];

 form.addEventListener('keydown', e => {
 if (e.key === 'Tab' || e.keyCode === 9) {
 if (e.shiftKey) {
 if (document.activeElement === firstEl) {
 lastEl.focus();
 e.preventDefault();
 }
 } else {
 if (document.activeElement === lastEl) {
 firstEl.focus();
 e.preventDefault();
 }
 }
 }
 });
 };

 /**
 * Initialization
 */
 document.addEventListener('DOMContentLoaded', () => {
 const predictionForm = qs('#prediction-form');
 if (predictionForm) {
 predictionForm.addEventListener('submit', handlePredictionSubmit);
 trapFocusWithinForm(predictionForm);
 clearPredictionResults();
 }

 setupMobileNavToggle();
 });

})();

/*
 * NOTES:
 * - Designed to be modular for usage only on prediction page or globally without errors
 * - Form validation includes regex for symbol format and presence
 * - Simulated async fetch for predictions with latency simulation
 * - Accessible focus management for keyboard users
 * - Mobile nav toggle for responsive design consistency
 * - Defensive coding with try/catch and null checks
 * - Extensive comments for maintainability
 */