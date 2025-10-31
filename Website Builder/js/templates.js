// templates.js - Handles templates page features and shared site interactions

const TemplatesScript = (() => {
 // Selectors used globally
 const selectors = {
 nav: '#main-nav',
 navLinks: '.nav-link',
 mobileNavToggleClass: 'nav-toggle',
 templatesList: '.template-list',
 selectButton: '.select-button',
 startBuildingBtn: '#start-building'
 };

 // Utility functions
 const utils = {
 safeQuerySelector: (selector, base = document) => {
 try {
 return base.querySelector(selector);
 } catch {
 return null;
 }
 },
 safeQuerySelectorAll: (selector, base = document) => {
 try {
 return Array.from(base.querySelectorAll(selector));
 } catch {
 return [];
 }
 },
 createElement: (tag, props = {}, ...children) => {
 const el = document.createElement(tag);
 Object.entries(props).forEach(([key, value]) => {
 if (key === 'className') el.className = value;
 else if (key === 'textContent') el.textContent = value;
 else if (key === 'innerHTML') el.innerHTML = value;
 else el.setAttribute(key, value);
 });
 children.forEach(child => {
 if (child) el.appendChild(child);
 });
 return el;
 },
 debounce: (func, wait=200) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func.apply(null, args), wait);
 };
 },
 sanitizeHTML: (str) => {
 const temp = document.createElement('div');
 temp.textContent = str;
 return temp.innerHTML;
 }
 };

 // Mobile Navigation Toggle
 function setupMobileNavToggle() {
 const nav = utils.safeQuerySelector(selectors.nav);
 if (!nav) return;

 // Create toggle button if not already present
 if (!document.querySelector(`.${selectors.mobileNavToggleClass}`)) {
 const toggleBtn = utils.createElement('button', {
 className: selectors.mobileNavToggleClass,
 type: 'button',
 'aria-label': 'Toggle navigation menu',
 'aria-expanded': 'false'
 });
 toggleBtn.innerHTML = '<span class="hamburger-icon">&#9776;</span>'; // Hamburger icon
 nav.parentElement.insertBefore(toggleBtn, nav);

 toggleBtn.addEventListener('click', () => {
 nav.classList.toggle('nav-open');
 const expanded = nav.classList.contains('nav-open');
 toggleBtn.setAttribute('aria-expanded', expanded);
 });
 }
 }

 // Highlight the active nav link based on current page
 function highlightActiveNavLink() {
 const navLinks = utils.safeQuerySelectorAll(selectors.navLinks);
 if (!navLinks.length) return;

 const currentPage = window.location.pathname.split('/').pop() || 'index.html';
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href === currentPage) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 }

 // Templates Page - Handle template selection with event delegation
 function setupTemplateSelection() {
 const templatesList = utils.safeQuerySelector(selectors.templatesList);
 if (!templatesList) return;

 templatesList.addEventListener('click', event => {
 const target = event.target;
 if (!target) return;

 // User clicked a select button
 if (target.matches(selectors.selectButton)) {
 event.preventDefault();
 const templateItem = target.closest('.template-item');
 if (!templateItem) return;

 const figcaption = templateItem.querySelector('figcaption');
 const templateName = figcaption ? figcaption.textContent.trim() : 'Template';

 const confirmSelection = window.confirm(
 `Are you sure you want to select the "${templateName}" template? This will overwrite your current website builder content.`
 );

 if (confirmSelection) {
 try {
 // Save template selection in localStorage (simulate applying template)
 const templateData = {
 name: templateName,
 timestamp: Date.now()
 };
 localStorage.setItem('selectedTemplate', JSON.stringify(templateData));

 // Also clear builder content to reflect new template
 localStorage.removeItem('builderContent');

 alert(`\"${templateName}\" template selected. Please visit the Builder page to start editing.`);
 } catch (error) {
 console.error('Error saving selected template:', error);
 alert('There was an error selecting the template. Please try again.');
 }
 }
 }
 });
 }

 // Enhance Start Building button on index or other pages
 function enhanceStartBuildingButton() {
 const startBtn = utils.safeQuerySelector(selectors.startBuildingBtn);
 if (!startBtn) return;

 // Add keyboard focus styles or aria attributes if needed (CSS usually suffices)
 // Add click analytics or additional user feedback if desired
 }

 // Accessibility enhancements
 function setupAccessibilityFeatures() {
 // Example: keyboard focus styles handled by CSS, ensure focus outline visible
 // You can add additional ARIA roles or attributes if more interactive
 }

 // Global Initialization
 function init() {
 document.addEventListener('DOMContentLoaded', () => {
 try {
 setupMobileNavToggle();
 highlightActiveNavLink();
 enhanceStartBuildingButton();
 setupTemplateSelection();
 setupAccessibilityFeatures();
 } catch (error) {
 console.error('Error initializing templates.js:', error);
 }
 });
 }

 // Public API
 return {
 init
 };
})();

TemplatesScript.init();

//# sourceURL=templates.js
