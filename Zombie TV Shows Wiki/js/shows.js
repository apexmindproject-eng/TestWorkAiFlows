/*
 shows.js
 JavaScript powering interactive features related to zombie shows in the Zombie TV Shows Wiki.

 FEATURES:
 - Mobile navigation toggle
 - Active nav link highlighting
 - Form validation enhancements
 - Interactive UI components for show cards and lists
 - Show info expand/collapse for better UX
 - Event delegation for efficiency
 - Smooth scrolling anchor support
 - Accessibility enhancements
 - Keyboard shortcuts
 - Error handling and performance considerations

 APPLICABLE PAGES:
 - index.html
 - shows.html
 - about.html

*/

'use strict';

(() => {
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Mobile navigation toggle button with ARIA
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
 } catch (e) {
 console.error('initMobileNavToggle error:', e);
 }
 };

 /**
 * Highlights the active navigation link based on location
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 const currentPage = window.location.pathname.split('/').pop().toLowerCase() || 'index.html';

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
 } catch (e) {
 console.error('highlightActiveNavLink error:', e);
 }
 };

 /**
 * Enhance form validation UX
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
 } catch (e) {
 console.error('enhanceFormsValidation error:', e);
 }
 };

 /**
 * Initiate expand/collapse toggle for show descriptions on shows.html
 * Allows users to click show title or thumbnail to toggle description visibility
 */
 const initShowExpandCollapse = () => {
 try {
 // Only relevant on shows.html
 if (!document.body.id.includes('shows-page')) return;

 const showList = $('.show-list');
 if (!showList) return;

 // Use event delegation for performance
 showList.addEventListener('click', e => {
 const showItem = e.target.closest('.show-item');
 if (!showItem) return;

 // Toggle a class to show/hide description
 const desc = showItem.querySelector('.show-description');
 if (!desc) return;

 e.preventDefault();

 desc.classList.toggle('expanded');

 // Update aria-expanded on container or heading for accessibility
 const heading = showItem.querySelector('.show-title') || showItem.querySelector('h2, h3');
 if (heading) {
 const expanded = desc.classList.contains('expanded');
 heading.setAttribute('aria-expanded', expanded ? 'true' : 'false');
 }
 });
 } catch (e) {
 console.error('initShowExpandCollapse error:', e);
 }
 };

 /**
 * Smooth scrolling for anchors
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
 } catch (e) {
 console.error('initSmoothScrolling error:', e);
 }
 };

 /**
 * Accessibility improvements
 * - aria-label for empty buttons
 * - safe target='_blank' and rel for external links
 */
 const initAccessibilityFixes = () => {
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
 } catch (e) {
 console.error('initAccessibilityFixes error:', e);
 }
 };

 /**
 * Keyboard shortcuts e.g., press 'h' to go home page
 */
 const initKeyboardShortcuts = () => {
 try {
 document.addEventListener('keydown', e => {
 if (['INPUT','TEXTAREA'].includes(e.target.tagName) || e.target.isContentEditable) return;
 if (e.key.toLowerCase() === 'h') {
 window.location.href = 'index.html';
 }
 });
 } catch (e) {
 console.error('initKeyboardShortcuts error:', e);
 }
 };

 /**
 * Navigation click logger placeholder
 */
 const initNavClickLogging = () => {
 try {
 const nav = $('#main-nav');
 if (!nav) return;

 nav.addEventListener('click', e => {
 const link = e.target.closest('a.nav-link');
 if (!link) return;
 // Analytics or tracking could happen here
 // console.log('Nav clicked:', link.href);
 });
 } catch (e) {
 console.error('initNavClickLogging error:', e);
 }
 };

 // Initialize all
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initShowExpandCollapse();
 initSmoothScrolling();
 initAccessibilityFixes();
 initKeyboardShortcuts();
 initNavClickLogging();
 });
})();
//# sourceURL=shows.js
