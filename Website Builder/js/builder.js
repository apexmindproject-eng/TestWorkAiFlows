/*
 builder.js - Core JavaScript for Website Builder project
 Handles global site navigation, mobile menu toggle, active link highlighting across all pages,
 and enhances interactive UI components found in all four pages:
 index.html, editor.html, templates.html, about.html

 Note: Other scripts (editor.js, templates.js) handle page-specific advanced features.
*/

(() => {
 'use strict';

 // Helper: Safely query single element
 const qs = (selector, scope = document) => scope.querySelector(selector);

 // Helper: Safely query multiple elements
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility to optimize frequent events like resize
 const debounce = (func, wait = 150) => {
 let timeoutId;
 return (...args) => {
 clearTimeout(timeoutId);
 timeoutId = setTimeout(() => func.apply(null, args), wait);
 };
 };

 // ====== Mobile Navigation Toggle ======
 // Creates toggle button, manages open/close state and accessibility attributes
 const initMobileNav = () => {
 try {
 const header = qs('#site-header');
 if (!header) return;

 // Prevent adding toggle multiple times
 if (qs('#mobile-nav-toggle')) return;

 const nav = qs('#main-navigation', header);
 if (!nav) return;

 // Create toggle button
 const toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-controls', 'main-navigation');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.classList.add('mobile-nav-toggle');
 toggleBtn.innerHTML = '&#9776;'; // Hamburger icon

 header.insertBefore(toggleBtn, nav);

 toggleBtn.addEventListener('click', () => {
 try {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 nav.classList.toggle('nav-open');
 toggleBtn.classList.toggle('active');
 document.body.classList.toggle('nav-open');
 } catch (err) {
 console.error('Error toggling mobile nav:', err);
 }
 });

 // Close nav on clicking outside nav or toggle button
 document.addEventListener('click', (event) => {
 try {
 if (!nav.classList.contains('nav-open')) return;
 const clickInsideNav = nav.contains(event.target);
 const clickOnToggle = toggleBtn.contains(event.target);
 if (!clickInsideNav && !clickOnToggle) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 document.body.classList.remove('nav-open');
 }
 } catch (err) {
 console.error('Error closing nav on outside click:', err);
 }
 });

 // Close nav when nav link clicked
 nav.addEventListener('click', (event) => {
 try {
 if (event.target.matches('.nav-link')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 document.body.classList.remove('nav-open');
 }
 } catch (err) {
 console.error('Error closing nav on link click:', err);
 }
 });

 } catch (error) {
 console.error('Failed to initialize mobile navigation:', error);
 }
 };

 // ====== Highlight Active Navigation Link ======
 // Depending on current path, set the .active class and aria-current on nav links
 const setActiveNavLink = () => {
 try {
 const navLinks = qsa('.nav-link');
 if (!navLinks.length) return;

 const currentPath = window.location.pathname.toLowerCase();

 navLinks.forEach(link => {
 // Normalize link href by creating anchor element
 const href = link.getAttribute('href') || '';
 const linkUrl = new URL(href, window.location.origin);
 const linkPath = linkUrl.pathname.toLowerCase();

 // Clear previous active states
 link.classList.remove('active');
 link.removeAttribute('aria-current');

 // Mark active if paths match exactly or if index is handled
 if (linkPath === currentPath || (linkPath.endsWith('index.html') && (currentPath === '/' || currentPath.endsWith('index.html')))) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 }
 });
 } catch (err) {
 console.error('Error setting active nav link:', err);
 }
 };

 // ====== Accessibility: Focus Trap inside Mobile Navigation ======
 const initFocusTrapInNav = () => {
 try {
 const nav = qs('#main-navigation');
 const toggleBtn = qs('#mobile-nav-toggle');
 if (!nav || !toggleBtn) return;

 const focusableSelectors = [
 'a[href]', 'button:not([disabled])', 'input:not([disabled])', 'select:not([disabled])', 'textarea:not([disabled])', '[tabindex]:not([tabindex="-1"])'
 ];

 const getFocusableElements = () => qsa(focusableSelectors.join(','), nav).filter(el => el.offsetParent !== null);

 document.addEventListener('keydown', (event) => {
 if (!nav.classList.contains('nav-open')) return;
 if (event.key !== 'Tab') return;

 const focusableElems = getFocusableElements();
 if (!focusableElems.length) return;

 const firstFocusable = focusableElems[0];
 const lastFocusable = focusableElems[focusableElems.length - 1];

 if (event.shiftKey) {
 if (document.activeElement === firstFocusable) {
 event.preventDefault();
 lastFocusable.focus();
 }
 } else {
 if (document.activeElement === lastFocusable) {
 event.preventDefault();
 firstFocusable.focus();
 }
 }
 });

 } catch (err) {
 console.error('Error initializing focus trap in nav:', err);
 }
 };

 // ====== Handle Start Building Button (index.html) ======
 // Provided for potential enhancements, currently it's a simple link
 const initStartBuildingBtn = () => {
 try {
 const btn = qs('#start-building-btn');
 if (!btn) return;

 btn.addEventListener('click', (event) => {
 // Could add analytics or feedback here
 // Currently no special handling needed
 });
 } catch (err) {
 console.error('Error initializing Start Building button:', err);
 }
 };

 // ====== Responsive Behavior: Close mobile nav on window resize if needed ======
 const initResponsiveResizeHandler = () => {
 window.addEventListener('resize', debounce(() => {
 try {
 const nav = qs('#main-navigation');
 const toggleBtn = qs('#mobile-nav-toggle');
 if (!nav || !toggleBtn) return;

 // Close mobile nav if desktop view (assumed breakpoint > 768px)
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 document.body.classList.remove('nav-open');
 }
 } catch (err) {
 console.error('Error handling responsive resize:', err);
 }
 }, 200));
 };

 // ====== Initialization ======
 document.addEventListener('DOMContentLoaded', () => {
 try {
 initMobileNav();
 setActiveNavLink();
 initFocusTrapInNav();
 initStartBuildingBtn();
 initResponsiveResizeHandler();
 } catch (err) {
 console.error('Error during DOMContentLoaded initialization:', err);
 }
 });

 // No forms found in any HTML pages, so no form validation or submission handling here

 // Global defensive coding and error handling implemented thoroughly
})();

/*

Summary:
- Mobile navigation toggle button is dynamically injected for accessibility and responsive layouts.
- Navigation active link is detected and highlighted based on current URL.
- Focus trapping is implemented inside nav menu when open to improve a11y.
- Responsive design closes mobile nav on wider screens resize.
- Event delegation is used where appropriate.
- Defensive coding and try/catch blocks ensure robust behavior.

*/
