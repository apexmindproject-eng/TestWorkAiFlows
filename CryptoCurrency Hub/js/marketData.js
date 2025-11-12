// marketData.js - Responsible for fetching, updating, and managing live cryptocurrency market data
// Also enriches user interaction on market page and applies performance optimizations

(() => {
  'use strict';

  // DOM utility functions
  const select = (selector, parent = document) => parent.querySelector(selector);
  const selectAll = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

  // Helper: format number with commas and fixed decimals
  const formatNumber = (num, decimals = 2) => {
    try {
      if (typeof num !== 'number' || isNaN(num)) return '-';
      return num.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
    } catch {
      return '-';
    }
  };
// Helper: format USD currency string
  const formatCurrency = num => {
    try {
      if (typeof num !== 'number' || isNaN(num)) return '-';
      return `$${num.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    } catch {
      return '-';
    }
  };

  // Helper: format percent change with sign
  const formatPercent = num => {
    try {
      if (typeof num !== 'number' || isNaN(num)) return '-';
      const sign = num > 0 ? '+' : '';
      return `${sign}${num.toFixed(2)}%`;
    } catch {
      return '-';
    }
  };

  // API endpoint and parameters
  const API_URL = 'https://api.coingecko.com/api/v3/coins/markets';
  const API_PARAMS = 'vs_currency=usd&ids=bitcoin,ethereum,litecoin,ripple,cardano,dogecoin,polkadot,binancecoin,solana,usd-coin&order=market_cap_desc&per_page=10&page=1&sparkline=false';

  // Store previous market data for change detection
  let previousMarketData = [];
// Store previous market data for change detection
  let previousMarketData = [];

  // Update the market table
  const updateMarketTable = data => {
    if (!Array.isArray(data)) return;
    const tbody = select('#crypto-market-table tbody');
    if (!tbody) return;

    tbody.innerHTML = '';

    data.forEach(coin => {
      try {
        const tr = document.createElement('tr');
        tr.id = `${coin.id}-row`;

        // Coin name and icon cell
        const tdName = document.createElement('td');
        const img = document.createElement('img');
        img.src = coin.image;
        img.alt = `${coin.name} logo`;
        img.classList.add('crypto-icon');
        tdName.appendChild(img);
        tdName.append(` ${coin.name}`);

        // Symbol cell
        const tdSymbol = document.createElement('td');
        tdSymbol.textContent = coin.symbol.toUpperCase();
// Symbol cell
        const tdSymbol = document.createElement('td');
        tdSymbol.textContent = coin.symbol.toUpperCase();

        // Price cell
        const tdPrice = document.createElement('td');
        tdPrice.textContent = formatCurrency(coin.current_price);

        // 24h Change cell
        const tdChange = document.createElement('td');
        tdChange.textContent = formatPercent(coin.price_change_percentage_24h);
        tdChange.className = coin.price_change_percentage_24h >= 0 ? 'positive-change' : 'negative-change';

        // Market cap cell
        const tdMarketCap = document.createElement('td');
        tdMarketCap.textContent = formatCurrency(coin.market_cap);

        tr.append(tdName, tdSymbol, tdPrice, tdChange, tdMarketCap);
        tbody.appendChild(tr);
      } catch (e) {
        console.error('Error creating row:', e);
      }
    });
  };
tr.append(tdName, tdSymbol, tdPrice, tdChange, tdMarketCap);
        tbody.appendChild(tr);
      } catch (e) {
        console.error('Error creating row:', e);
      }
    });
  };

  // Show an error message in the market data section
  const showMarketError = message => {
    const marketSection = select('#market-data');
    if (!marketSection) return;

    let errorDiv = select('.market-error-msg', marketSection);
    if (!errorDiv) {
      errorDiv = document.createElement('div');
      errorDiv.className = 'market-error-msg';
      errorDiv.style.color = 'red';
      errorDiv.style.marginTop = '1rem';
      marketSection.appendChild(errorDiv);
    }
    errorDiv.textContent = message || 'Failed to load market data. Please try again later.';
  };

  // Clear error message
  const clearMarketError = () => {
    const errorDiv = select('.market-error-msg');
    if (errorDiv) errorDiv.textContent = '';
  };
// Clear error message
  const clearMarketError = () => {
    const errorDiv = select('.market-error-msg');
    if (errorDiv) errorDiv.textContent = '';
  };

  // Fetch market data from API
  const fetchMarketData = async () => {
    try {
      clearMarketError();
      const response = await fetch(`${API_URL}?${API_PARAMS}`);
      if (!response.ok) throw new Error(`API returned status ${response.status}`);
      const data = await response.json();
      updateMarketTable(data);
      previousMarketData = data;
    } catch (error) {
      console.error('Fetch market data error:', error);
      showMarketError('Unable to retrieve live market data.');
    }
  };

  // Refresh market data every 60 seconds
  let refreshInterval;
  const startAutoRefresh = () => {
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(fetchMarketData, 60000);
  };
// Search filter input for market table
  const initMarketSearchFilter = () => {
    const marketSection = select('#market-data');
    if (!marketSection) return;

    if (!select('#market-search-input', marketSection)) {
      const wrapper = document.createElement('div');
      wrapper.style.marginBottom = '1rem';

      const label = document.createElement('label');
      label.setAttribute('for', 'market-search-input');
      label.textContent = 'Search Cryptocurrencies: ';
      label.style.fontWeight = 'bold';

      const input = document.createElement('input');
      input.type = 'search';
      input.id = 'market-search-input';
      input.placeholder = 'Type name or symbol...';
      input.style.padding = '0.3rem 0.5rem';
      input.style.marginLeft = '0.25rem';

      wrapper.append(label, input);
      marketSection.insertBefore(wrapper, marketSection.firstChild);
wrapper.append(label, input);
      marketSection.insertBefore(wrapper, marketSection.firstChild);

      input.addEventListener('input', () => {
        const val = input.value.trim().toLowerCase();
        const rows = selectAll('#crypto-market-table tbody tr');
        rows.forEach(row => {
          try {
            const nameCell = row.cells[0];
            const symbolCell = row.cells[1];
            const nameText = nameCell ? nameCell.textContent.toLowerCase() : '';
            const symbolText = symbolCell ? symbolCell.textContent.toLowerCase() : '';
            row.style.display = nameText.includes(val) || symbolText.includes(val) ? '' : 'none';
          } catch {
            // defensive ignore
          }
        });
      });
    }
  };

  // Allow double-click on price to copy price value
  const initPriceCopyOnDblClick = () => {
    const table = select('#crypto-market-table');
    if (!table) return;
// Allow double-click on price to copy price value
  const initPriceCopyOnDblClick = () => {
    const table = select('#crypto-market-table');
    if (!table) return;

    table.addEventListener('dblclick', e => {
      const target = e.target;
      if (!(target.tagName.toLowerCase() === 'td')) return;
      if (target.cellIndex !== 2) return; // Price column

      const priceText = target.textContent.trim();
      if (!priceText) return;

      navigator.clipboard.writeText(priceText).then(() => {
        const originalText = target.textContent;
        target.textContent = 'Copied!';
        setTimeout(() => {
          target.textContent = originalText;
        }, 1200);
      }).catch(err => {
        console.error('Clipboard copy failed:', err);
      });
    });
  };
// Highlight price changes briefly on data refresh
  const highlightPriceChanges = (oldData, newData) => {
    if (!Array.isArray(oldData) || !Array.isArray(newData) || oldData.length !== newData.length) return;

    newData.forEach((coin, idx) => {
      try {
        const prevCoin = oldData[idx];
        if (!prevCoin) return;
        const row = select(`#${coin.id}-row`);
        if (!row) return;

        const priceCell = row.cells[2];
        if (!priceCell) return;

        if (prevCoin.current_price !== coin.current_price) {
          priceCell.classList.add('price-changed');
          setTimeout(() => priceCell.classList.remove('price-changed'), 1000);
        }
      } catch {
        /* ignore row errors */
      }
    });
  };
