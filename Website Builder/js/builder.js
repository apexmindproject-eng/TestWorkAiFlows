/*
 builder.js
 Core JS powering the Website Builder project across all pages.

 RESPONSIBILITIES:
 - Mobile navigation toggle with ARIA support
 - Active navigation link highlighting
 - Form validation enhancements when forms are present
 - Interactive UI components specific to builder tools (create page, edit styles, manage assets, preview)
 - Event delegation and centralized event handling
 - Error handling and performance optimizations
 - Smooth scrolling for anchor links
 - Accessibility improvements
 - Keyboard shortcuts

 APPLICABLE PAGES:
 - index.html
 - builder.html
 - preview.html
 - about.html

 FILE: js/builder.js
*/

'use strict';

(() => {
 // DOM shortcuts
 const $ = (selector, scope = document) => scope.querySelector(selector);
 const $$ = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 /**
 * Mobile navigation toggle for all pages
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
 * Highlight active nav link
 */
 const highlightActiveNavLink = () => {
 try {
 const navLinks = $$('.nav-link');
 if (!navLinks.length) return;

 let currentPath = window.location.pathname.split('/').pop().toLowerCase();
 if (!currentPath) currentPath = 'index.html';

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
 } catch (error) {
 console.error('highlightActiveNavLink error:', error);
 }
 };

 /**
 * Enhance forms with better validation UX
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
 * Smooth scroll anchors
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
 * Accessibility fixes for buttons and external links
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
 * Keyboard shortcuts (e.g. h to home)
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
 * Builder page: Open modal with title and content
 * @param {string} title
 * @param {HTMLElement} content
 */
 const openModal = (title, content) => {
 try {
 // Create modal overlay
 let modalOverlay = $('#builder-modal-overlay');
 if (!modalOverlay) {
 modalOverlay = document.createElement('div');
 modalOverlay.id = 'builder-modal-overlay';
 modalOverlay.className = 'modal-overlay';
 document.body.appendChild(modalOverlay);
 }
 modalOverlay.innerHTML = '';

 // Modal dialog container
 const modal = document.createElement('div');
 modal.className = 'modal-dialog';
 modal.setAttribute('role', 'dialog');
 modal.setAttribute('aria-modal', 'true');
 modal.setAttribute('aria-labelledby', 'modal-title');
 modal.tabIndex = -1;

 // Modal header
 const headerElem = document.createElement('header');
 headerElem.className = 'modal-header';
 const heading = document.createElement('h2');
 heading.id = 'modal-title';
 heading.textContent = title;
 headerElem.appendChild(heading);

 // Modal close button
 const closeBtn = document.createElement('button');
 closeBtn.type = 'button';
 closeBtn.className = 'modal-close-btn';
 closeBtn.setAttribute('aria-label', 'Close modal');
 closeBtn.innerHTML = '&times;';
 headerElem.appendChild(closeBtn);

 // Modal content
 const contentElem = document.createElement('div');
 contentElem.className = 'modal-content';
 contentElem.appendChild(content);

 modal.appendChild(headerElem);
 modal.appendChild(contentElem);
 modalOverlay.appendChild(modal);

 // Close modal
 const closeModal = () => {
 modalOverlay.style.display = 'none';
 document.body.style.overflow = '';
 document.removeEventListener('keydown', keyListener);
 closeBtn.removeEventListener('click', closeModal);
 modalOverlay.removeEventListener('click', overlayClick);
 };

 // Accessibility: trap tab inside modal
 const focusableSelectors = 'a[href],area[href],input:not([disabled]),select:not([disabled]),textarea:not([disabled]),button:not([disabled]),iframe,object,embed,[tabindex], [contenteditable]';
 let focusableElements = [];

 const trapFocus = (e) => {
 const isTabPressed = (e.key === 'Tab' || e.keyCode === 9);
 if (!isTabPressed) return;

 if (focusableElements.length === 0) return;

 const firstEl = focusableElements[0];
 const lastEl = focusableElements[focusableElements.length - 1];

 if (e.shiftKey) {
 if (document.activeElement === firstEl) {
 lastEl.focus();
 e.preventDefault();
 }
 } else {
 if (document.activeElement === lastEl) {
 firstEl.focus();
 e.preventDefault();
 }
 }
 };

 // Key listener for Escape and tab trap
 const keyListener = (e) => {
 if (e.key === 'Escape' || e.key === 'Esc') {
 e.preventDefault();
 closeModal();
 }
 trapFocus(e);
 };

 // Close modal on overlay click
 const overlayClick = (e) => {
 if (e.target === modalOverlay) closeModal();
 };

 // Setup
 modalOverlay.style.display = 'flex';
 document.body.style.overflow = 'hidden';
 closeBtn.addEventListener('click', closeModal);
 modalOverlay.addEventListener('click', overlayClick);
 document.addEventListener('keydown', keyListener);

 focusableElements = Array.from(modal.querySelectorAll(focusableSelectors));
 if (focusableElements.length) focusableElements[0].focus();
 } catch (error) {
 console.error('openModal error:', error);
 }
 };

 /**
 * Handler for 'Create New Page' button
 */
 const onCreateNewPageClick = () => {
 try {
 const form = document.createElement('form');
 form.className = 'modal-form';

 const label = document.createElement('label');
 label.setAttribute('for', 'page-name-input');
 label.textContent = 'Page Name:';

 const input = document.createElement('input');
 input.id = 'page-name-input';
 input.name = 'pageName';
 input.type = 'text';
 input.placeholder = 'Enter page name (e.g. about.html)';
 input.required = true;
 input.autocomplete = 'off';
 input.className = 'form-input';

 const submitBtn = document.createElement('button');
 submitBtn.type = 'submit';
 submitBtn.className = 'btn btn-primary';
 submitBtn.textContent = 'Create Page';

 form.appendChild(label);
 form.appendChild(input);
 form.appendChild(submitBtn);

 form.addEventListener('submit', e => {
 e.preventDefault();
 const pageName = input.value.trim();
 if (!pageName) {
 input.setCustomValidity('Page name is required');
 input.reportValidity();
 return;
 }
 if (!/^\w+[\w-]*\.html$/.test(pageName)) {
 input.setCustomValidity('Page name must be alphanumeric with optional dashes and end with .html');
 input.reportValidity();
 return;
 }

 // Fire a custom event or do something to create the page
 // For this demo, just close modal and log
 openModal('Success', document.createTextNode(`Page "${pageName}" created successfully!`));
 form.reset();
 });

 openModal('Create New Page', form);
 } catch (error) {
 console.error('onCreateNewPageClick error:', error);
 }
 };

 /**
 * Handler for 'Edit Styles' button
 */
 const onEditStylesClick = () => {
 try {
 const textarea = document.createElement('textarea');
 textarea.className = 'style-editor';
 textarea.rows = 15;
 textarea.placeholder = 'Enter CSS styles here...';

 // Load saved styles from localStorage if available
 const storedStyles = localStorage.getItem('userStyles') || '';
 textarea.value = storedStyles;

 const saveButton = document.createElement('button');
 saveButton.type = 'button';
 saveButton.className = 'btn btn-primary';
 saveButton.textContent = 'Save Styles';

 const container = document.createElement('div');
 container.appendChild(textarea);
 container.appendChild(saveButton);

 saveButton.addEventListener('click', () => {
 const styles = textarea.value;
 localStorage.setItem('userStyles', styles);
 openModal('Styles Saved', document.createTextNode('Styles have been saved locally.'));
 });

 openModal('Edit Styles', container);
 } catch (error) {
 console.error('onEditStylesClick error:', error);
 }
 };

 /**
 * Handler for 'Manage Assets' button
 * For demonstration, shows list of assets from localStorage
 */
 const onManageAssetsClick = () => {
 try {
 // Dummy implementation: show stored asset keys
 const assets = JSON.parse(localStorage.getItem('userAssets') || '{}');
 const container = document.createElement('div');
 container.className = 'assets-container';

 if (Object.keys(assets).length === 0) {
 container.appendChild(document.createTextNode('No assets uploaded yet.'));
 } else {
 const ul = document.createElement('ul');
 ul.className = 'assets-list';
 Object.entries(assets).forEach(([name, url]) => {
 const li = document.createElement('li');
 const link = document.createElement('a');
 link.href = url;
 link.textContent = name;
 link.target = '_blank';
 link.rel = 'noopener noreferrer';
 li.appendChild(link);
 ul.appendChild(li);
 });
 container.appendChild(ul);
 }

 openModal('Manage Assets', container);
 } catch (error) {
 console.error('onManageAssetsClick error:', error);
 }
 };

 /**
 * Handler for 'Preview Site' button
 * For demo: redirects to preview.html
 */
 const onPreviewSiteClick = () => {
 try {
 window.location.href = 'pages/preview.html';
 } catch (error) {
 console.error('onPreviewSiteClick error:', error);
 }
 };

 /**
 * Sets up event listeners for builder tool buttons
 */
 const initBuilderToolButtons = () => {
 try {
 const newPageBtn = $('#new-page-btn');
 const editStylesBtn = $('#edit-style-btn');
 const manageAssetsBtn = $('#manage-assets-btn');
 const previewSiteBtn = $('#preview-site-btn');

 if (newPageBtn) newPageBtn.addEventListener('click', onCreateNewPageClick);
 if (editStylesBtn) editStylesBtn.addEventListener('click', onEditStylesClick);
 if (manageAssetsBtn) manageAssetsBtn.addEventListener('click', onManageAssetsClick);
 if (previewSiteBtn) previewSiteBtn.addEventListener('click', onPreviewSiteClick);
 } catch (error) {
 console.error('initBuilderToolButtons error:', error);
 }
 };

 // Init all on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 initMobileNavToggle();
 highlightActiveNavLink();
 enhanceFormsValidation();
 initSmoothScrolling();
 initAccessibilityFixes();
 initKeyboardShortcuts();
 initBuilderToolButtons();
 });

})();

//# sourceURL=builder.js
