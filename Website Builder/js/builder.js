// builder.js
// Main script for Website Builder project
// Handles global site features: navigation, active link detection, builder interface interactions, live preview update, and utilities

// Immediately Invoked Function Expression (IIFE) to avoid polluting global scope
(() => {
 'use strict';

 // Helper function: safely query single element
 const qs = (selector, parent = document) => parent.querySelector(selector);
 // Helper function: safely query multiple elements
 const qsa = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

 // Mobile Navigation Toggle
 const setupMobileNavigation = () => {
 try {
 const mainNav = qs('#main-nav');
 if (!mainNav) return;

 // Check if a mobile toggle button is present or create one
 let toggleBtn = qs('#mobile-nav-toggle');
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.id = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.innerHTML = '&#9776;'; // Hamburger icon

 const headerContainer = qs('.header-container');
 if (headerContainer) headerContainer.insertBefore(toggleBtn, mainNav);
 }

 toggleBtn.addEventListener('click', () => {
 mainNav.classList.toggle('nav-open');
 const expanded = mainNav.classList.contains('nav-open');
 toggleBtn.setAttribute('aria-expanded', expanded);
 });
 } catch (error) {
 console.error('Error setting up mobile navigation:', error);
 }
 };

 // Active Page Link Highlighting
 const highlightActiveNav = () => {
 try {
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 const navLinks = qsa('.nav-link, .footer-nav-link');
 navLinks.forEach(link => {
 const linkPath = link.getAttribute('href');
 if (linkPath === currentPath) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch (error) {
 console.error('Error highlighting active navigation links:', error);
 }
 };

 // Utilities for Builder Interface
 const builderUtils = {
 // Create DOM elements for different components
 createTextElement: () => {
 const p = document.createElement('p');
 p.textContent = 'Editable Text';
 p.contentEditable = 'true';
 p.className = 'canvas-text';
 p.setAttribute('tabindex', '0');
 return p;
 },

 createImageElement: () => {
 const img = document.createElement('img');
 img.src = 'images/placeholder-image.png';
 img.alt = 'Placeholder Image';
 img.className = 'canvas-image';
 img.setAttribute('tabindex', '0');
 img.style.maxWidth = '100%';
 img.style.height = 'auto';
 return img;
 },

 createButtonElement: () => {
 const btn = document.createElement('button');
 btn.textContent = 'Click Me';
 btn.className = 'canvas-button';
 btn.setAttribute('tabindex', '0');
 btn.type = 'button';
 return btn;
 },

 createFormElement: () => {
 const form = document.createElement('form');
 form.className = 'canvas-form';
 form.innerHTML = `
 <label>Name:<br><input type="text" name="name" placeholder="Your name" required></label><br>
 <label>Email:<br><input type="email" name="email" placeholder="Your email" required></label><br>
 <button type="submit">Submit</button>
 `;
 return form;
 },

 // Serialize canvas content to HTML string
 serializeCanvas: (canvas) => {
 if (!canvas) return '';
 // Clone canvas to avoid modifying original
 const clone = canvas.cloneNode(true);
 // Remove placeholder if present
 const placeholder = qs('.canvas-placeholder', clone);
 if (placeholder) placeholder.remove();
 // Remove contentEditable attributes for production-ready HTML
 qsa('[contenteditable]', clone).forEach(el => el.removeAttribute('contenteditable'));
 return clone.innerHTML;
 },

 // Load serialized HTML into iframe preview
 updatePreview: (html) => {
 try {
 const iframe = qs('#preview-frame');
 if (!iframe) return;
 iframe.srcdoc = html || '<p>Start building your website to see the live preview here.</p>';
 } catch (error) {
 console.error('Error updating live preview:', error);
 }
 }
 };

 // Builder Interface Logic
 const setupBuilderInterface = () => {
 try {
 const toolbox = qs('#toolbox');
 const canvas = qs('#canvas');
 const preview = qs('#preview-frame');

 if (!toolbox || !canvas) return;

 // Remove placeholder text on first element added
 const removePlaceholder = () => {
 const placeholder = qs('.canvas-placeholder', canvas);
 if (placeholder) placeholder.remove();
 };

 // Append new element to canvas and update preview
 const addElementToCanvas = (element) => {
 removePlaceholder();
 canvas.appendChild(element);
 updateCanvasPreview();
 };

 // Update live preview iframe
 const updateCanvasPreview = () => {
 const canvasHTML = builderUtils.serializeCanvas(canvas);
 builderUtils.updatePreview(canvasHTML);
 };

 // Event delegation for toolbox clicks
 toolbox.addEventListener('click', (event) => {
 const target = event.target;
 if (!target) return;
 if (!target.classList.contains('tool-item')) return;

 const toolName = target.textContent.trim();
 switch (toolName) {
 case 'Add Text':
 addElementToCanvas(builderUtils.createTextElement());
 break;
 case 'Add Image':
 addElementToCanvas(builderUtils.createImageElement());
 break;
 case 'Add Button':
 addElementToCanvas(builderUtils.createButtonElement());
 break;
 case 'Add Form':
 addElementToCanvas(builderUtils.createFormElement());
 break;
 default:
 break;
 }
 });

 // Enable drag-and-drop sorting for canvas elements
 // Using HTML5 Drag and Drop API
 const dragState = {
 draggedElem: null,
 placeholderElem: null
 };

 canvas.addEventListener('dragstart', (e) => {
 if (!e.target) return;
 dragState.draggedElem = e.target;
 e.dataTransfer.effectAllowed = 'move';
 try {
 // Firefox requires dataTransfer data
 e.dataTransfer.setData('text/plain', 'drag');
 } catch (err) {
 // Ignore
 }
 // Create placeholder
 dragState.placeholderElem = document.createElement('div');
 dragState.placeholderElem.className = 'drag-placeholder';
 dragState.placeholderElem.style.height = `${e.target.offsetHeight}px`;
 });

 canvas.addEventListener('dragover', (e) => {
 e.preventDefault();
 if (!dragState.placeholderElem || !dragState.draggedElem) return;
 const afterElem = getDragAfterElement(canvas, e.clientY);
 if (afterElem == null) {
 canvas.appendChild(dragState.placeholderElem);
 } else {
 canvas.insertBefore(dragState.placeholderElem, afterElem);
 }
 });

 canvas.addEventListener('drop', (e) => {
 e.preventDefault();
 if (!dragState.draggedElem || !dragState.placeholderElem) return;
 canvas.insertBefore(dragState.draggedElem, dragState.placeholderElem);
 dragState.placeholderElem.remove();
 dragState.draggedElem = null;
 dragState.placeholderElem = null;
 updateCanvasPreview();
 });

 canvas.addEventListener('dragend', (e) => {
 if (dragState.placeholderElem) {
 dragState.placeholderElem.remove();
 }
 dragState.draggedElem = null;
 dragState.placeholderElem = null;
 });

 // Make canvas children draggable when added
 const observer = new MutationObserver((mutations) => {
 mutations.forEach(mutation => {
 if (mutation.type === 'childList') {
 mutation.addedNodes.forEach(node => {
 if (node.nodeType === Node.ELEMENT_NODE) {
 node.setAttribute('draggable', 'true');
 }
 });
 }
 });
 });
 observer.observe(canvas, { childList: true });

 // Helper function for dragover to find element after pointer
 const getDragAfterElement = (container, y) => {
 const draggableElements = [...container.querySelectorAll('[draggable]:not(.drag-placeholder)')];
 return draggableElements.reduce((closest, child) => {
 const box = child.getBoundingClientRect();
 const offset = y - box.top - box.height / 2;
 if (offset < 0 && offset > closest.offset) {
 return { offset: offset, element: child };
 } else {
 return closest;
 }
 }, { offset: Number.NEGATIVE_INFINITY }).element || null;
 };

 // Enable editing and update preview on text input
 canvas.addEventListener('input', (event) => {
 if (!event.target) return;
 if (event.target.classList.contains('canvas-text')) {
 updateCanvasPreview();
 }
 });

 // Simple demo alert for buttons in canvas
 canvas.addEventListener('click', (event) => {
 if (!event.target) return;
 if (event.target.classList.contains('canvas-button')) {
 alert('Button clicked! This is a demo action.');
 }
 });

 // Prevent default submit for forms in canvas and show alert
 canvas.addEventListener('submit', (event) => {
 if (!event.target) return;
 event.preventDefault();
 alert('Form submitted! This is a demo form submission.');
 });

 // Initial preview update
 updateCanvasPreview();
 } catch (error) {
 console.error('Error setting up builder interface:', error);
 }
 };

 // Global Initialization on DOM content loaded
 const init = () => {
 setupMobileNavigation();
 highlightActiveNav();

 // Only initialize builder interface if builder page detected
 if (window.location.pathname.endsWith('builder.html')) {
 setupBuilderInterface();
 }
 };

 // Run init when DOM fully loaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 init();
 } catch (error) {
 console.error('Initialization error:', error);
 }
 });

 // Expose utility functions (optional), helpful for debugging
 window.builderUtils = builderUtils;
})();

// End of builder.js
