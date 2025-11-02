/*
 preview.js
 Core script for Website Builder project managing preview and shared features across all pages.

 RESPONSIBILITIES:
 - Mobile navigation toggle with ARIA support
 - Active navigation link highlighting
 - Form validation enhancements if forms exist
 - Load and display preview content dynamically (simulated here)
 - Interactive UI enhancements
 - Event delegation and performance optimization
 - Accessibility improvements
 - Keyboard shortcuts
 - Smooth scrolling for internal anchor links

 APPLICABLE PAGES:
 - index.html
 - builder.html
 - preview.html
 - about.html

 FILE: js/preview.js
*/

'use strict';

(() => {
 // Utility selector shortcuts
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Mobile navigation toggle button
 */
 const initMobileNavToggle = () => {
 try {
 const header = $('#main-header');
 if (!header) return;
 if ($('#mobile-nav-toggle')) return; // prevent duplicate initialization

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
 * Highlight active page navigation link
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 const currentPath = window.location.pathname.split('/').pop().toLowerCase() || 'index.html';

 navLinks.forEach(link => {
 const href = link.getAttribute('href') || '';
 const page = href.split('/').pop().toLowerCase();

 if (page === currentPath || (page === 'index.html' && currentPath === '')) {
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
 * Enhance forms with improved user experience for validation
 */
 const enhanceFormsValidation = () => {
 try {
 const forms = $$('form.form');
 if (!forms.length) return;

 forms.forEach(form => {
 const requiredFields = $$('input[required],textarea[required],select[required]', form);

 requiredFields.forEach(field => {
 field.addEventListener('input', () => {
 field.setCustomValidity('');
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
 * Smooth scroll for internal anchors
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
 * Accessibility fixes: aria-label on no-text buttons and safe external links
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
 * Keyboard shortcuts (e.g. h for home)
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
 * Load preview content dynamically
 * (In real app, this would fetch or generate the preview of pages, scripts, styles, assets dynamically)
 * For demonstration, this simulates loading preview content
 */
 const loadPreviewContent = () => {
 try {
 const previewArea = $('#preview-area');
 if (!previewArea) return;

 // Show loading indicator
 previewArea.innerHTML = '<p>Loading preview content...</p>';

 // Simulate async loading
 setTimeout(() => {
 // Simulated dummy preview content
 previewArea.innerHTML = '';

 const previewFrame = document.createElement('iframe');
 previewFrame.width = '100%';
 previewFrame.height = '600px';
 previewFrame.title = 'Website Preview Frame';
 previewFrame.style.border = '1px solid #ccc';

 // For demo, create a basic html content in the iframe
 const previewDocument = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Preview Site</title>
<style>
body{ font-family: Arial, sans-serif; padding: 1em; background:#f9f9f9; }
h1 { color: #333; }
p { font-size: 1rem; color:#555; }
</style>
</head>
<body>
<h1>Website Preview</h1>
<p>This is a live preview of your website based on your builder settings.</p>
</body>
</html>`;

 previewFrame.srcdoc = previewDocument;

 previewArea.appendChild(previewFrame);
 }, 800);
 } catch (error) {
 console.error('loadPreviewContent error:', error);
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
 // Placeholder for analytics event
 // console.log('Navigation clicked:', link.href);
 });
 } catch (error) {
 console.error('initNavClickLogging error:', error);
 }
 };

 // Initialize events on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityFixes();
 initKeyboardShortcuts();
 initNavClickLogging();

 // Load preview if on preview page
 if (window.location.pathname.toLowerCase().includes('preview.html')) {
 loadPreviewContent();
 }
 });

})();

//# sourceURL=preview.js
