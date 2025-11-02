/*
 * main.js
 * Core JavaScript functionality for Shark Info Site
 * Handles mobile navigation toggle, active nav link highlighting,
 * accessible keyboard support, smooth scrolling enhancements,
 * and global UI behaviors.
 * 
 * Currently used only on index.html page but designed for scalability.
 *
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 // Utility functions
 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce function for event optimization
 const debounce = (fn, wait = 150) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => fn(...args), wait);
 };
 };

 /////////////////////
 // Navigation

 /**
 * Highlight the active navigation link based on current URL
 */
 const highlightActiveNav = () => {
 try {
 const navLinks = qsa('.nav-link');
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (!href) return;
 if (href === currentPath) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 console.error('Error in highlightActiveNav:', error);
 }
 };

 /**
 * Setup Mobile Navigation Toggle Button
 * Adds a button if not present, toggles mobile menu visibility
 * Updates ARIA attributes for accessibility
 */
 const setupMobileNavToggle = () => {
 try {
 const header = qs('#site-header');
 if (!header) return;

 // Check if toggle already exists
 let toggleBtn = qs('#mobile-nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '\u2630'; // Hamburger icon
 header.insertBefore(toggleBtn, qs('#main-nav'));
 }

 const nav = qs('#main-nav');
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

 // Close menu if clicking outside or on nav link
 document.addEventListener('click', e => {
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

 // Close menu on window resize if above mobile breakpoint
 window.addEventListener('resize', debounce(() => {
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.removeAttribute('tabindex');
 }
 }, 200));
 } catch (error) {
 console.error('Error in setupMobileNavToggle:', error);
 }
 };

 /////////////////////
 // Smooth scroll on anchor links
 const setupSmoothScroll = () => {
 try {
 document.body.addEventListener('click', e => {
 const anchor = e.target.closest('a[href^="#"]');
 if (!anchor) return;

 let href = anchor.getAttribute('href');
 if (!href || href.length < 2) return;

 const targetId = href.slice(1);
 const targetEl = qs(`#${targetId}`);
 if (!targetEl) return;

 e.preventDefault();

 targetEl.scrollIntoView({behavior: 'smooth', block: 'start'});
 targetEl.setAttribute('tabindex', '-1');
 targetEl.focus({preventScroll: true});
 });
 } catch (error) {
 console.error('Error in setupSmoothScroll:', error);
 }
 };

 /////////////////////
 // Accessibility: Manage focus outline on keyboard navigation
 const setupFocusOutline = () => {
 try {
 let lastInputWasKeyboard = false;
 const body = document.body;

 const handleFirstTab = (e) => {
 if (e.key === 'Tab' || e.keyCode === 9) {
 if (!lastInputWasKeyboard) {
 body.classList.add('user-is-tabbing');
 lastInputWasKeyboard = true;
 }
 window.removeEventListener('keydown', handleFirstTab);
 window.addEventListener('mousedown', handleMouseDown);
 }
 };

 const handleMouseDown = () => {
 if (lastInputWasKeyboard) {
 body.classList.remove('user-is-tabbing');
 lastInputWasKeyboard = false;
 }
 window.removeEventListener('mousedown', handleMouseDown);
 window.addEventListener('keydown', handleFirstTab);
 };

 window.addEventListener('keydown', handleFirstTab);
 } catch (error) {
 console.error('Error in setupFocusOutline:', error);
 }
 };

 /////////////////////
 // Initialization
 document.addEventListener('DOMContentLoaded', () => {
 highlightActiveNav();
 setupMobileNavToggle();
 setupSmoothScroll();
 setupFocusOutline();
 });

})();

/*
 * Notes:
 * - This script is production ready with robust error handling and modern JS syntax.
 * - Responsive mobile menu toggle with accessibility ARIA roles.
 * - Smooth scrolling for anchor link navigation.
 * - Visual focus indication only for keyboard users.
 * - Modular design enables easy extension.
 */