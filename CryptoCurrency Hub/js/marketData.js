// marketData.js - Handles fetching and dynamic display of cryptocurrency market data for CryptoCurrency Hub

// Use IIFE module pattern to keep scope contained
(() => {
  'use strict';

  /**
   * API Endpoints and Configurations
   *
   * For demonstration, using CoinGecko public API:
   * https://www.coingecko.com/en/api
   * No API key required but limits apply.
   */
  const API_BASE = 'https://api.coingecko.com/api/v3';
  const MARKETS_ENDPOINT = '/coins/markets'; // to fetch market data

   * DOM Selectors
  const selectors = {
    marketList: '#market-trends .market-list'
  };

   * Helper: Select element or null (defensive)
  const select = (selector, all = false) => {
    try {
      return all ? Array.from(document.querySelectorAll(selector)) : document.querySelector(selector);
    } catch (e) {
      console.error(`Selector error for '${selector}':`, e);
      return null;
    }
   * Fetch market data from API
   * @param {string} vsCurrency  - currency symbol like 'usd'
   * @param {number} perPage - number of coins per page
   * @param {number} page - page number
   * @returns {Promise<Array>} 
  const fetchMarketData = async (vsCurrency = 'usd', perPage = 10, page = 1) => {
      const url = new URL(API_BASE + MARKETS_ENDPOINT);
      url.searchParams.append('vs_currency', vsCurrency);
      url.searchParams.append('order', 'market_cap_desc');
      url.searchParams.append('per_page', perPage);
      url.searchParams.append('page', page);
      url.searchParams.append('sparkline', 'false');
const response = await fetch(url.toString(), { cache: 'no-cache' });
      if (!response.ok) {
        throw new Error(`Network response was not ok: ${response.status} ${response.statusText}`);
      const data = await response.json();
      if (!Array.isArray(data)) {
        throw new Error('Unexpected API response format, expected an array.');
      return data;
    } catch (error) {
      console.error('Failed to fetch market data:', error);
      return [];

   * Format numbers with commas and decimals
   * @param {number} num
   * @param {number} decimals
  const formatNumber = (num, decimals = 2) => {
      if (typeof num !== 'number' || isNaN(num)) return '-';
      return num.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
      console.error('Error formatting number:', e);
      return num;
   * Create a single market item element from coin data
   * @param {Object} coin
   * @returns {HTMLLIElement}
  const createMarketItem = (coin) => {
      const li = document.createElement('li');
      li.classList.add('market-item');
      li.setAttribute('data-coin-id', coin.id);

      // Image
      const img = document.createElement('img');
      img.src = coin.image || '';
      img.alt = `${coin.name} Icon`;
      img.className = 'crypto-icon';
      img.loading = 'lazy';
      li.appendChild(img);

      // Info container
      const infoDiv = document.createElement('div');
      infoDiv.className = 'market-info';

      // Name and Symbol
      const nameHeading = document.createElement('h3');
      nameHeading.textContent = `${coin.name} (${coin.symbol.toUpperCase()})`;
      nameHeading.classList.add('crypto-name');
      infoDiv.appendChild(nameHeading);
// Current Price
      const pricePara = document.createElement('p');
      pricePara.textContent = `Price: $${formatNumber(coin.current_price)}`;
      pricePara.classList.add('crypto-price');
      infoDiv.appendChild(pricePara);

      // Price Change 24h
      const changePara = document.createElement('p');
      const change = coin.price_change_percentage_24h;
      changePara.textContent = `24h Change: ${formatNumber(change)}%`;
      changePara.classList.add('crypto-change');
      changePara.style.color = change >= 0 ? 'var(--color-positive, green)' : 'var(--color-negative, red)';
      infoDiv.appendChild(changePara);

      // Market Cap
      const marketCapPara = document.createElement('p');
      marketCapPara.textContent = `Market Cap: $${formatNumber(coin.market_cap, 0)}`;
      marketCapPara.classList.add('crypto-marketcap');
      infoDiv.appendChild(marketCapPara);

      li.appendChild(infoDiv);

      return li;
      console.error('Error creating market item element:', error);

   * Render the market list with coin data
   * @param {Array} coins
  const renderMarketList = (coins) => {
    const marketListEl = select(selectors.marketList);
    if (!marketListEl) {
      console.warn('Market list element not found in DOM');
      return;

    // Clear current list (defensive)
    marketListEl.innerHTML = '';

    if (!coins.length) {
      const noDataMsg = document.createElement('p');
      noDataMsg.textContent = 'No market data available at the moment.';
      noDataMsg.classList.add('no-data-msg');
      marketListEl.appendChild(noDataMsg);

    const fragment = document.createDocumentFragment();
    for (const coin of coins) {
      const item = createMarketItem(coin);
      if (item) fragment.appendChild(item);

    marketListEl.appendChild(fragment);

   * Pagination controls
   * @param {number} currentPage
   * @param {function} onPageChange
  const setupPagination = (currentPage, onPageChange) => {
    const containerId = 'market-pagination';
    // If pagination container exists, remove it first
    const existing = select(`#${containerId}`);
    if (existing) existing.remove();

    const container = document.createElement('div');
    container.id = containerId;
    container.classList.add('pagination-container');

    const prevBtn = document.createElement('button');
    prevBtn.textContent = 'Previous';
    prevBtn.disabled = currentPage === 1;
    prevBtn.classList.add('pagination-btn');

    const nextBtn = document.createElement('button');
    nextBtn.textContent = 'Next';
    nextBtn.classList.add('pagination-btn');

    container.appendChild(prevBtn);
    container.appendChild(document.createTextNode(`Page ${currentPage}`));
    container.appendChild(nextBtn);

    prevBtn.addEventListener('click', () => {
      if (currentPage > 1) onPageChange(currentPage - 1);
    });

    // Next button is always enabled since API supports pagination
    nextBtn.addEventListener('click', () => {
      onPageChange(currentPage + 1);

    // Insert container after the market list
    if (marketListEl) {
      marketListEl.parentNode.insertBefore(container, marketListEl.nextSibling);
   * Loading indicator management
  const showLoading = () => {
    let loader = select('#market-loading');
    if (!loader) {
      loader = document.createElement('div');
      loader.id = 'market-loading';
      loader.className = 'loading-indicator';
      loader.textContent = 'Loading market data...';
      const container = select('#market-trends');
      if (container) {
        container.appendChild(loader);
    loader.style.display = 'block';

  const hideLoading = () => {
    const loader = select('#market-loading');
    if (loader) loader.style.display = 'none';

   * Error message display
   * @param {string} msg
  const showError = (msg) => {
    if (!container) return;

    let errorEl = select('#market-error-msg');
    if (!errorEl) {
      errorEl = document.createElement('div');
      errorEl.id = 'market-error-msg';
      errorEl.classList.add('error-message');
      container.appendChild(errorEl);
    errorEl.textContent = msg;
    errorEl.style.display = 'block';

  const hideError = () => {
    const errorEl = select('#market-error-msg');
    if (errorEl) {
      errorEl.style.display = 'none';
      errorEl.textContent = '';

   * Main function to load and display market data
   * @param {number} page
  const loadMarketData = async (page = 1) => {
      hideError();
      showLoading();
      const coins = await fetchMarketData('usd', 10, page);
      hideLoading();
      renderMarketList(coins);
      setupPagination(page, loadMarketData);
      showError('Error loading market data. Please try again later.');
      console.error('Error in loadMarketData:', error);

   * Initialization function on DOM ready
  const init = () => {
    // Only initialize market data on pages with market section
    if (!marketListEl) return;

    loadMarketData(1);

  document.addEventListener('DOMContentLoaded', init);

})();

/*
  Notes:
  - Uses CoinGecko public API to load cryptocurrency market data dynamically.
  - Includes pagination controls.
  - Defensive code and error handling.
  - Loading indicator and error messaging for UX.
  - Designed to be maintainable and extensible.
  - Lazy loads images for performance.