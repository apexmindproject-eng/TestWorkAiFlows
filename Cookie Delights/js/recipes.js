// recipes.js - Handles recipe page interactive features and any shared interactive features for Cookie Delights

// Defensive and modular utility functions
const safeQuery = (selector, context = document) => {
 try {
 return context.querySelector(selector) || null;
 } catch (err) {
 console.error(`safeQuery error for selector: ${selector}`, err);
 return null;
 }
};
const safeQueryAll = (selector, context = document) => {
 try {
 return Array.from(context.querySelectorAll(selector));
 } catch (err) {
 console.error(`safeQueryAll error for selector: ${selector}`, err);
 return [];
 }
};

// Event delegation utility
const delegate = (parent, selector, eventType, handler) => {
 parent.addEventListener(eventType, event => {
 let target = event.target;
 if (!target) return;
 if (target.matches(selector)) {
 handler(event, target);
 } else {
 const closest = target.closest(selector);
 if (closest && parent.contains(closest)) {
 handler(event, closest);
 }
 }
 });
};

// ----------------------------
// Recipe Details Expand/Collapse
// ----------------------------
// For 'recipes.html' page recipe items, enable toggling detailed instructions & ingredients for better UX.
const setupRecipeToggle = () => {
 try {
 const recipesList = safeQuery('#recipes-list');
 if (!recipesList) return; // Not on recipes page

 // Determine recipe items which have details to toggle
 const recipeItems = safeQueryAll('.recipe-item', recipesList);
 
 recipeItems.forEach(item => {
 const details = safeQuery('.recipe-details', item);
 if (!details) return;

 // Initially collapse details except possibly the first recipe
 details.style.maxHeight = '0';
 details.style.overflow = 'hidden';
 details.style.transition = 'max-height 0.4s ease';

 // Create toggle button dynamically if not existing
 let toggleBtn = safeQuery('.recipe-toggle-btn', item);
 if (!toggleBtn) {
 toggleBtn = document.createElement('button');
 toggleBtn.type = 'button';
 toggleBtn.className = 'recipe-toggle-btn btn btn-secondary';
 toggleBtn.textContent = 'Show Details';
 toggleBtn.setAttribute('aria-expanded', 'false');
 toggleBtn.setAttribute('aria-controls', details.id || '');
 item.insertBefore(toggleBtn, details);
 }
 });

 // Delegate click on toggle buttons
 delegate(recipesList, '.recipe-toggle-btn', 'click', (event, btn) => {
 try {
 event.preventDefault();
 const item = btn.closest('.recipe-item');
 if (!item) return;
 const details = safeQuery('.recipe-details', item);
 if (!details) return;

 const isExpanded = btn.getAttribute('aria-expanded') === 'true';

 if (isExpanded) {
 // Collapse details
 details.style.maxHeight = '0';
 btn.textContent = 'Show Details';
 btn.setAttribute('aria-expanded', 'false');
 details.setAttribute('aria-hidden', 'true');
 } else {
 // Expand details
 details.style.maxHeight = details.scrollHeight + 'px';
 btn.textContent = 'Hide Details';
 btn.setAttribute('aria-expanded', 'true');
 details.setAttribute('aria-hidden', 'false');
 }
 } catch (err) {
 console.error('Error toggling recipe details:', err);
 }
 });
 } catch (error) {
 console.error('setupRecipeToggle error:', error);
 }
};

// ----------------------------
// Recipe Search Functionality
// ----------------------------
// Enables filtering recipe cards on recipes.html based on search input for improved navigation
const setupRecipeSearch = () => {
 try {
 const recipesSection = safeQuery('#recipes-list');
 if (!recipesSection) return;

 // Create a search input dynamically at the top of recipes section
 let searchInput = safeQuery('#recipe-search-input');
 if (!searchInput) {
 searchInput = document.createElement('input');
 searchInput.type = 'search';
 searchInput.id = 'recipe-search-input';
 searchInput.placeholder = 'Search recipes...';
 searchInput.setAttribute('aria-label', 'Search cookie recipes');
 searchInput.className = 'recipe-search-input';
 recipesSection.parentNode.insertBefore(searchInput, recipesSection);
 }

 const recipeItems = safeQueryAll('.recipe-item', recipesSection);

 searchInput.addEventListener('input', () => {
 const query = searchInput.value.trim().toLowerCase();
 recipeItems.forEach(item => {
 // Search in title and description only for simplicity
 const title = safeQuery('.recipe-title', item)?.textContent.toLowerCase() || '';
 const description = safeQuery('.recipe-description', item)?.textContent.toLowerCase() || '';

 if (title.includes(query) || description.includes(query)) {
 item.style.display = '';
 } else {
 item.style.display = 'none';
 }
 });
 });
 } catch (error) {
 console.error('Recipe search setup error:', error);
 }
};