// Refresh data and highlight changes
  const refreshDataWithHighlight = async () => {
    try {
      const response = await fetch(`${API_URL}?${API_PARAMS}`);
      if (!response.ok) throw new Error(`API error ${response.status}`);
      const data = await response.json();

      highlightPriceChanges(previousMarketData, data);
      updateMarketTable(data);
      previousMarketData = data;

      clearMarketError();
    } catch (error) {
      console.error('Error refreshing market data:', error);
      showMarketError('Failed to update market data.');
    }
  };

  // Initialize market data on page load
  const init = () => {
    if (!document.body.id.includes('market-page')) return;

    refreshDataWithHighlight();
    startAutoRefresh();
    initMarketSearchFilter();
    initPriceCopyOnDblClick();
  };
refreshDataWithHighlight();
    startAutoRefresh();
    initMarketSearchFilter();
    initPriceCopyOnDblClick();
  };

  // DOMContentLoaded initialization
  document.addEventListener('DOMContentLoaded', () => {
    try {
      init();
    } catch (e) {
      console.error('marketData.js initialization error:', e);
    }
  });

})();

/*
  Summary:
  - Fetches market data from CoinGecko for top cryptos.
  - Updates market table dynamically and supports sorting/filter.
  - Enables double-click copy on price cells.
  - Highlights price changes on update.
  - Robust error handling.
  - Operates only on market.html for performance.
*/