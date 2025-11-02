/*
 utils.js
 Utility and shared interaction script for Website Builder project.

 RESPONSIBILITIES:
 - Mobile navigation toggle with ARIA for all pages
 - Active page navigation highlighting
 - Universal form validation improvement
 - Smooth scrolling on anchor links
 - Accessibility helpers
 - Keyboard shortcuts
 - Centralized event delegation for generic UI
 - Defensive error handling

 APPLICABLE TO ALL PAGES:
 index.html, builder.html, preview.html, about.html

 FILE: js/utils.js
*/

'use strict';

(() => {
 // Simple DOM selectors
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Initialize mobile navigation toggle with ARIA attributes
 */
 const initMobileNavToggle = () => {
 try {
 const header = $('#main-header');
 if (!header) return;
 if ($('#mobile-nav-toggle')) return;

 const nav = $('#main-nav', header);
 if (!nav) return;

 const toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.type = 'button';
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '&#9776;';

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
 * Set active link based on current page URL
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 let currentPage = window.location.pathname.split('/').pop().toLowerCase();
 if (!currentPage) currentPage = 'index.html';

 navLinks.forEach(link => {
 const hrefPage = (link.getAttribute('href') || '').split('/').pop().toLowerCase();
 if (hrefPage === currentPage || (hrefPage === 'index.html' && currentPage === '')) {
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
 * Universal enhancement for all form validations
 */
 const enhanceFormsValidation = () => {
 try {
 const forms = $$('form.form');
 if (!forms.length) return;

 forms.forEach(form => {
 const requiredFields = $$('input[required],textarea[required],select[required]', form);

 requiredFields.forEach(field => {
 field.addEventListener('input', () => field.setCustomValidity(''));
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
 * Initialize smooth scrolling for internal anchors
 */
 const initSmoothScrolling = () => {
 try {
 const anchors = $$('a[href^="#"]');
 if (!anchors.length) return;

 anchors.forEach(anchor => {
 anchor.addEventListener('click', e => {
 e.preventDefault();
 const targetId = anchor.getAttribute('href').slice(1);
 const target = document.getElementById(targetId);
 if (target) target.scrollIntoView({ behavior: 'smooth' });
 });
 });
 } catch (error) {
 console.error('initSmoothScrolling error:', error);
 }
 };

 /**
 * Accessibility fixes: provide aria-label for blank buttons and ensure external links open safely
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
 * Global keyboard shortcuts, e.g. 'h' to go home
 */
 const initKeyboardShortcuts = () => {
 try {
 document.addEventListener('keydown', e => {
 if (['INPUT','TEXTAREA'].includes(e.target.tagName) || e.target.isContentEditable) return;
 if (e.key.toLowerCase() === 'h') {
 window.location.href = 'index.html';
 }
 });
 } catch (error) {
 console.error('initKeyboardShortcuts error:', error);
 }
 };

 /**
 * Central event delegation for common UI interactions, placeholders for future
 */
 const initGlobalEventDelegation = () => {
 try {
 document.body.addEventListener('click', e => {
 // Placeholder: for additional delegated events
 });
 } catch (error) {
 console.error('initGlobalEventDelegation error:', error);
 }
 };

 /**
 * Navigation click logging placeholder
 */
 const initNavClickLogging = () => {
 try {
 const nav = $('#main-nav');
 if (!nav) return;
 nav.addEventListener('click', e => {
 const link = e.target.closest('a.nav-link');
 if (!link) return;
 // Placeholder for analytics logging
 // console.log('Nav click:', link.href);
 });
 } catch (error) {
 console.error('initNavClickLogging error:', error);
 }
 };

 // Initialize all on DOM ready
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityFixes();
 initKeyboardShortcuts();
 initGlobalEventDelegation();
 initNavClickLogging();
 });

})();

//# sourceURL=utils.js