// ----------------------------
// Ingredients Checklist
// ----------------------------
// Enable users to check off ingredients for a recipe to track what is used or bought
const setupIngredientsChecklist = () => {
 try {
 const recipesSection = safeQuery('#recipes-list');
 if (!recipesSection) return;

 const ingredientLists = safeQueryAll('.ingredients-list', recipesSection);
 ingredientLists.forEach(ul => {
 // Make each ingredient an interactive checkbox list item
 Array.from(ul.children).forEach(li => {
 if (li.getAttribute('data-has-checkbox') === 'true') return; // Already processed

 // Wrap content with a label
 const label = document.createElement('label');
 label.className = 'ingredient-label';

 const checkbox = document.createElement('input');
 checkbox.type = 'checkbox';
 checkbox.className = 'ingredient-checkbox';

 // Preserve text
 const text = li.textContent;
 li.textContent = '';

 label.appendChild(checkbox);
 label.appendChild(document.createTextNode(text));

 li.appendChild(label);
 li.setAttribute('data-has-checkbox', 'true');
 });
 });

 // Optional: persist checked state in sessionStorage for current session
 delegate(recipesSection, '.ingredient-checkbox', 'change', (event, checkbox) => {
 try {
 const label = checkbox.parentElement;
 const li = label?.parentElement;
 if (!li) return;

 // Mark or unmark checked class for styling
 if (checkbox.checked) {
 li.classList.add('ingredient-checked');
 } else {
 li.classList.remove('ingredient-checked');
 }

 // Could add persistence here based on recipe ID and ingredient text - omitted for brevity
 } catch (err) {
 console.error('Error in ingredient checkbox change:', err);
 }
 });
 } catch (error) {
 console.error('setupIngredientsChecklist error:', error);
 }
};

// ----------------------------
// Print Recipe Button
// ----------------------------
// Adds print functionality for recipe details to print easily
const setupPrintRecipeButtons = () => {
 try {
 const recipesList = safeQuery('#recipes-list');
 if (!recipesList) return;

 // Add print buttons dynamically if not already present
 const recipeItems = safeQueryAll('.recipe-item', recipesList);
 recipeItems.forEach(item => {
 if (safeQuery('.print-recipe-btn', item)) return; // Already has button

 const printBtn = document.createElement('button');
 printBtn.type = 'button';
 printBtn.className = 'print-recipe-btn btn btn-tertiary';
 printBtn.textContent = 'Print Recipe';

 // Append at bottom of recipe details or item
 const details = safeQuery('.recipe-details', item);

 (details || item).appendChild(printBtn);
 });

 delegate(recipesList, '.print-recipe-btn', 'click', (event, btn) => {
 try {
 const item = btn.closest('.recipe-item');
 if (!item) return;

 const title = safeQuery('.recipe-title', item)?.textContent || 'Recipe';
 const details = safeQuery('.recipe-details', item) || item;

 // Create a printable window or iframe
 const printWindow = window.open('', '', 'width=800,height=600');
 if (!printWindow) {
 alert('Pop-up blocked. Please allow pop-ups for printing.');
 return;
 }

 // Grab stylesheets for consistent print style
 const stylesheets = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(link => link.href);

 // Construct print content
 const printDoc = printWindow.document;
 printDoc.open();
 printDoc.write(`<!DOCTYPE html><html><head><title>Print - ${title}</title>`);
 stylesheets.forEach(href => printDoc.write(`<link rel="stylesheet" href="${href}">`));
 printDoc.write(`</head><body><h1>${title}</h1>${details.innerHTML}</body></html>`);
 printDoc.close();

 // Wait for content load then print
 printWindow.onload = () => {
 printWindow.focus();
 printWindow.print();
 printWindow.close();
 };
 } catch (err) {
 console.error('Printing recipe failed:', err);
 }
 });
 } catch (error) {
 console.error('setupPrintRecipeButtons error:', error);
 }
};

// ----------------------------
// Responsive Table Enhancement
// ----------------------------
// If in future recipes have tables, enable scroll or better UX for small screens
const enhanceResponsiveTables = () => {
 try {
 const tables = safeQueryAll('table', document);
 tables.forEach(table => {
 if (!table.classList.contains('responsive-table')) {
 table.classList.add('responsive-table');
 }

 // Wrap tables with scroll container if not already
 if (!table.parentElement.classList.contains('table-wrapper')) {
 const wrapper = document.createElement('div');
 wrapper.className = 'table-wrapper';
 table.parentNode.insertBefore(wrapper, table);
 wrapper.appendChild(table);
 }
 });
 } catch (error) {
 console.error('Error enhancing tables:', error);
 }
};

// ----------------------------
// DOMContentLoaded - initialize all features
// ----------------------------
document.addEventListener('DOMContentLoaded', () => {
 // Only activate recipe page specific features on recipes.html
 if (window.location.pathname.includes('recipes.html') || window.location.pathname === '/' || window.location.pathname.endsWith('recipes.html')) {
 setupRecipeToggle();
 setupRecipeSearch();
 setupIngredientsChecklist();
 setupPrintRecipeButtons();
 enhanceResponsiveTables();
 }

 // Other pages might include recipe cards (e.g. homepage featured recipes) - setup basic enhancements
 else {
 // If recipe cards exist outside recipes page, enable print and toggle if necessary in future
 }
});

//# sourceURL=recipes.js
