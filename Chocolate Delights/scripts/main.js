// main.js - Core functionality for Chocolate Delights website
// Handles navigation, global UI features, and general interactive elements

// Use Immediately Invoked Function Expression (IIFE) to avoid polluting global scope
(() => {
 'use strict';

 // Utility functions
 const select = (selector, all = false) => {
 try {
 if (all) return document.querySelectorAll(selector);
 return document.querySelector(selector);
 } catch (e) {
 console.error(`Invalid selector: ${selector}`, e);
 return null;
 }
 };

 const on = (element, event, handler, options = false) => {
 if (!element) return;
 element.addEventListener(event, handler, options);
 };

 const onDelegate = (parent, eventType, selector, handler) => {
 if (!parent) return;
 parent.addEventListener(eventType, event => {
 const targetElement = event.target.closest(selector);
 if (targetElement && parent.contains(targetElement)) {
 handler(event, targetElement);
 }
 });
 };

 // Detect active nav link and set aria-current and active class
 const activateCurrentNavLink = () => {
 try {
 const navLinks = select('#main-nav .nav-link', true);
 if (!navLinks) return;

 const currentPath = window.location.pathname;
 navLinks.forEach(link => {
 // Normalize paths for comparison
 const linkPath = new URL(link.href).pathname;
 if (linkPath === currentPath) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('active');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('Error activating current nav link:', error);
 }
 };

 // Mobile navigation toggle functionality
 const initMobileNavToggle = () => {
 // Check if nav exists
 const nav = select('#main-nav');
 if (!nav) return;

 // Create toggle button dynamically if not present
 let toggleBtn = select('#nav-toggle-btn');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'nav-toggle-btn';
 toggleBtn.className = 'nav-toggle-btn';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '<span class="bar"></span><span class="bar"></span><span class="bar"></span>';
 nav.parentNode.insertBefore(toggleBtn, nav);
 }

 // Toggle nav visibility
 on(toggleBtn, 'click', () => {
 try {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 nav.classList.toggle('nav-open', !expanded);

 // Lock scroll when nav is open (optional)
 if (!expanded) {
 document.body.style.overflow = 'hidden';
 } else {
 document.body.style.overflow = '';
 }
 } catch (e) {
 console.error('Error toggling mobile nav:', e);
 }
 });

 // Close nav when clicking outside
 on(document, 'click', event => {
 if (!nav.contains(event.target) && !toggleBtn.contains(event.target) && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 document.body.style.overflow = '';
 }
 });

 // Close nav on page navigation (any click on nav links)
 onDelegate(nav, 'click', '.nav-link', () => {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 document.body.style.overflow = '';
 });
 };

 // Keyboard navigation enhancements for accessibility
 const keyboardNavEnhancements = () => {
 // Allow closing mobile nav with Escape key
 on(document, 'keydown', e => {
 const nav = select('#main-nav');
 const toggleBtn = select('#nav-toggle-btn');
 if (e.key === 'Escape' && nav && nav.classList.contains('nav-open')) {
 e.preventDefault();
 nav.classList.remove('nav-open');
 if (toggleBtn) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.focus();
 }
 document.body.style.overflow = '';
 }
 });
 };

 // Smooth scroll for anchor links within the site
 const smoothScrollInit = () => {
 try {
 onDelegate(document.body, 'click', 'a[href^="#"]', (event, link) => {
 const href = link.getAttribute('href');
 if (href.length > 1) { // Not just #
 const target = select(href);
 if (target) {
 event.preventDefault();
 target.scrollIntoView({ behavior: 'smooth' });
 // Optionally update hash without jumping
 history.pushState(null, '', href);
 }
 }
 });
 } catch (error) {
 console.error('Error initializing smooth scroll:', error);
 }
 };

 // Highlight chocolate items on index page on hover and keyboard focus
 const enhanceChocolateItems = () => {
 const gallery = select('.featured-gallery');
 if (!gallery) return;

 onDelegate(gallery, 'mouseover', '.chocolate-item', (e, item) => {
 try {
 item.classList.add('highlight');
 } catch(e) {
 console.error('Error highlighting chocolate item on hover:', e);
 }
 });

 onDelegate(gallery, 'mouseout', '.chocolate-item', (e, item) => {
 try {
 item.classList.remove('highlight');
 } catch(e) {
 console.error('Error removing highlight from chocolate item:', e);
 }
 });

 // Keyboard accessibility: focus and blur
 onDelegate(gallery, 'focusin', '.chocolate-item', (e, item) => {
 try {
 item.classList.add('highlight');
 } catch(e) {
 console.error('Error highlighting chocolate item on focus:', e);
 }
 });

 onDelegate(gallery, 'focusout', '.chocolate-item', (e, item) => {
 try {
 item.classList.remove('highlight');
 } catch(e) {
 console.error('Error removing highlight from chocolate item on blur:', e);
 }
 });
 };

 // Footer year update (dynamic current year)
 const updateFooterYear = () => {
 try {
 const footer = select('#main-footer');
 if (!footer) return;
 const yearMatch = footer.textContent.match(/\d{4}/);
 const currentYear = new Date().getFullYear();
 if (!yearMatch || +yearMatch[0] !== currentYear) {
 footer.innerHTML = footer.innerHTML.replace(/\d{4}/, currentYear);
 }
 } catch (e) {
 console.error('Error updating footer year:', e);
 }
 };

 // Initialization
 const init = () => {
 try {
 activateCurrentNavLink();
 initMobileNavToggle();
 keyboardNavEnhancements();
 smoothScrollInit();
 enhanceChocolateItems();
 updateFooterYear();
 } catch (error) {
 console.error('Error during main.js initialization:', error);
 }
 };

 // Run initialization on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', init);
 
})();

// End of main.js
