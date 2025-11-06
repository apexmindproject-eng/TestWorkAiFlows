/*
 templates.js - JavaScript for Website Builder project
 Provides functionality primarily for templates.html page:
 - Template selection with confirmation
 - Navigation to editor page with selected template data
 - Global robust behavior with defensive coding
 - Also safely loads on other pages without errors

 Responsibilities:
 - Handle template selection buttons
 - Store selected template info in session storage
 - Confirm before proceeding
 - Event delegation for efficiency
 - Accessibility consideration
 - Performance optimizations and error handling
*/

(() => {
 'use strict';

 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Key for session storage to store selected template id
 const STORAGE_KEY_SELECTED_TEMPLATE = 'websiteBuilderSelectedTemplate';

 // Redirect to editor with template details
 const redirectToEditorWithTemplate = (templateId) => {
 try {
 if (!templateId) return;

 // Store selected template id in sessionStorage
 sessionStorage.setItem(STORAGE_KEY_SELECTED_TEMPLATE, templateId);

 // Navigate to editor
 window.location.href = 'editor.html';
 } catch (err) {
 console.error('Error redirecting to editor with template:', err);
 }
 };

 // Initialize event handlers for template selection
 const initTemplateSelection = () => {
 try {
 const templatesList = qs('.templates-list');
 if (!templatesList) return;

 templatesList.addEventListener('click', (event) => {
 try {
 const target = event.target;
 if (target && target.matches('.select-template-btn')) {
 event.preventDefault();
 // Find parent template-item id
 const templateItem = target.closest('.template-item');
 if (!templateItem) return;
 const templateId = templateItem.id || '';

 if (!templateId) {
 alert('Template ID not found. Please try again.');
 return;
 }

 // Confirm selection
 const templateTitle = qs('.template-title', templateItem)?.innerText || 'this template';
 const confirmed = confirm(`Are you sure you want to select "${templateTitle}"? This will load the template in the editor.`);

 if (confirmed) {
 redirectToEditorWithTemplate(templateId);
 }
 }
 } catch (innerErr) {
 console.error('Error handling template selection:', innerErr);
 }
 });
 } catch (err) {
 console.error('Error initializing template selection:', err);
 }
 };

 // Optional: Show previously selected template info somewhere (if needed)
 const displayPreviouslySelectedTemplate = () => {
 try {
 if (document.body.id !== 'templates-page') return;
 const selectedTemplateId = sessionStorage.getItem(STORAGE_KEY_SELECTED_TEMPLATE);
 if (!selectedTemplateId) return;

 const templateItem = qs(`#${selectedTemplateId}`);
 if (!templateItem) return;

 // Add highlight or badge to show selection
 templateItem.classList.add('selected-template');

 // Optionally show a message
 let infoBox = qs('#selected-template-info');
 if (!infoBox) {
 infoBox = document.createElement('div');
 infoBox.id = 'selected-template-info';
 infoBox.style.padding = '1em';
 infoBox.style.margin = '10px 0';
 infoBox.style.backgroundColor = '#e0ffe0';
 infoBox.style.border = '1px solid #7cfc00';
 infoBox.style.borderRadius = '4px';
 infoBox.innerText = 'You have previously selected a template. Select another or proceed to the editor.';

 const container = qs('.templates-section .container');
 if (container) container.insertBefore(infoBox, container.firstChild);
 }
 } catch (err) {
 console.error('Error displaying previously selected template info:', err);
 }
 };

 // Clear selected template from storage (optional feature if needed)
 const clearSelectedTemplate = () => {
 try {
 sessionStorage.removeItem(STORAGE_KEY_SELECTED_TEMPLATE);
 } catch (err) {
 console.error('Error clearing selected template:', err);
 }
 };

 // Initialization on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 if (document.body.id !== 'templates-page') return;

 initTemplateSelection();
 displayPreviouslySelectedTemplate();
 } catch (err) {
 console.error('Error initializing templates page:', err);
 }
 });

 // Safe no-op for other pages
})();

/*
NOTES:
- Templates page features event delegation for efficient button management.
- Session storage is used to persist selected template before redirecting to editor.
- Confirmations prevent accidental selections.
- Defensive coding ensures no interference on unrelated pages.
- Selected template is visually highlighted upon return or page refresh.
*/
