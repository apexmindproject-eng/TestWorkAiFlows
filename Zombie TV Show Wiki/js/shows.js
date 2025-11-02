/*
 * shows.js
 * JavaScript functionality primarily for shows.html page of Zombie TV Show Wiki
 * While designed mainly for the shows page UI enhancements, includes global utilities
 * such as focus management and mobile nav toggle support for consistency.
 *
 * Key Features:
 * - Show cards interactivity enhancements
 * - Event delegation for efficient event handling
 * - Accessibility improvements
 * - Robust error handling
 * - Performance optimizations
 * - Defensive coding practices
 * 
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 // Utility shortcuts
 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility to optimize event handling
 const debounce = (fn, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => fn(...args), wait);
 };
 };

 /**
 * Setup accessible keyboard focus outline management
 * Adds a class to body when user navigates via keyboard
 */
 const setupFocusOutlineManagement = () => {
 try {
 let keyboardUser = false;
 const body = document.body;

 const onFirstTab = e => {
 if (e.key === 'Tab' || e.keyCode === 9) {
 if (!keyboardUser) {
 body.classList.add('user-is-tabbing');
 keyboardUser = true;
 }
 window.removeEventListener('keydown', onFirstTab);
 window.addEventListener('mousedown', onMouseDown);
 }
 };

 const onMouseDown = () => {
 if (keyboardUser) {
 body.classList.remove('user-is-tabbing');
 keyboardUser = false;
 }
 window.removeEventListener('mousedown', onMouseDown);
 window.addEventListener('keydown', onFirstTab);
 };

 window.addEventListener('keydown', onFirstTab);
 } catch (e) {
 console.error('Error in setupFocusOutlineManagement:', e);
 }
 };

 /**
 * Setup mobile navigation menu toggle button and events
 * Supports pages with different header IDs
 */
 const setupMobileNavToggle = () => {
 try {
 const headerIds = ['site-header', 'about-header', 'shows-header', 'contact-header'];
 let header = null;
 for (const id of headerIds) {
 header = document.getElementById(id);
 if (header) break;
 }
 if (!header) return;

 let toggleBtn = qs('#mobile-nav-toggle', header);
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.type = 'button';
 toggleBtn.innerHTML = '&#9776;'; // hamburger icon

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

 // Close nav menu on outside click or link click
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

 // Handle window resize to close nav menu if desktop
 window.addEventListener('resize', debounce(() => {
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.removeAttribute('tabindex');
 }
 }, 200));
 } catch(e) {
 console.error('Error in setupMobileNavToggle:', e);
 }
 };

 /**
 * Setup show cards interactivity
 * Example enhancement: toggle expanded description on click
 * Uses event delegation for performance
 */
 const setupShowCardsInteractivity = () => {
 try {
 const showsList = qs('#shows-list') || qs('.featured-shows');
 if (!showsList) return;

 showsList.addEventListener('click', e => {
 const showCard = e.target.closest('.show-card');
 if (!showCard || !showsList.contains(showCard)) return;

 // Toggle an expanded state class
 showCard.classList.toggle('expanded');

 // Accessibility: update aria-expanded attribute
 const expanded = showCard.classList.contains('expanded');
 showCard.setAttribute('aria-expanded', expanded ? 'true' : 'false');
 });
 } catch (e) {
 console.error('Error in setupShowCardsInteractivity:', e);
 }
 };

 /**
 * Set initial ARIA attributes to show cards for accessibility
 */
 const setupShowCardsAccessibility = () => {
 try {
 const showCards = qsa('.show-card');
 showCards.forEach(card => {
 card.setAttribute('tabindex', '0'); // Make focusable
 card.setAttribute('role', 'region');
 card.setAttribute('aria-expanded', 'false');
 card.setAttribute('aria-label', card.querySelector('.show-title')?.textContent || 'Show Card');
 });
 } catch (e) {
 console.error('Error setting ARIA attributes on show cards:', e);
 }
 };

 /**
 * Highlight active nav link based on current path
 * Useful if called independently from main.js
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = qsa('.nav-link');
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;

 const normalizedHref = href.replace(/^\.\.\//, '').replace(/\/g, '/');
 if (normalizedHref.endsWith(currentPath) || (currentPath === '' && normalizedHref === 'index.html')) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (e) {
 console.error('Error highlighting active nav link:', e);
 }
 };

 /////////////////////////
 // Initialization
 document.addEventListener('DOMContentLoaded', () => {
 highlightActiveNavLink();
 setupMobileNavToggle();
 setupFocusOutlineManagement();
 setupShowCardsAccessibility();
 setupShowCardsInteractivity();
 });

})();

/*
 * NOTES:
 * - Robust event delegation ensures smooth interaction on show cards
 * - Accessibility tuned with ARIA attributes and keyboard focus
 * - Responsive mobile nav toggle with accessible ARIA control
 * - Defensive code to avoid errors on any page
 * - Performance and code maintainability prioritized
 */