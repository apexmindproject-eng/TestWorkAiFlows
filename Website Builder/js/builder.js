// builder.js - Handles website builder page interactions and shared site features

// Encapsulate all functionality to avoid polluting global namespace
const WebsiteBuilder = (() => {
 // Cache frequently accessed elements
 const selectors = {
 header: '#site-header',
 nav: '#main-nav',
 navLinks: '.nav-link',
 startBuildingBtn: '#start-building',
 editorContainer: '#editor-container',
 saveWebsiteBtn: '#save-website',
 saveMessage: '#save-message',
 templatesList: '.template-list',
 selectTemplateButtons: '.select-button'
 };

 // Utility: Helpers
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
 if (key === 'className') { el.className = value; }
 else if (key === 'textContent') { el.textContent = value; }
 else if (key === 'innerHTML') { el.innerHTML = value; }
 else { el.setAttribute(key, value); }
 });
 children.forEach(child => {
 if (child) el.appendChild(child);
 });
 return el;
 },
 debounce: (func, wait = 100) => {
 let timeout;
 return (...args) => {
 clearTimeout(timeout);
 timeout = setTimeout(() => func.apply(this, args), wait);
 };
 },
 sanitizeHTML: (str) => {
 const temp = document.createElement('div');
 temp.textContent = str;
 return temp.innerHTML;
 }
 };

 // Global state for editor content
 let editorContent = [];

 // Mobile Navigation Toggle
 function setupMobileNavToggle() {
 const nav = utils.safeQuerySelector(selectors.nav);
 if (!nav) return;
 // Create toggle button if not exists
 if (!utils.safeQuerySelector('.nav-toggle')) {
 const toggleBtn = utils.createElement('button', {
 className: 'nav-toggle',
 'aria-label': 'Toggle navigation menu',
 type: 'button'
 },
 utils.createElement('span', {className: 'hamburger-icon', textContent: '\u2261'}) // Unicode triple bar as hamburger
 );
 nav.parentElement.insertBefore(toggleBtn, nav);
 toggleBtn.addEventListener('click', () => {
 nav.classList.toggle('nav-open');
 toggleBtn.setAttribute('aria-expanded', nav.classList.contains('nav-open'));
 });
 }
 }

 // Highlight current page navigation link
 function highlightActiveNavLink() {
 const navLinks = utils.safeQuerySelectorAll(selectors.navLinks);
 if (!navLinks.length) return;
 const currentPath = window.location.pathname.split('/').pop() || 'index.html';
 navLinks.forEach(link => {
 const href = link.getAttribute('href');
 if (href === currentPath) {
 link.classList.add('current');
 link.setAttribute('aria-current', 'page');
 } else {
 link.classList.remove('current');
 link.removeAttribute('aria-current');
 }
 });
 }

 // =======================
 // Builder Page Specific
 // =======================

 // Initialize the editor with drag & drop support and element additions
 function initEditor() {
 const editor = utils.safeQuerySelector(selectors.editorContainer);
 if (!editor) return;

 // Store initial placeholder if exists
 const placeholder = editor.querySelector('.editor-placeholder');

 // Make editor container droppable and interactable
 editor.setAttribute('tabindex', '0'); // Make focusable for accessibility

 // Clear editor content on load if saved content exists
 const savedContent = loadFromLocalStorage('builderContent');
 if (savedContent && Array.isArray(savedContent) && savedContent.length) {
 renderEditorContent(savedContent, editor);
 editorContent = savedContent;
 } else {
 editorContent = [];
 }

 // Remove placeholder once user adds content
 function hidePlaceholder() {
 if (placeholder && editorContent.length > 0) placeholder.style.display = 'none';
 else if (placeholder) placeholder.style.display = '';
 }

 // Attach drag and drop events for reordering
 let draggedItemIndex = null;

 // General event delegation for editor items
 editor.addEventListener('click', event => {
 const target = event.target;
 if (!target) return;

 // Remove element button
 if (target.classList.contains('remove-element-btn')) {
 const index = parseInt(target.dataset.index, 10);
 if (!isNaN(index) && editorContent[index]) {
 editorContent.splice(index, 1);
 updateEditor(editor);
 }
 }
 });

 // Drag and drop handlers
 editor.addEventListener('dragstart', event => {
 if (event.target && event.target.classList.contains('editor-element')) {
 draggedItemIndex = Array.from(editor.children).indexOf(event.target);
 event.dataTransfer.effectAllowed = 'move';
 event.dataTransfer.setData('text/plain', 'dragging');
 // Highlight drag source
 event.target.classList.add('dragging');
 }
 });
 editor.addEventListener('dragend', event => {
 if (event.target && event.target.classList.contains('editor-element')) {
 event.target.classList.remove('dragging');
 draggedItemIndex = null;
 }
 });
 editor.addEventListener('dragover', event => {
 event.preventDefault();
 if (!event.target || !event.target.classList.contains('editor-element')) return;
 const targetIndex = Array.from(editor.children).indexOf(event.target);
 if (draggedItemIndex === null || targetIndex === draggedItemIndex) return;
 // Reorder content
 const draggedItem = editorContent.splice(draggedItemIndex, 1)[0];
 editorContent.splice(targetIndex, 0, draggedItem);
 draggedItemIndex = targetIndex;
 updateEditor(editor);
 });

 // Function to add element to editor content
 function addElement(type, data) {
 const element = {
 id: Date.now().toString(),
 type: type,
 data: data
 };
 editorContent.push(element);
 updateEditor(editor);
 }

 // Render editor content array to DOM
 function renderEditorContent(contentArray, container) {
 container.innerHTML = '';
 contentArray.forEach((item, index) => {
 const el = createEditorElement(item, index);
 container.appendChild(el);
 });
 hidePlaceholder();
 }

 // Create editor DOM element for content item
 function createEditorElement(dataItem, index) {
 const el = utils.createElement('div', {
 className: 'editor-element',
 draggable: 'true',
 'data-index': index,
 tabIndex: 0
 });

 let content;
 switch (dataItem.type) {
 case 'text':
 content = utils.createElement('p', {textContent: dataItem.data.text || ''});
 break;
 case 'image':
 content = utils.createElement('img', {
 src: dataItem.data.src || '',
 alt: dataItem.data.alt || 'User added image'
 });
 break;
 case 'button':
 content = utils.createElement('button', {textContent: dataItem.data.text || 'Button'});
 break;
 default:
 content = utils.createElement('div', {textContent: 'Unknown element type'});
 break;
 }

 const removeBtn = utils.createElement('button', {
 className: 'remove-element-btn',
 'aria-label': 'Remove element',
 type: 'button',
 'data-index': index
 },
 utils.createElement('span', {textContent: '\u2715'}) // Cross mark
 );

 el.appendChild(content);
 el.appendChild(removeBtn);
 return el;
 }

 // Update editor content UI and save state
 function updateEditor(container) {
 renderEditorContent(editorContent, container);
 hidePlaceholder();
 saveToLocalStorage('builderContent', editorContent);
 }

 // Add interface to add elements (simulate tools) - for demo, allow quick add of text or image
 // This feature can be extended, currently provide quick adds as example
 const toolsSection = utils.safeQuerySelector('#tools-section');
 if (toolsSection) {
 const toolList = toolsSection.querySelector('.tools-list');
 if (toolList) {
 toolList.innerHTML = '';
 const tools = [
 {type: 'text', label: 'Add Text Block'},
 {type: 'image', label: 'Add Image'},
 {type: 'button', label: 'Add Button'}
 ];

 tools.forEach(tool => {
 const btn = utils.createElement('button', {
 className: 'button tool-add-button',
 type: 'button',
 textContent: tool.label
 });
 btn.addEventListener('click', () => {
 if (tool.type === 'text') {
 // Prompt user for text
 const userText = prompt('Enter the text content to add:', 'Sample Text');
 if (userText && userText.trim()) {
 addElement('text', {text: userText.trim()});
 }
 } else if (tool.type === 'image') {
 // Prompt user for image URL
 const imageUrl = prompt('Enter the image URL to add:', 'https://via.placeholder.com/150');
 if (imageUrl && imageUrl.trim()) {
 addElement('image', {src: imageUrl.trim(), alt: 'User provided image'});
 }
 } else if (tool.type === 'button') {
 // Prompt for button label
 const btnLabel = prompt('Enter the button label:', 'Click Me');
 if (btnLabel && btnLabel.trim()) {
 addElement('button', {text: btnLabel.trim()});
 }
 }
 });
 toolList.appendChild(btn);
 });
 }
 }
 }

 // Save to localStorage safely
 function saveToLocalStorage(key, data) {
 try {
 const serializedData = JSON.stringify(data);
 localStorage.setItem(key, serializedData);
 } catch (err) {
 console.error('Error saving to localStorage', err);
 }
 }

 // Load from localStorage safely
 function loadFromLocalStorage(key) {
 try {
 const data = localStorage.getItem(key);
 if (!data) return null;
 return JSON.parse(data);
 } catch (err) {
 console.error('Error loading from localStorage', err);
 return null;
 }
 }

 // Bind save button click on builder.html
 function setupSaveButton() {
 const saveBtn = utils.safeQuerySelector(selectors.saveWebsiteBtn);
 const saveMsg = utils.safeQuerySelector(selectors.saveMessage);
 if (!saveBtn || !saveMsg) return;

 saveBtn.addEventListener('click', () => {
 // Save current editorContent to localStorage
 try {
 saveToLocalStorage('builderContent', editorContent);
 saveMsg.textContent = 'Website saved successfully!';
 saveMsg.style.color = 'green';
 } catch (err) {
 saveMsg.textContent = 'Failed to save website. Please try again.';
 saveMsg.style.color = 'red';
 console.error('Save error:', err);
 }
 // Clear message after 3 seconds
 setTimeout(() => {
 saveMsg.textContent = '';
 }, 3000);
 });
 }

 // Start Building button on index.html - just ensure it is focusable and accessible
 function enhanceStartBuildingButton() {
 const startBtn = utils.safeQuerySelector(selectors.startBuildingBtn);
 if (!startBtn) return;
 // For now no special logic besides focus styling handled by CSS
 }

 // Templates page: handle template selection
 function setupTemplateSelection() {
 const templatesList = utils.safeQuerySelector(selectors.templatesList);
 if (!templatesList) return;

 // Use event delegation
 templatesList.addEventListener('click', event => {
 const target = event.target;
 if (target && target.classList.contains('select-button')) {
 const templateItem = target.closest('.template-item');
 const figcaption = templateItem ? templateItem.querySelector('figcaption') : null;
 const templateName = figcaption ? figcaption.textContent.trim() : 'template';
 if (confirm(`Are you sure you want to select the '${templateName}' template? This will replace your current builder content.`)) {
 try {
 // For demo, clear builderContent and add a placeholder text element
 const newContent = [
 { id: Date.now().toString(), type: 'text', data: { text: `Template '${templateName}' selected.` } }
 ];
 saveToLocalStorage('builderContent', newContent);
 alert('Template selected and saved. Go to the Builder page to see changes.');
 } catch (err) {
 console.error('Error applying template', err);
 }
 }
 }
 });
 }

 // Accessibility: keyboard navigation support for editor elements
 function setupEditorKeyboardNavigation() {
 const editor = utils.safeQuerySelector(selectors.editorContainer);
 if (!editor) return;

 editor.addEventListener('keydown', event => {
 const target = event.target;
 if (!target || !target.classList.contains('editor-element')) return;
 const index = parseInt(target.getAttribute('data-index'), 10);
 if (isNaN(index)) return;

 switch (event.key) {
 case 'Delete':
 case 'Backspace':
 // Remove element on delete/backspace
 event.preventDefault();
 editorContent.splice(index, 1);
 updateEditorUI();
 break;
 case 'ArrowUp':
 case 'ArrowLeft':
 event.preventDefault();
 focusEditorElement(index - 1);
 break;
 case 'ArrowDown':
 case 'ArrowRight':
 event.preventDefault();
 focusEditorElement(index + 1);
 break;
 }
 });

 function focusEditorElement(idx) {
 if (idx < 0 || idx >= editorContent.length) return;
 const el = editor.querySelector(`.editor-element[data-index=\"${idx}\"]`);
 if (el) el.focus();
 }

 function updateEditorUI() {
 // Re-render editor content
 renderEditorContent(editorContent, editor);
 }

 // Reuse render function from initEditor scope, created as a closure
 }

 // Initialize script features based on current page
 function init() {
 document.addEventListener('DOMContentLoaded', () => {
 try {
 setupMobileNavToggle();
 highlightActiveNavLink();
 enhanceStartBuildingButton();

 // Only initialize builder page functionalities if builder container exists
 if (document.querySelector(selectors.editorContainer)) {
 initEditor();
 setupSaveButton();
 setupEditorKeyboardNavigation();
 }

 // Only initialize templates selection if templates list exists
 if (document.querySelector(selectors.templatesList)) {
 setupTemplateSelection();
 }

 } catch (error) {
 console.error('Error initializing builder.js:', error);
 }
 });
 }

 // Expose init method
 return {
 init
 };
})();

WebsiteBuilder.init();

//# sourceURL=builder.js
