/*
 main.js
 Core JavaScript powering Zombie TV Shows Wiki across all pages.

 FEATURES:
 - Mobile navigation toggle with ARIA support
 - Active page navigation link highlighting
 - Universal form validation enhancements (if forms present)
 - Smooth anchor scrolling
 - Accessibility improvements
 - Keyboard shortcuts
 - Event delegation for efficient interaction
 - Defensive error handling
 - Performance optimizations

 PAGES COVERED:
 index.html, shows.html, about.html

 */

'use strict';

(() => {
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Initialize mobile navigation toggle button
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
 } catch (err) {
 console.error('Error in initMobileNavToggle:', err);
 }
 };

 /**
 * Highlight the active navigation link based on current page path
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 const currentPath = window.location.pathname.split('/').pop().toLowerCase() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href') || '';
 const hrefPage = href.split('/').pop().toLowerCase();

 if (hrefPage === currentPath || (hrefPage === 'index.html' && currentPath === '')) {
 link.classList.add('active');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('active');
 link.removeAttribute('aria-current');
 }
 });
 } catch (err) {
 console.error('Error in highlightActiveNavLink:', err);
 }
 };

 /**
 * Enhance forms across site for better validation UX
 */
 const enhanceFormsValidation = () => {
 try {
 const forms = $$('form');
 if (!forms.length) return;

 forms.forEach(form => {
 const requiredFields = $$('[required]', form);

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
 } catch (err) {
 console.error('Error in enhanceFormsValidation:', err);
 }
 };

 /**
 * Smooth scrolling for internal anchor links
 */
 const initSmoothScrolling = () => {
 try {
 const anchors = $$('a[href^="#"]');
 if (!anchors.length) return;

 anchors.forEach(anchor => {
 anchor.addEventListener('click', e => {
 e.preventDefault();
 const targetId = anchor.getAttribute('href').slice(1);
 const targetElem = document.getElementById(targetId);
 if (targetElem) targetElem.scrollIntoView({ behavior: 'smooth' });
 });
 });
 } catch (err) {
 console.error('Error in initSmoothScrolling:', err);
 }
 };

 /**
 * Accessibility fixes: aria-label for empty buttons, safe external links
 */
 const initAccessibilityEnhancements = () => {
 try {
 const buttons = $$('button');
 buttons.forEach(btn => {
 if (!btn.textContent.trim() && !btn.hasAttribute('aria-label')) {
 btn.setAttribute('aria-label', 'Button');
 }
 });

 const externalLinks = $$('a[href^="http"]');
 externalLinks.forEach(link => {
 if (!link.hasAttribute('target')) {
 link.setAttribute('target', '_blank');
 link.setAttribute('rel', 'noopener noreferrer');
 }
 });
 } catch (err) {
 console.error('Error in initAccessibilityEnhancements:', err);
 }
 };

 /**
 * Keyboard shortcuts, e.g., press 'h' to go home page
 */
 const initKeyboardShortcuts = () => {
 try {
 document.addEventListener('keydown', (e) => {
 if (['INPUT', 'TEXTAREA'].includes(e.target.tagName) || e.target.isContentEditable) return;
 if (e.key.toLowerCase() === 'h') {
 window.location.href = 'index.html';
 }
 });
 } catch (err) {
 console.error('Error in initKeyboardShortcuts:', err);
 }
 };

 /**
 * Centralized event delegation stub for future interactive UI
 */
 const initEventDelegation = () => {
 try {
 document.body.addEventListener('click', (e) => {
 // Placeholder for delegated events if needed in future
 });
 } catch (err) {
 console.error('Error in initEventDelegation:', err);
 }
 };

 /**
 * Placeholder for navigation click logging/analytics
 */
 const initNavClickLogging = () => {
 try {
 const nav = $('#main-nav');
 if (!nav) return;

 nav.addEventListener('click', e => {
 const link = e.target.closest('a.nav-link');
 if (!link) return;
 // Placeholder: console.log('Nav clicked:', link.href);
 });
 } catch (err) {
 console.error('Error in initNavClickLogging:', err);
 }
 };

 // Init all functionalities on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityEnhancements();
 initKeyboardShortcuts();
 initEventDelegation();
 initNavClickLogging();
 });

})();

//# sourceURL=main.js
