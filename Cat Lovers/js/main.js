/*
 main.js
 Core global JavaScript for Cat Lovers website.

 FEATURES:
 - Mobile navigation toggle with ARIA support
 - Active navigation link highlighting
 - Form validation enhancements with focus management
 - Smooth scrolling for internal anchor links
 - Accessibility improvements for buttons, links, and keyboard
 - Keyboard shortcuts for quick navigation
 - Responsive window resize handling
 - Event delegation for performance and maintainability
 - Defensive error handling
 - Modern ES6+ production-ready code

 COVERAGE:
 Applicability across all pages: index.html, about.html, gallery.html, contact.html

 */
'use strict';

(() => {
 // DOM utility shortcuts
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Initialize mobile navigation toggle
 * Adds hamburger toggle button and manages nav visibility
 */
 const initMobileNavToggle = () => {
 try {
 const header = $('#main-header');
 if (!header) return;
 if ($('#mobile-nav-toggle')) return; // Prevent duplicates

 const nav = $('#main-nav', header);
 if (!nav) return;

 const toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.type = 'button';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '&#9776;'; // hamburger icon

 header.insertBefore(toggleBtn, nav);

 toggleBtn.addEventListener('click', () => {
 const expanded = toggleBtn.getAttribute('aria-expanded') === 'true';
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 toggleBtn.classList.toggle('active');
 nav.classList.toggle('active');
 });

 nav.addEventListener('focusout', () => {
 setTimeout(() => {
 if (!nav.contains(document.activeElement)) {
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.classList.remove('active');
 nav.classList.remove('active');
 }
 }, 100);
 });
 } catch (error) {
 console.error('initMobileNavToggle error:', error);
 }
 };

 /**
 * Highlight active navigation link on page load
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 const path = window.location.pathname;
 const currentPage = path.substring(path.lastIndexOf('/') + 1).toLowerCase() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href') || '';
 const linkPage = href.substring(href.lastIndexOf('/') + 1).toLowerCase();

 if (linkPage === currentPage || (linkPage === 'index.html' && currentPage === '')) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('active');
 link.removeAttribute('aria-current');
 }
 });
 } catch (error) {
 console.error('highlightActiveNavLink error:', error);
 }
 };

 /**
 * Enhance form validation UX
 * Focus the first invalid input on submit and clear custom validity on input
 */
 const enhanceFormsValidation = () => {
 try {
 const forms = $$('form.form');
 if (!forms.length) return;

 forms.forEach(form => {
 const requiredInputs = $$('input[required],textarea[required],select[required]', form);

 requiredInputs.forEach(input => {
 input.addEventListener('input', () => {
 input.setCustomValidity('');
 });
 });

 form.addEventListener('submit', e => {
 if (!form.checkValidity()) {
 e.preventDefault();
 const firstInvalid = form.querySelector(':invalid');
 if (firstInvalid) firstInvalid.focus();
 }
 });
 });
 } catch (error) {
 console.error('enhanceFormsValidation error:', error);
 }
 };

 /**
 * Smooth scroll for anchor links starting with '#'
 */
 const initSmoothScrolling = () => {
 try {
 const anchors = $$('a[href^="#"]');
 if (!anchors.length) return;

 anchors.forEach(anchor => {
 anchor.addEventListener('click', e => {
 e.preventDefault();
 const targetId = anchor.getAttribute('href').substring(1);
 const target = document.getElementById(targetId);
 if (target) {
 target.scrollIntoView({ behavior: 'smooth' });
 }
 });
 });
 } catch (error) {
 console.error('initSmoothScrolling error:', error);
 }
 };

 /**
 * Accessibility enhancements
 * - Aria-label on empty buttons
 * - External links open in new tab safely
 */
 const initAccessibilityFixes = () => {
 try {
 const buttons = $$('button');
 buttons.forEach(button => {
 if (!button.textContent.trim() && !button.hasAttribute('aria-label')) {
 button.setAttribute('aria-label', 'Button');
 }
 });

 const externalLinks = $$('a[href^="http"]');
 externalLinks.forEach(link => {
 if (!link.hasAttribute('target')) {
 link.setAttribute('target', '_blank');
 link.setAttribute('rel', 'noopener noreferrer');
 }
 });
 } catch (error) {
 console.error('initAccessibilityFixes error:', error);
 }
 };

 /**
 * Keyboard shortcuts
 * "h" to navigate home
 */
 const initKeyboardShortcuts = () => {
 try {
 document.addEventListener('keydown', e => {
 if (['INPUT', 'TEXTAREA'].includes(e.target.tagName) || e.target.isContentEditable) return;
 if (e.key.toLowerCase() === 'h') {
 window.location.href = 'index.html';
 }
 });
 } catch (error) {
 console.error('initKeyboardShortcuts error:', error);
 }
 };

 /**
 * Responsive handler to close mobile nav if resizing beyond mobile breakpoint
 */
 const initResponsiveResizeHandler = () => {
 try {
 const nav = $('#main-nav');
 const toggleBtn = $('#mobile-nav-toggle');
 if (!nav || !toggleBtn) return;

 let resizeTimeout = null;
 window.addEventListener('resize', () => {
 clearTimeout(resizeTimeout);
 resizeTimeout = setTimeout(() => {
 if (window.innerWidth > 768 && nav.classList.contains('active')) {
 nav.classList.remove('active');
 toggleBtn.classList.remove('active');
 toggleBtn.setAttribute('aria-expanded', 'false');
 }
 }, 200);
 });
 } catch (error) {
 console.error('initResponsiveResizeHandler error:', error);
 }
 };

 /**
 * Navigation click logging placeholder for analytics
 */
 const initNavClickLogging = () => {
 try {
 const nav = $('#main-nav');
 if (!nav) return;

 nav.addEventListener('click', e => {
 const link = e.target.closest('a.nav-link');
 if (!link) return;
 // Placeholder: Analytics could use this
 // console.log('Navigation click:', link.href);
 });
 } catch (error) {
 console.error('initNavClickLogging error:', error);
 }
 };

 // Initialize all on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityFixes();
 initKeyboardShortcuts();
 initResponsiveResizeHandler();
 initNavClickLogging();
 });

})();

//# sourceURL=main.js
