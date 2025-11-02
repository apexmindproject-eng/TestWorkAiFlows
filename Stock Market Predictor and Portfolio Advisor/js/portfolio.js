/*
 * portfolio.js
 * Manages the portfolio allocation form, validation, recommendation display,
 * and interactive UI components for the Stock Market Predictor and Portfolio Advisor application.
 *
 * Designed to handle features on portfolio.html and integrate gracefully with other pages.
 *
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility to improve performance on resize and input
 const debounce = (fn, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => fn(...args), wait);
 };
 };

 /**
 * Validates portfolio form fields according to requirements
 * @param {HTMLFormElement} form
 * @returns {boolean}
 */
 const validatePortfolioForm = (form) => {
 try {
 const risk = qs('#risk-tolerance', form);
 const horizon = qs('#investment-horizon', form);
 const amount = qs('#investment-amount', form);

 const errors = [];

 if (!risk || !['low', 'medium', 'high'].includes(risk.value)) {
 errors.push('Please select a valid risk tolerance.');
 }

 const horizonVal = Number(horizon?.value);
 if (!horizon || isNaN(horizonVal) || horizonVal < 1 || horizonVal > 50) {
 errors.push('Investment horizon must be between 1 and 50 years.');
 }

 const amountVal = Number(amount?.value);
 if (!amount || isNaN(amountVal) || amountVal < 1000) {
 errors.push('Investment amount must be at least $1000.');
 }

 if (errors.length > 0) {
 alert(errors.join('\n'));
 return false;
 }
 return true;
 } catch (error) {
 console.error('Portfolio form validation error:', error);
 return false;
 }
 };

 /**
 * Simulate portfolio recommendation calculation
 * Replace with real business logic or service call in production
 * @param {object} preferences
 * @returns {Promise<object>} recommended allocations
 */
 const getPortfolioRecommendation = (preferences) => {
 return new Promise((resolve) => {
 setTimeout(() => {
 // Simple mock recommendation based on risk tolerance
 let allocation = {};
 switch (preferences.riskTolerance) {
 case 'low':
 allocation = { Stocks: 30, Bonds: 50, Cash: 20 };
 break;
 case 'medium':
 allocation = { Stocks: 50, Bonds: 35, Cash: 15 };
 break;
 case 'high':
 allocation = { Stocks: 70, Bonds: 20, Cash: 10 };
 break;
 default:
 allocation = { Stocks: 50, Bonds: 35, Cash: 15 };
 }
 resolve(allocation);
 }, 1000);
 });
 };

 /**
 * Render portfolio recommendation results
 * @param {object} allocation
 * @param {number} amount
 */
 const renderPortfolioResults = (allocation, amount) => {
 const resultsContainer = qs('#recommendation-results');
 if (!resultsContainer) return;

 // Clear previous results
 resultsContainer.innerHTML = '';

 const fragment = document.createDocumentFragment();

 const header = document.createElement('h2');
 header.className = 'section-title';
 header.textContent = 'Portfolio Recommendations';
 fragment.appendChild(header);

 const list = document.createElement('ul');
 list.className = 'recommendation-list';

 for (const [asset, percent] of Object.entries(allocation)) {
 const li = document.createElement('li');
 li.className = 'recommendation-item';
 const dollarAmount = ((percent / 100) * amount).toFixed(2);
 li.textContent = `${asset}: ${percent}% (~$${dollarAmount})`;
 list.appendChild(li);
 }

 fragment.appendChild(list);

 resultsContainer.appendChild(fragment);
 };

 /**
 * Clear the recommendation results
 */
 const clearPortfolioResults = () => {
 const resultsContainer = qs('#recommendation-results');
 if (!resultsContainer) return;
 resultsContainer.innerHTML = '';
 };

 /**
 * Handle portfolio form submission
 * @param {Event} event
 */
 const handlePortfolioSubmit = async (event) => {
 event.preventDefault();

 const form = event.target;

 if (!validatePortfolioForm(form)) return;

 const submitBtn = qs('#submit-portfolio', form);
 if (submitBtn) submitBtn.disabled = true;

 try {
 const riskTolerance = qs('#risk-tolerance', form).value;
 const investmentHorizon = Number(qs('#investment-horizon', form).value);
 const investmentAmount = Number(qs('#investment-amount', form).value);

 clearPortfolioResults();

 renderLoadingIndicator();

 const allocation = await getPortfolioRecommendation({
 riskTolerance,
 investmentHorizon,
 investmentAmount
 });

 renderPortfolioResults(allocation, investmentAmount);
 } catch (error) {
 console.error('Portfolio recommendation error:', error);
 const results = qs('#recommendation-results');
 if (results) {
 results.innerHTML = '<p class="error-text" role="alert">An error occurred while processing your portfolio. Please try again later.</p>';
 }
 } finally {
 if (submitBtn) submitBtn.disabled = false;
 }
 };

 /**
 * Render loading indicator during recommendations fetching
 */
 const renderLoadingIndicator = () => {
 const resultsContainer = qs('#recommendation-results');
 if (!resultsContainer) return;
 resultsContainer.innerHTML = '<p class="loading-text">Calculating recommendations, please wait...</p>';
 };

 /**
 * Setup mobile navigation toggle button for portfolio page if not handled globally
 */
 const setupMobileNavToggle = () => {
 try {
 const header = qs('#portfolio-header');
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
 * Initialize focus outline behavior
 */
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
 } catch (error) {
 console.error('Error setting up focus outline:', error);
 }
 };

 /**
 * Traps keyboard focus within the portfolio form for accessibility
 * @param {HTMLFormElement} form
 */
 const trapFocusWithinForm = (form) => {
 const focusableSelectors = 'a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])';
 const focusableElements = qsa(focusableSelectors, form).filter(el => !el.disabled && el.offsetParent !== null);

 if (focusableElements.length === 0) return;

 const firstEl = focusableElements[0];
 const lastEl = focusableElements[focusableElements.length -1];

 form.addEventListener('keydown', (e) => {
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
 * Initialization on DOMContentLoaded
 */
 document.addEventListener('DOMContentLoaded', () => {
 const portfolioForm = qs('#portfolio-form');
 if (portfolioForm) {
 portfolioForm.addEventListener('submit', handlePortfolioSubmit);
 trapFocusWithinForm(portfolioForm);
 clearPortfolioResults();
 }

 setupMobileNavToggle();
 setupFocusOutlineManagement();
 });

})();

/*
 * NOTES:
 * - Handles client form validation and simulated recommendation fetching
 * - Accessible keyboard management including focus trap
 * - Responsive mobile nav toggle for portfolio page
 * - Defensive and performant coding suitable for production
 */