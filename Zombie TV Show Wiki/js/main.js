/*
 * main.js
 * Core JavaScript for Zombie TV Show Wiki
 * Handles navigation, mobile menu toggle, active link highlighting,
 * contact form validation and submission, accessibility enhancements,
 * and consistent global UI behavior across all pages.
 *
 * Supports pages: index.html, about.html, shows.html, contact.html
 *
 * Author: Automated Production Script
 * Date: 2024
 */

(() => {
 'use strict';

 // Utility selectors
 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Debounce utility for event optimization
 const debounce = (callback, delay = 150) => {
 let timerId;
 return (...args) => {
 clearTimeout(timerId);
 timerId = setTimeout(() => callback(...args), delay);
 };
 };

 /////////////////////////
 // Highlight active navigation link based on current URL
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
 console.error('Error in highlightActiveNavLink:', e);
 }
 };

 /////////////////////////
 // Mobile Navigation Toggle Setup
 const setupMobileNavToggle = () => {
 try {
 // Different header IDs on pages
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
 toggleBtn.innerHTML = '&#9776;'; // Hamburger icon

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

 // Close mobile nav if clicking outside menu or on link
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

 // Close nav on window resize if viewport wide
 window.addEventListener('resize', debounce(() => {
 if (window.innerWidth > 768 && nav.classList.contains('nav-open')) {
 nav.classList.remove('nav-open');
 toggleBtn.setAttribute('aria-expanded', 'false');
 nav.removeAttribute('tabindex');
 }
 }, 200));

 } catch (e) {
 console.error('Error setting up mobile nav toggle:', e);
 }
 };

 /////////////////////////
 // Smooth scroll for internal anchor links
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

 // Accessibility: focus target after scrolling
 target.setAttribute('tabindex', '-1');
 target.focus({preventScroll: true});
 });
 } catch (e) {
 console.error('Error setting up smooth scroll:', e);
 }
 };

 /////////////////////////
 // Manage Focus outlines only for keyboard users
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
 } catch (e) {
 console.error('Error setting up focus outlines:', e);
 }
 };

 /////////////////////////
 // Contact Form Validation & Submission
 const setupContactForm = () => {
 try {
 const form = qs('#contact-form');
 if (!form) return;

 const validateForm = () => {
 const name = qs('#name', form)?.value.trim();
 const email = qs('#email', form)?.value.trim();
 const message = qs('#message', form)?.value.trim();

 const errors = [];

 if (!name) errors.push('Name is required.');

 if (!email) {
 errors.push('Email is required.');
 } else if (!/^\S+@\S+\.\S+$/.test(email)) {
 errors.push('Please enter a valid email address.');
 }

 if (!message) errors.push('Message is required.');

 return errors;
 };

 form.addEventListener('submit', e => {
 e.preventDefault();
 const errors = validateForm();
 if (errors.length > 0) {
 alert(errors.join('\n'));
 return;
 }

 // Disable submit button to prevent duplicate submission
 const submitBtn = qs('#submit-contact', form);
 if (submitBtn) submitBtn.disabled = true;

 // Fake submission - replace with actual AJAX as needed
 setTimeout(() => {
 alert('Thank you for contacting us! We will get back to you shortly.');
 form.reset();
 if (submitBtn) submitBtn.disabled = false;
 }, 1000);
 });
 } catch (e) {
 console.error('Error setting up contact form:', e);
 }
 };

 /////////////////////////
 // Initialization
 document.addEventListener('DOMContentLoaded', () => {
 highlightActiveNavLink();
 setupMobileNavToggle();
 setupSmoothScroll();
 setupFocusOutlineManagement();
 setupContactForm();
 });

})();

/*
 * NOTES:
 * - Mobile navigation toggle with ARIA and accessibility
 * - Smooth scrolling with focus management
 * - Contact form validation with user feedback and disable on submission
 * - Keyboard focus outlines only on keyboard navigation
 * - Robust error handling for resilience
 * - Modular, maintainable, and performant
 */