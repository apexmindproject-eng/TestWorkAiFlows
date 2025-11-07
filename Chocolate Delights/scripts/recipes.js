// recipes.js - Specialized script for Chocolate Delights website
// Handles interaction and enhancements for recipes.html page and relevant improvements across site

(() => {
 'use strict';

 // Utility selectors and event helper
 const select = (selector, all = false) => {
 try {
 if (all) return document.querySelectorAll(selector);
 return document.querySelector(selector);
 } catch (e) {
 console.error(`Invalid selector: ${selector}`, e);
 return null;
 }
 };

 const on = (element, event, handler, options = false) => {
 if (!element) return;
 element.addEventListener(event, handler, options);
 };

 const onDelegate = (parent, eventType, selector, handler) => {
 if (!parent) return;
 parent.addEventListener(eventType, event => {
 const targetElement = event.target.closest(selector);
 if (targetElement && parent.contains(targetElement)) {
 handler(event, targetElement);
 }
 });
 };

 // Recipe list expand/collapse detail toggling
 const initRecipeDetailsToggle = () => {
 const recipeList = select('#recipe-list');
 if (!recipeList) return;

 // Create a detail panel container to show full recipe details
 // For this example, we'll show/hide a placeholder detail modal or inline details
 // Since <a href="#">View Full Recipe</a> links are placeholders, intercept clicks

 onDelegate(recipeList, 'click', '.recipe-link', (event, link) => {
 event.preventDefault();
 try {
 const recipeArticle = link.closest('.recipe');
 if (!recipeArticle) return;

 // Toggle active class for expansion
 const expanded = recipeArticle.classList.toggle('expanded');

 if (expanded) {
 // Load or simulate loading full recipe details
 loadRecipeDetails(recipeArticle.id);
 } else {
 // Hide details
 hideRecipeDetails(recipeArticle);
 }
 } catch (e) {
 console.error('Error toggling recipe details:', e);
 }
 });
 };

 // Simulated recipe details loading (could be enhanced to fetch from external source)
 const loadRecipeDetails = (recipeId) => {
 try {
 const recipeArticle = select(`#${recipeId}`);
 if (!recipeArticle) return;

 // Check if details container already exists
 if (recipeArticle.querySelector('.recipe-full-details')) return;

 // Create detail container
 const detailsContainer = document.createElement('div');
 detailsContainer.className = 'recipe-full-details';
 detailsContainer.setAttribute('tabindex', '0'); // Make focusable for accessibility

 // Sample detail content - in a real app, load from JSON/api or static markup
 const detailsContent = getRecipeDetailsContent(recipeId);
 detailsContainer.innerHTML = detailsContent;

 recipeArticle.appendChild(detailsContainer);

 detailsContainer.focus();

 } catch (e) {
 console.error('Error loading recipe details:', e);
 }
 };

 // Hide recipe full details
 const hideRecipeDetails = (recipeArticle) => {
 try {
 const detailsContainer = recipeArticle.querySelector('.recipe-full-details');
 if (detailsContainer) {
 detailsContainer.remove();
 }
 } catch (e) {
 console.error('Error hiding recipe details:', e);
 }
 };

 // Return HTML string for recipe full details by recipe ID
 const getRecipeDetailsContent = (recipeId) => {
 // Static sample content for each recipe. In a real site, this might be a JSON data source.
 const detailsData = {
 'recipe-chocolate-cake': `
 <h4>Classic Chocolate Cake Recipe Details</h4>
 <h5>Ingredients:</h5>
 <ul>
 <li>2 cups flour</li>
 <li>2 cups sugar</li>
 <li>3/4 cup cocoa powder</li>
 <li>1.5 tsp baking powder</li>
 <li>1.5 tsp baking soda</li>
 <li>1 tsp salt</li>
 <li>1 cup milk</li>
 <li>1/2 cup vegetable oil</li>
 <li>2 eggs</li>
 <li>2 tsp vanilla extract</li>
 <li>1 cup boiling water</li>
 </ul>
 <h5>Instructions:</h5>
 <ol>
 <li>Preheat oven to 350°F (175°C). Grease and flour two 9-inch pans.</li>
 <li>Mix dry ingredients together in a bowl.</li>
 <li>Add milk, vegetable oil, eggs, and vanilla. Beat on medium speed 2 minutes.</li>
 <li>Stir in boiling water (batter will be thin).</li>
 <li>Pour into pans and bake 30-35 minutes.</li>
 <li>Cool and frost as desired.</li>
 </ol>
 `,
 'recipe-chocolate-truffles': `
 <h4>Chocolate Truffles Recipe Details</h4>
 <h5>Ingredients:</h5>
 <ul>
 <li>8 oz bittersweet chocolate</li>
 <li>1/2 cup heavy cream</li>
 <li>1 tsp vanilla extract</li>
 <li>Cocoa powder for dusting</li>
 </ul>
 <h5>Instructions:</h5>
 <ol>
 <li>Chop chocolate and place in a bowl.</li>
 <li>Heat cream until simmering and pour over chocolate.</li>
 <li>Let sit for 2 minutes, then stir until smooth.</li>
 <li>Stir in vanilla extract.</li>
 <li>Chill mixture for 2 hours until firm.</li>
 <li>Scoop and roll into balls, dust with cocoa powder.</li>
 </ol>
 `,
 'recipe-hot-chocolate': `
 <h4>Rich Hot Chocolate Recipe Details</h4>
 <h5>Ingredients:</h5>
 <ul>
 <li>2 cups milk</li>
 <li>2 tbsp cocoa powder</li>
 <li>2 tbsp sugar</li>
 <li>1/2 tsp vanilla extract</li>
 <li>Pinch of salt</li>
 <li>Whipped cream for topping (optional)</li>
 </ul>
 <h5>Instructions:</h5>
 <ol>
 <li>Heat milk on medium heat until warm but not boiling.</li>
 <li>Whisk cocoa powder, sugar, salt into warm milk until dissolved.</li>
 <li>Remove from heat and stir in vanilla extract.</li>
 <li>Serve topped with whipped cream if desired.</li>
 </ol>
 `,
 'recipe-chocolate-bar': `
 <h4>Homemade Chocolate Bars Recipe Details</h4>
 <h5>Ingredients:</h5>
 <ul>
 <li>1 cup cocoa butter</li>
 <li>1 cup cocoa powder</li>
 <li>1/2 cup powdered sugar</li>
 <li>1 tsp vanilla extract</li>
 <li>Nuts or dried fruit (optional)</li>
 </ul>
 <h5>Instructions:</h5>
 <ol>
 <li>Melt cocoa butter in a double boiler.</li>
 <li>Remove from heat, stir in cocoa powder, sugar, and vanilla.</li>
 <li>Pour mixture into molds.</li>
 <li>Add nuts or dried fruit if desired.</li>
 <li>Refrigerate until solid.</li>
 </ol>
 `
 };
 return detailsData[recipeId] || '<p>Details are not available for this recipe.</p>';
 };

 // Filter recipes by keyword search
 const initRecipeSearchFilter = () => {
 const searchInput = select('#recipe-search');
 if (!searchInput) return; // No search input on page

 const recipeList = select('#recipe-list');
 if (!recipeList) return;

 on(searchInput, 'input', (event) => {
 const query = event.target.value.toLowerCase().trim();
 const recipes = select('.recipe', true);

 recipes.forEach(recipe => {
 const title = recipe.querySelector('h3')?.textContent.toLowerCase() || '';
 const desc = recipe.querySelector('p')?.textContent.toLowerCase() || '';
 if (title.includes(query) || desc.includes(query)) {
 recipe.style.display = '';
 } else {
 recipe.style.display = 'none';
 }
 });
 });
 };

 // Keyboard shortcuts for recipe modal controls (if used)
 const initKeyboardRecipeControls = () => {
 // Currently no modal used, but if modal added, implement keyboard controls here
 };

 // Lazy load images for recipes to improve performance
 const initLazyLoadImages = () => {
 try {
 const images = select('.recipe-image', true);
 if (!images) return;

 if ('loading' in HTMLImageElement.prototype) {
 // Native lazy loading supported
 images.forEach(img => {
 img.setAttribute('loading', 'lazy');
 });
 } else {
 // Fallback to intersection observer
 const observer = new IntersectionObserver(
 (entries, observerRef) => {
 entries.forEach(entry => {
 if (entry.isIntersecting) {
 const img = entry.target;
 const src = img.getAttribute('data-src');
 if (src) {
 img.src = src;
 img.removeAttribute('data-src');
 }
 observerRef.unobserve(img);
 }
 });
 },
 { rootMargin: '0px 0px 256px 0px' }
 );

 images.forEach(img => {
 const src = img.getAttribute('src');
 if (src) {
 // Move current src to data-src and replace src with placeholder
 img.setAttribute('data-src', src);
 img.src = '';
 observer.observe(img);
 }
 });
 }
 } catch(e) {
 console.error('Lazy load images error:', e);
 }
 };

 // Accessibility: trap focus inside expanded recipe details (optional enhancement)
 const trapFocusInRecipeDetails = (container) => {
 if (!container) return;
 const focusableSelectors = [
 'a[href]','button:not([disabled])','textarea','input[type="text"]','input[type="email"]','select',
 '[tabindex]:not([tabindex="-1"])'
 ];
 const focusableElements = container.querySelectorAll(focusableSelectors.join(','));
 if (focusableElements.length === 0) return;

 const firstEl = focusableElements[0];
 const lastEl = focusableElements[focusableElements.length - 1];

 const keyListener = e => {
 if (e.key === 'Tab') {
 if (e.shiftKey) {
 // Shift + Tab
 if (document.activeElement === firstEl) {
 e.preventDefault();
 lastEl.focus();
 }
 } else {
 // Tab
 if (document.activeElement === lastEl) {
 e.preventDefault();
 firstEl.focus();
 }
 }
 }
 if (e.key === 'Escape') {
 // Close details on escape
 const expandedRecipe = container.closest('.recipe.expanded');
 if (expandedRecipe) {
 expandedRecipe.classList.remove('expanded');
 hideRecipeDetails(expandedRecipe);
 expandedRecipe.querySelector('.recipe-link')?.focus();
 }
 }
 };

 container.addEventListener('keydown', keyListener);
 };


 // Initialization main function
 const init = () => {
 try {
 initRecipeDetailsToggle();
 initRecipeSearchFilter(); // if search present
 initLazyLoadImages();
 initKeyboardRecipeControls();
 } catch (error) {
 console.error('Error during recipes.js initialization:', error);
 }
 };

 // Run init on DOMContentLoaded
 document.addEventListener('DOMContentLoaded', init);

})();

// End of recipes.js
