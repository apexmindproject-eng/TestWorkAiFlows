// marketData.js - Handles real-time data fetching and UI updates across all pages
// This script is loaded on all pages and manages live stock data retrieval and common dynamic features

const marketData = (() => {
 const API_ENDPOINT = 'https://api.example.com/stock'; // Placeholder for real API endpoint
 const FETCH_INTERVAL_MS = 10000; // 10 seconds update interval

 // Cache DOM elements used on multiple pages
 const liveStockDataContainer = document.getElementById('live-stock-data');
 const navLinks = document.querySelectorAll('#main-nav .nav-link');
 const mobileNavToggleSelector = '.mobile-nav-toggle';

 // Utility: Simple fetch wrapper with error handling
 const fetchJSON = async (url) => {
 try {
 const response = await fetch(url);
 if (!response.ok) {
 throw new Error(`Network response was not ok: ${response.status} ${response.statusText}`);
 }
 return await response.json();
 } catch (error) {
 console.error('Fetch error:', error);
 return null;
 }
 };

 // Determine active page for nav highlighting
 const setActiveNavItem = () => {
 try {
 const currentPath = window.location.pathname.split('/').pop();
 navLinks.forEach(link => {
 const linkHref = link.getAttribute('href');
 if (!linkHref) return;
 // Normalize for index.html as root
 const normalizedHref = linkHref === 'index.html' ? '' : linkHref;
 const normalizedPath = currentPath === 'index.html' ? '' : currentPath;

 if (normalizedHref === normalizedPath) {
 link.classList.add('active');
 } else {
 link.classList.remove('active');
 }
 });
 } catch(e) {
 console.warn('Error setting active nav item:', e);
 }
 };

 // Mobile navigation toggle functionality
 const setupMobileNavToggle = () => {
 const header = document.getElementById('main-header');
 if (!header) return;

 let toggleBtn = header.querySelector(mobileNavToggleSelector);
 if (!toggleBtn) {
 // Create mobile nav toggle button if not present
 toggleBtn = document.createElement('button');
 toggleBtn.className = 'mobile-nav-toggle';
 toggleBtn.setAttribute('aria-label', 'Toggle navigation menu');
 toggleBtn.innerHTML = '&#9776;'; // hamburger icon
 header.querySelector('.header-container').appendChild(toggleBtn);
 }

 toggleBtn.addEventListener('click', () => {
 const nav = document.getElementById('main-nav');
 if (!nav) return;

 const expanded = nav.getAttribute('aria-expanded') === 'true';
 nav.setAttribute('aria-expanded', String(!expanded));
 nav.classList.toggle('open');

 // Update toggle button aria-expanded
 toggleBtn.setAttribute('aria-expanded', String(!expanded));
 });
 };

 // Render live stock data entries
 const renderLiveStockData = (data) => {
 if (!liveStockDataContainer || !data) return;
 try {
 liveStockDataContainer.innerHTML = ''; // Clear existing content

 if (!Array.isArray(data) || data.length === 0) {
 liveStockDataContainer.innerHTML = '<p>No live stock data available.</p>';
 return;
 }

 const list = document.createElement('ul');
 list.className = 'stock-data-list';

 data.forEach(stock => {
 // Defensive checks
 const symbol = stock.symbol || 'N/A';
 const price = (typeof stock.price === 'number') ? stock.price.toFixed(2) : 'N/A';
 const change = (typeof stock.change === 'number') ? stock.change.toFixed(2) : 'N/A';
 const percentChange = (typeof stock.percentChange === 'number') ? stock.percentChange.toFixed(2) : 'N/A';

 // Item container
 const item = document.createElement('li');
 item.className = 'stock-data-item';

 // Compose inner HTML
 item.innerHTML = `
 <span class="stock-symbol">${symbol}</span>
 <span class="stock-price">$${price}</span>
 <span class="stock-change ${change >= 0 ? 'positive' : 'negative'}">
 ${change >= 0 ? '+' : ''}${change} (${percentChange}%)
 </span>
 `;

 list.appendChild(item);
 });

 liveStockDataContainer.appendChild(list);
 } catch (e) {
 console.error('Error rendering live stock data:', e);
 liveStockDataContainer.innerHTML = '<p>Error loading live market data.</p>';
 }
 };

 // Fetch and update live market data
 let liveDataTimer = null;
 const startLiveDataUpdates = () => {
 if (!liveStockDataContainer) return;

 const updateData = async () => {
 const data = await fetchJSON(`${API_ENDPOINT}/live`);
 if (data) {
 renderLiveStockData(data.stocks);
 } else {
 liveStockDataContainer.innerHTML = '<p>Failed to load live market data.</p>';
 }
 };

 updateData(); // Initial fetch immediately
 liveDataTimer = setInterval(updateData, FETCH_INTERVAL_MS);
 };

 const stopLiveDataUpdates = () => {
 if (liveDataTimer) {
 clearInterval(liveDataTimer);
 liveDataTimer = null;
 }
 };

 // Public init method
 const init = () => {
 setActiveNavItem();
 setupMobileNavToggle();

 // Only start live data updates on pages that contain live stock data container
 if (liveStockDataContainer) {
 startLiveDataUpdates();
 }

 // Accessibility improvement: keyboard navigation for nav menu
 const nav = document.getElementById('main-nav');
 if (nav) {
 nav.addEventListener('keydown', (event) => {
 try {
 const { key } = event;
 if (key !== 'ArrowDown' && key !== 'ArrowUp' && key !== 'Escape') return;

 const focusableItems = nav.querySelectorAll('a.nav-link');
 if (focusableItems.length === 0) return;

 const currentIndex = Array.from(focusableItems).indexOf(document.activeElement);
 if (key === 'ArrowDown') {
 event.preventDefault();
 const nextIndex = (currentIndex + 1) % focusableItems.length;
 focusableItems[nextIndex].focus();
 } else if (key === 'ArrowUp') {
 event.preventDefault();
 const prevIndex = (currentIndex - 1 + focusableItems.length) % focusableItems.length;
 focusableItems[prevIndex].focus();
 } else if (key === 'Escape') {
 nav.querySelector('#main-nav').blur();
 nav.setAttribute('aria-expanded', 'false');
 nav.classList.remove('open');
 }
 } catch(e) {
 console.warn('Navigation keyboard error:', e);
 }
 });
 }

 // Other common UI interactions could be initialized here
 };

 // Cleanup before page unload
 const destroy = () => {
 stopLiveDataUpdates();
 };

 // Expose public API
 return {
 init,
 destroy,
 fetchJSON // exporting for usage by other modules if needed
 };
})();

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
 try {
 marketData.init();
 } catch (err) {
 console.error('Initialization error in marketData.js:', err);
 }
});

// Listen to page unload to cleanup timers
window.addEventListener('beforeunload', () => {
 marketData.destroy();
});

//# sourceMappingURL=marketData.js.map
