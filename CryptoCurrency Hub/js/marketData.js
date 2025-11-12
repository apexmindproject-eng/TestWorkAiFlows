// marketData.js - Handles cryptocurrency market data fetching, dynamic table population, sorting, filtering, caching, and user preferences
// Script covers the market data section across the whole site, though market data table is present only on market.html

(() => {
  'use strict';

  // Configuration and constants
  const API_URL = 'https://api.coingecko.com/api/v3/coins/markets';
  const CURRENCY = 'usd';
  const CACHE_KEY = 'cryptocurrency_market_data_cache';
  const CACHE_EXPIRY = 5 * 60 * 1000; // 5 minutes

  // DOM elements cache
  let marketTableBody = null;
  let marketTable = null;
  let sortState = { column: 'market_cap', order: 'desc' };
  let marketData = [];
// DOM elements cache
  let marketTableBody = null;
  let marketTable = null;
  let sortState = { column: 'market_cap', order: 'desc' };
  let marketData = [];

  // Utility: format large numbers with commas and abbreviate
  const formatNumber = (num) => {
    if (num === null || num === undefined || isNaN(num)) return '-';
    if (num >= 1e12) return (num / 1e12).toFixed(2) + 'T';
    if (num >= 1e9) return (num / 1e9).toFixed(2) + 'B';
    if (num >= 1e6) return (num / 1e6).toFixed(2) + 'M';
    if (num >= 1e3) return (num / 1e3).toFixed(2) + 'K';
    return num.toLocaleString();
  };

  // Utility: format price to 2-6 decimals depending on value
  const formatPrice = (price) => {
    if (price === null || price === undefined || isNaN(price)) return '-';
    if (price >= 1) return '$' + price.toFixed(2);
    return '$' + price.toFixed(6);
  };
// Utility: format 24h change percent with color
  const formatChange = (change) => {
    if (change === null || change === undefined || isNaN(change)) return '-';
    const formatted = change.toFixed(2) + '%';
    if (change > 0) return `<span class="positive-change">+${formatted}</span>`;
    if (change < 0) return `<span class="negative-change">${formatted}</span>`;
    return formatted;
  };

  // Save market data to localStorage cache
  const saveCache = (data) => {
    try {
      const cacheData = {
        timestamp: Date.now(),
        data
      };
      localStorage.setItem(CACHE_KEY, JSON.stringify(cacheData));
    } catch (error) {
      console.warn('Unable to save market data cache:', error);
    }
  };
// Retrieve market data from localStorage cache if fresh
  const getCache = () => {
    try {
      const raw = localStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!parsed.timestamp || !parsed.data) return null;
      if ((Date.now() - parsed.timestamp) > CACHE_EXPIRY) return null;
      return parsed.data;
    } catch (error) {
      console.warn('Unable to read market data cache:', error);
      return null;
    }
  };

  // Fetch market data from API
  const fetchMarketData = async () => {
    const params = new URLSearchParams({
      vs_currency: CURRENCY,
      order: 'market_cap_desc',
      per_page: '50',
      page: '1',
      price_change_percentage: '24h'
    });
try {
      const response = await fetch(`${API_URL}?${params.toString()}`);
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching market data:', error);
      return null;
    }
  };

  // Build table row for a single coin
  const buildTableRow = (coin) => {
    try {
      if (!coin) return null;

      const tr = document.createElement('tr');
      tr.className = 'market-row';
      tr.setAttribute('data-id', coin.id);

      // Name with icon and link to official homepage or coingecko page
      const nameTd = document.createElement('td');
      nameTd.className = 'coin-name-col';
      const img = document.createElement('img');
      img.src = coin.image || '';
      img.alt = `${coin.name} logo`;
      img.className = 'coin-icon';
      nameTd.appendChild(img);
const nameLink = document.createElement('a');
      nameLink.href = `https://www.coingecko.com/en/coins/${coin.id}`;
      nameLink.target = '_blank';
      nameLink.rel = 'noopener noreferrer';
      nameLink.textContent = `${coin.name} (${coin.symbol.toUpperCase()})`;
      nameLink.className = 'coin-link';

      nameTd.appendChild(nameLink);
      tr.appendChild(nameTd);

      // Price
      const priceTd = document.createElement('td');
      priceTd.className = 'coin-price-col';
      priceTd.innerHTML = formatPrice(coin.current_price);
      tr.appendChild(priceTd);

      // 24h Change
      const changeTd = document.createElement('td');
      changeTd.className = 'coin-change-col';
      changeTd.innerHTML = formatChange(coin.price_change_percentage_24h);
      tr.appendChild(changeTd);
// Market Cap
      const capTd = document.createElement('td');
      capTd.className = 'coin-cap-col';
      capTd.textContent = formatNumber(coin.market_cap);
      tr.appendChild(capTd);

      return tr;
    } catch (error) {
      console.error('Error building table row:', error);
      return null;
    }
  };

  // Clear existing table rows
  const clearTableRows = () => {
    if (!marketTableBody) return;
    while (marketTableBody.firstChild) {
      marketTableBody.removeChild(marketTableBody.firstChild);
    }
  };

  // Render the whole market table with current marketData array
  const renderTable = () => {
    try {
      if (!marketTableBody) return;
      clearTableRows();
      marketData.forEach(coin => {
        const tr = buildTableRow(coin);
        if (tr) marketTableBody.appendChild(tr);
      });
    } catch (error) {
      console.error('Error rendering market table:', error);
    }
  };
// Sort market data array by column
  const sortMarketData = (column, order) => {
    try {
      const sortKeyMap = {
        'name': coin => coin.name.toLowerCase(),
        'price': coin => coin.current_price || 0,
        'change': coin => coin.price_change_percentage_24h || 0,
        'market_cap': coin => coin.market_cap || 0
      };

      const keyFn = sortKeyMap[column];
      if (!keyFn) return;

      marketData.sort((a, b) => {
        const valA = keyFn(a);
        const valB = keyFn(b);

        if (typeof valA === 'string') {
          return order === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
        } else {
          return order === 'asc' ? valA - valB : valB - valA;
        }
      });
    } catch (error) {
      console.error('Error sorting market data:', error);
    }
  };
// Update table headers sort visual and attributes
  const updateSortIndicators = () => {
    try {
      if (!marketTable) return;
      const headers = marketTable.querySelectorAll('th.sortable');
      headers.forEach(th => {
        th.classList.remove('sort-asc', 'sort-desc');
        if (th.dataset.column === sortState.column) {
          th.classList.add(sortState.order === 'asc' ? 'sort-asc' : 'sort-desc');
          th.setAttribute('aria-sort', sortState.order === 'asc' ? 'ascending' : 'descending');
        } else {
          th.setAttribute('aria-sort', 'none');
        }
      });
    } catch (error) {
      console.error('Error updating sort indicators:', error);
    }
  };

  // Handle header click to sort
  const handleHeaderClick = (event) => {
    try {
      const th = event.target.closest('th.sortable');
      if (!th) return;

      const column = th.dataset.column;
      if (!column) return;
const column = th.dataset.column;
      if (!column) return;

      // Toggle order or default to descending
      if (sortState.column === column) {
        sortState.order = sortState.order === 'asc' ? 'desc' : 'asc';
      } else {
        sortState.column = column;
        sortState.order = 'desc';
      }

      sortMarketData(sortState.column, sortState.order);
      renderTable();
      updateSortIndicators();

    } catch (error) {
      console.error('Error in header click for sorting:', error);
    }
  };

  // Initialize sorting listeners
  const initSorting = () => {
    try {
      if (!marketTable) return;

      const headers = marketTable.querySelectorAll('th.sortable');
      headers.forEach(th => {
        th.style.cursor = 'pointer';
      });

      marketTable.querySelector('thead').addEventListener('click', handleHeaderClick);
    } catch (error) {
      console.error('Error initializing sorting:', error);
    }
  };
marketTable.querySelector('thead').addEventListener('click', handleHeaderClick);
    } catch (error) {
      console.error('Error initializing sorting:', error);
    }
  };

  // Main initialization function
  const init = async () => {
    try {
      marketTable = document.getElementById('crypto-market-table');
      if (!marketTable) return; // Market table not found, skip

      marketTableBody = marketTable.querySelector('tbody');
      if (!marketTableBody) return;

      // Try loading from cache
      let cached = getCache();
      if (cached && Array.isArray(cached) && cached.length > 0) {
        marketData = cached;
      } else {
        // Fetch fresh data
        const data = await fetchMarketData();
        if (data && Array.isArray(data)) {
          marketData = data;
          saveCache(marketData);
        } else {
          console.warn('No market data fetched.');
          marketData = [];
        }
      }
sortMarketData(sortState.column, sortState.order);
      renderTable();
      updateSortIndicators();
      initSorting();

      // Setup periodic refresh every 5 minutes
      setInterval(async () => {
        try {
          const freshData = await fetchMarketData();
          if (freshData && Array.isArray(freshData)) {
            marketData = freshData;
            saveCache(marketData);
            sortMarketData(sortState.column, sortState.order);
            renderTable();
            updateSortIndicators();
          }
        } catch (error) {
          console.error('Error refreshing market data:', error);
        }
      }, CACHE_EXPIRY);
    } catch (error) {
      console.error('Error initializing marketData.js:', error);
    }
  };

  document.addEventListener('DOMContentLoaded', init);
})();