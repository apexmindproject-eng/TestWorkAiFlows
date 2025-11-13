// listingFilter.js - Handles filtering functionality on listings.html page specifically
// Provides dynamic filtering UI, accessibility, and performance improvements

'use strict';

(() => {
  // Cache elements
  const filterForm = document.getElementById('filter-form');
  const listingsContainer = document.getElementById('listings-container');

  // Mock data: In a real project, this data may come from server or JSON file
  // Here we derive listings from DOM at page load or assume a collection exists
  // For demonstration, assume listings container has children .listing-item elements with data attributes

  // Selector for individual listing items
  const listingSelector = '.listing-item';

  // Utility debounce
  const debounce = (func, wait, immediate = false) => {
    let timeout;
    return function(...args) {
      const context = this;
      const later = () => {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      const callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  };

  // Parse filter criteria from form inputs
  const getFilters = () => {
    if (!filterForm) return null;
    const filters = {
      sizes: new Set(), // e.g. 'small', 'medium', 'large'
      price: [] // store price range strings or min/max number
    };

    try {
      // Sizes - checkboxes
      filterForm.querySelectorAll('input[name="size"]:checked').forEach(input => {
        filters.sizes.add(input.value.toLowerCase());
      });

      // Price range - assuming radio buttons or checkboxes with name="price"
      // Extract minimum and maximum price or range id
      filterForm.querySelectorAll('input[name="price"]:checked').forEach(input => {
        filters.price.push(input.value.toLowerCase());
      });
    } catch (error) {
      console.error('Error reading filter inputs:', error);
    }

    return filters;
  };

  // Filtering logic based on listing data attributes
  // Each listing item is expected to have data-size and data-price attributes
  const filterListings = () => {
    if (!listingsContainer) return;

    const filters = getFilters();
    if (!filters) return;

    // Gather all listing elements
    const listings = listingsContainer.querySelectorAll(listingSelector);

    listings.forEach(listing => {
      try {
        const size = listing.getAttribute('data-size') ? listing.getAttribute('data-size').toLowerCase() : '';
        const priceStr = listing.getAttribute('data-price') || '';
        // Convert price to number for range comparison
        const priceNum = parseFloat(priceStr.replace(/[^0-9.]/g, '')) || 0;

        // Check size filter
        let sizePass = true;
        if (filters.sizes.size > 0) {
          sizePass = filters.sizes.has(size);
        }

        // Check price filter
        let pricePass = true;
        if (filters.price.length > 0) {
          pricePass = filters.price.some(range => {
            // Expected price filter values: e.g., "low", "medium", "high"
            // Define ranges:
            // low: < 1000
            // medium: 1000-2000
            // high: > 2000
            switch(range) {
              case 'low':
                return priceNum < 1000;
              case 'medium':
                return priceNum >= 1000 && priceNum <= 2000;
              case 'high':
                return priceNum > 2000;
              default:
                return true;
            }
          });
        }
// Display if passes all filters
        if (sizePass && pricePass) {
          listing.style.display = '';
          listing.setAttribute('aria-hidden', 'false');
        } else {
          listing.style.display = 'none';
          listing.setAttribute('aria-hidden', 'true');
        }
      } catch (error) {
        console.error('Error filtering listing element:', listing, error);
      }
    });

    updateResultsCount();
  };

  // Update count of displayed listings for user feedback
  const updateResultsCount = () => {
    try {
      const listings = listingsContainer ? listingsContainer.querySelectorAll(listingSelector) : [];
      const visibleCount = Array.from(listings).filter(el => el.style.display !== 'none').length;
      let resultsCounter = document.getElementById('results-count');
      if (!resultsCounter) {
        // Create results count display
        resultsCounter = document.createElement('p');
        resultsCounter.id = 'results-count';
        resultsCounter.className = 'results-count';

        if (listingsContainer) {
          listingsContainer.parentNode.insertBefore(resultsCounter, listingsContainer);
        }
      }

      resultsCounter.textContent = `${visibleCount} office apartment${visibleCount !== 1 ? 's' : ''} found.`;

      // Accessibility: Announce changes dynamically
      resultsCounter.setAttribute('aria-live', 'polite');

    } catch (error) {
      console.error('Error updating results count:', error);
    }
  };

  // Reset filters to default (all listings shown)
  const resetFilters = () => {
    try {
      if (!filterForm) return;

      // Reset form inputs
      filterForm.reset();

      // Trigger filtering to show all
      filterListings();
    } catch (error) {
      console.error('Error resetting filters:', error);
    }
  };

  // Initialize the filter UI
  const initFilters = () => {
    try {
      if (!filterForm) return;

      // Attach change event with debounce
      filterForm.addEventListener('change', debounce(() => {
        filterListings();
      }, 250));

      // Create Reset button if not present
      if (!document.getElementById('filter-reset-btn')) {
        const resetBtn = document.createElement('button');
        resetBtn.type = 'button';
        resetBtn.id = 'filter-reset-btn';
        resetBtn.className = 'btn btn-secondary filter-reset-btn';
        resetBtn.textContent = 'Reset Filters';

        filterForm.appendChild(resetBtn);

        resetBtn.addEventListener('click', () => {
          resetFilters();
          // Focus first filter input after reset
          const firstInput = filterForm.querySelector('input[name="size"]');
          if (firstInput) firstInput.focus();
        });
      }

      // Initial filtering (in case default filters are set)
      filterListings();

    } catch (error) {
      console.error('Error initializing filters:', error);
    }
  };

  // Accessibility: Keyboard support enhancements for filter form inputs
  const enhanceFilterAccessibility = () => {
    try {
      if (!filterForm) return;

      // Add focus styles for keyboard users
      filterForm.addEventListener('keydown', event => {
        const target = event.target;
        if(!target.matches('input[type="checkbox"], input[type="radio"]')) return;

        if(event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault();
          const inputs = Array.from(filterForm.querySelectorAll('input[name="'+ target.name+ '"]'));
          let idx = inputs.indexOf(target);
if (event.key === 'ArrowDown') {
            idx = (idx + 1) % inputs.length;
          } else if (event.key === 'ArrowUp') {
            idx = (idx - 1 + inputs.length) % inputs.length;
          }

          inputs[idx].focus();
        }
      });
    } catch (error) {
      console.error('Error enhancing filter accessibility:', error);
    }
  };

  // Initialize module on DOM ready
  const init = () => {
    try {
      if (!filterForm || !listingsContainer) {
        // Not on listings.html page, safely abort
        return;
      }

      initFilters();
      enhanceFilterAccessibility();

    } catch (error) {
      console.error('Error initializing listingFilter module:', error);
    }
  };

  // Event listener to run on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', init);

})();

//# sourceURL=listingFilter.js