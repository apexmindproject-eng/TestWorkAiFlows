/*
 editor.js - JavaScript for Website Builder project
 Enhances the Editor page (editor.html) with interactive editor tools:
 add text, add image, add section
 and manages preview area updates.
 Also includes global defensive checks so it won't interfere or break on other pages.

 RESPONSIBILITIES:
 - Handle editor tool buttons click events
 - Create editable content blocks dynamically
 - Enable drag-and-drop reordering of preview blocks
 - Enable inline text editing for text blocks
 - Allow image URL insertion and display
 - Section blocks as group containers
 - Maintain placeholder text when empty preview
 - Handle accessibility and keyboard support
 - Defensive coding to allow usage across all pages
*/

(() => {
 'use strict';

 const qs = (selector, scope = document) => scope.querySelector(selector);
 const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

 // Types of blocks
 const BLOCK_TYPES = {
 TEXT: 'text-block',
 IMAGE: 'image-block',
 SECTION: 'section-block'
 };

 // Preview container and placeholder reference
 let previewArea = null;
 let placeholder = null;

 // Generate unique IDs for blocks
 const generateId = (() => {
 let id = 0;
 return () => `block-${++id}`;
 })();

 // Create a text block element
 const createTextBlock = () => {
 const block = document.createElement('div');
 block.className = `block ${BLOCK_TYPES.TEXT}`;
 block.setAttribute('tabindex', '0');
 block.setAttribute('role', 'textbox');
 block.setAttribute('aria-label', 'Editable text block');
 block.contentEditable = true;
 block.id = generateId();
 block.style.minHeight = '40px';
 block.style.outline = 'none';
 block.innerText = 'Click here to edit text...';

 // Handle empty text styling
 block.addEventListener('focus', () => {
 if (block.innerText === 'Click here to edit text...') {
 block.innerText = '';
 }
 });

 block.addEventListener('blur', () => {
 if (!block.innerText.trim()) {
 block.innerText = 'Click here to edit text...';
 }
 });

 return block;
 };

 // Create an image block element with prompt for URL
 const createImageBlock = () => {
 const block = document.createElement('div');
 block.className = `block ${BLOCK_TYPES.IMAGE}`;
 block.id = generateId();
 block.style.minHeight = '100px';
 block.style.textAlign = 'center';
 block.style.position = 'relative';

 // Placeholder text or button to add image URL
 const placeholderText = document.createElement('p');
 placeholderText.innerText = 'Click to add image URL';
 placeholderText.style.cursor = 'pointer';
 placeholderText.style.color = '#666';

 block.appendChild(placeholderText);

 // On click, prompt user for image URL
 block.addEventListener('click', () => {
 try {
 const url = prompt('Enter image URL:', 'https://');
 if (url && url.trim()) {
 const img = document.createElement('img');
 img.src = url.trim();
 img.alt = 'User added image';
 img.style.maxWidth = '100%';
 img.style.height = 'auto';
 img.onerror = () => {
 alert('Image failed to load. Please check the URL and try again.');
 img.remove();
 placeholderText.style.display = '';
 };
 img.onload = () => {
 placeholderText.style.display = 'none';
 };
 // Remove previous image if any
 const existingImg = qs('img', block);
 if (existingImg) existingImg.remove();
 block.appendChild(img);
 }
 } catch (err) {
 console.error('Error adding image URL:', err);
 }
 });

 return block;
 };

 // Create a section block element that can contain other blocks
 const createSectionBlock = () => {
 const block = document.createElement('section');
 block.className = `block ${BLOCK_TYPES.SECTION}`;
 block.id = generateId();
 block.style.border = '2px dashed #7cfc00'; // bright green dashed border
 block.style.padding = '10px';
 block.style.margin = '10px 0';
 block.style.position = 'relative';
 block.setAttribute('aria-label', 'Section block container');

 // Optional: Add a title bar for the section with remove button
 const titleBar = document.createElement('div');
 titleBar.style.display = 'flex';
 titleBar.style.justifyContent = 'space-between';
 titleBar.style.alignItems = 'center';
 titleBar.style.marginBottom = '8px';

 const title = document.createElement('strong');
 title.innerText = 'Section';
 titleBar.appendChild(title);

 const removeBtn = document.createElement('button');
 removeBtn.type = 'button';
 removeBtn.className = 'remove-section-btn';
 removeBtn.innerText = 'Remove Section';
 removeBtn.style.cursor = 'pointer';
 removeBtn.style.padding = '3px 6px';
 removeBtn.style.fontSize = '0.9rem';
 removeBtn.setAttribute('aria-label', 'Remove this section');

 removeBtn.addEventListener('click', () => {
 try {
 if (confirm('Are you sure you want to remove this entire section?')) {
 block.remove();
 refreshPlaceholderVisibility();
 }
 } catch (err) {
 console.error('Error removing section:', err);
 }
 });

 titleBar.appendChild(removeBtn);
 block.appendChild(titleBar);

 // Container inside section where user can add blocks
 const contentContainer = document.createElement('div');
 contentContainer.className = 'section-content';
 contentContainer.style.minHeight = '40px';
 contentContainer.style.backgroundColor = '#f9fff9';
 contentContainer.style.padding = '5px';
 contentContainer.style.border = '1px solid #7cfc00';
 block.appendChild(contentContainer);

 // Allow drag and drop inside section content in future or additional features

 return block;
 };

 // Check if preview area is empty and show/hide placeholder accordingly
 const refreshPlaceholderVisibility = () => {
 if (!previewArea || !placeholder) return;
 const hasBlocks = previewArea.querySelectorAll('.block').length > 0;
 if (hasBlocks) {
 placeholder.style.display = 'none';
 } else {
 placeholder.style.display = '';
 }
 };

 // Try to find suitable container where new blocks should be added
 // If cursor is inside a section-content, add there; else add to previewArea
 const getInsertionContainer = () => {
 const selection = window.getSelection();
 if (selection.rangeCount === 0) return previewArea;

 const anchorNode = selection.anchorNode;
 if (!anchorNode) return previewArea;

 // Traverse up to element if text node
 let container = anchorNode.nodeType === 3 ? anchorNode.parentElement : anchorNode;

 // Search up tree to find if inside a section-content
 while (container && container !== previewArea) {
 if (container.classList && container.classList.contains('section-content')) {
 return container;
 }
 container = container.parentElement;
 }

 return previewArea;
 };

 // Add block to previewArea or inside section
 const addBlock = (block) => {
 if (!previewArea || !block) return;

 // Remove placeholder text on first add
 refreshPlaceholderVisibility();

 const container = getInsertionContainer();
 container.appendChild(block);

 // Focus newly added text blocks automatically
 if (block.classList.contains(BLOCK_TYPES.TEXT)) {
 block.focus();
 }

 refreshPlaceholderVisibility();
 };

 // Initialize drag and drop for blocks in preview area
 const initDragAndDrop = () => {
 try {
 if (!previewArea) return;

 let dragSrcEl = null;

 // Delegate event listeners
 previewArea.addEventListener('dragstart', (e) => {
 const target = e.target;
 if (target && target.classList.contains('block')) {
 dragSrcEl = target;
 e.dataTransfer.effectAllowed = 'move';
 e.dataTransfer.setData('text/html', target.outerHTML);
 // Add dragging class
 target.classList.add('dragging');
 }
 });

 previewArea.addEventListener('dragover', (e) => {
 e.preventDefault();
 e.dataTransfer.dropEffect = 'move';
 const target = e.target.closest('.block');
 if (target && dragSrcEl && target !== dragSrcEl) {
 // Determine position relative to target
 const rect = target.getBoundingClientRect();
 const next = (e.clientY - rect.top) / rect.height > 0.5;
 previewArea.insertBefore(dragSrcEl, next ? target.nextSibling : target);
 }
 });

 previewArea.addEventListener('dragend', (e) => {
 if (dragSrcEl) {
 dragSrcEl.classList.remove('dragging');
 dragSrcEl = null;
 }
 });

 // Make each block draggable
 const setDraggable = () => {
 qsa('.block', previewArea).forEach(block => {
 block.setAttribute('draggable', 'true');
 // Remove old listeners if any (not needed with delegation)
 });
 };

 const observer = new MutationObserver(() => {
 setDraggable();
 });

 observer.observe(previewArea, { childList: true, subtree: true });

 setDraggable();
 } catch (err) {
 console.error('Error initializing drag-and-drop:', err);
 }
 };

 // Initialize editor tool buttons click events
 const initEditorTools = () => {
 try {
 const addTextBtn = qs('#add-text-btn');
 const addImageBtn = qs('#add-image-btn');
 const addSectionBtn = qs('#add-section-btn');

 if (!addTextBtn || !addImageBtn || !addSectionBtn) return;

 addTextBtn.addEventListener('click', () => {
 try {
 addBlock(createTextBlock());
 } catch (err) {
 console.error('Error adding text block:', err);
 }
 });

 addImageBtn.addEventListener('click', () => {
 try {
 addBlock(createImageBlock());
 } catch (err) {
 console.error('Error adding image block:', err);
 }
 });

 addSectionBtn.addEventListener('click', () => {
 try {
 addBlock(createSectionBlock());
 } catch (err) {
 console.error('Error adding section block:', err);
 }
 });
 } catch (error) {
 console.error('Error initializing editor tools:', error);
 }
 };

 // Clear preview area
 const clearPreview = () => {
 if (!previewArea) return;
 previewArea.innerHTML = '';
 refreshPlaceholderVisibility();
 };

 // Keyboard shortcuts for editor (optional enhancement)
 const initKeyboardShortcuts = () => {
 document.addEventListener('keydown', (e) => {
 if (document.activeElement && document.activeElement.isContentEditable) return;

 if (e.ctrlKey) {
 switch(e.key.toLowerCase()) {
 case 't': // Ctrl+T add text
 e.preventDefault();
 qs('#add-text-btn')?.click();
 break;
 case 'i': // Ctrl+I add image
 e.preventDefault();
 qs('#add-image-btn')?.click();
 break;
 case 's': // Ctrl+S add section
 e.preventDefault();
 qs('#add-section-btn')?.click();
 break;
 default:
 break;
 }
 }
 });
 };

 // Initialization on DOM loaded
 document.addEventListener('DOMContentLoaded', () => {
 try {
 if (document.body.id !== 'editor-page') return; // Only initialize on editor.html

 previewArea = qs('#preview-area');
 if (!previewArea) return;

 placeholder = qs('.placeholder-text', previewArea);

 initEditorTools();
 initDragAndDrop();
 refreshPlaceholderVisibility();
 initKeyboardShortcuts();

 } catch (err) {
 console.error('Error initializing editor page:', err);
 }
 });

})();

/*
NOTES:
- This script is scoped to the editor.html page but safely loads on other pages.
- Drag-and-drop enhances user experience reordering content blocks.
- Inline editing for text blocks mimics easy-to-use content management.
- Image blocks prompt user for URL and validate image loading.
- Section blocks group multiple blocks, can be removed as a unit.
- Keyboard shortcuts improve efficiency.
- Defensive coding and error handling throughout.
*/
