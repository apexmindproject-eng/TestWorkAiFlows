/*
 * main.js
 * Core JavaScript for Kittens Delight website
 * Supports navigation toggling, active link highlighting,
 * accessibility improvements, and global UI behaviors.
 *
 * Designed to function consistently across all 4 pages: index, gallery, care, about.
 *
 * Author: Automated Production Ready Script
 * Date: 2024
 */

(() => {
 'use strict';

 // Utility selectors
 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce helper to optimize event handlers
 const debounce = (func, wait = 100) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func(...args), wait);
 };
 };

 /**
 * Highlight the active nav link based on current URL
 * Ensures only one nav link is active
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = qsa('.nav-link');
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 navLinks.forEach(link => {
 const href = link.getAttribute('href')?.split(/[?#]/)[0];
 if (!href) return;
 if (href === currentPath) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 console.error('Error in highlightActiveNavLink:', error);
 }
 };

 /**
 * Setup mobile navigation toggle button
 * Dynamically creates toggle button if it doesn't exist
 * Manages aria-expanded attribute and toggles nav visibility
 */
 const setupMobileNavToggle = () => {
 try {
 const header = qs('.site-header');
 if (!header) return;

 let toggleBtn = qs('#mobile-nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '&#9776;'; // hamburger icon
 header.insertBefore(toggleBtn, qs('nav'));
 }

 const nav = qs('nav');
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

 toggleBtn.onclick = toggleMenu;

 // Close nav if clicking outside or clicking a link
 document.body.addEventListener('click', e => {
 if (!nav.contains(e.target) && !toggleBtn.contains(e.target) && nav.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.classList.remove('nav-open');
 }
 if (nav.contains(e.target) && e.target.classList.contains('nav-link') && nav.classList.contains('nav-open')) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.classList.remove('nav-open');
 }
 });

 // Close nav menu on window resize if width exceeds mobile breakpoint
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

 /**
 * Smooth scrolling for internal anchor link navigation
 * Handles keyboard accessibility by focusing targeted element
 */
 const setupSmoothScrolling = () => {
 try {
 document.body.addEventListener('click', e => {
 const anchor = e.target.closest('a[href^="#"]');
 if (!anchor) return;

 const href = anchor.getAttribute('href');
 if (!href || href === '#' || href === '#0') return;

 const targetId = href.substring(1);
 const target = qs(`#${targetId}`);
 if (!target) return;

 e.preventDefault();
 target.scrollIntoView({ behavior: 'smooth', block: 'start' });
 target.setAttribute('tabindex', '-1');
 target.focus({ preventScroll: true });
 });
 } catch (error) {
 console.error('Error in setupSmoothScrolling:', error);
 }
 };

 /**
 * Accessibility: manage focus outline visibility based on input modality (keyboard vs mouse)
 */
 const setupFocusVisibility = () => {
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
 console.error('Error in setupFocusVisibility:', error);
 }
 };

 /**
 * Initialization on DOMContentLoaded
 */
 document.addEventListener('DOMContentLoaded', () => {
 highlightActiveNavLink();
 setupMobileNavToggle();
 setupSmoothScrolling();
 setupFocusVisibility();
 });

})();

/*
 NOTES:
 - This script handles core navigation and accessibility features.
 - No forms present on provided pages; form validation should be handled in separate scripts if needed.
 - Modular and defensive event handling ensures consistency across pages.
 - Mobile nav toggle is dynamically created for easy integration.
 - Smooth scrolling and focus management improves user experience.
 - Well-commented and structured for maintainability.
*/