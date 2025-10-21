// Utility functions for USDA Karate website

// Get URL parameters
function getUrlParameter(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}

// Format price with currency
function formatPrice(price) {
    if (isNaN(price) || price === null || price === undefined) {
        return '$0.00';
    }
    return '$' + parseFloat(price).toFixed(2);
}

// Debounce function to limit function calls
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Check if element is in viewport
function isInViewport(element) {
    const rect = element.getBoundingClientRect();
    return (
        rect.top >= 0 &&
        rect.left >= 0 &&
        rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
        rect.right <= (window.innerWidth || document.documentElement.clientWidth)
    );
}

// Smooth scroll to element
function scrollToElement(element) {
    if (element) {
        element.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }
}

// Add loading state to button
function setButtonLoading(button, isLoading) {
    if (isLoading) {
        button.disabled = true;
        button.dataset.originalText = button.textContent;
        button.textContent = 'Loading...';
        button.classList.add('loading');
    } else {
        button.disabled = false;
        button.textContent = button.dataset.originalText || button.textContent;
        button.classList.remove('loading');
    }
}

// Generate unique ID
function generateId() {
    return 'id-' + Math.random().toString(36).substr(2, 9);
}

// Validate email format
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

// Validate phone format
function isValidPhone(phone) {
    const phoneRegex = /^[\+]?[1-9][\d]{0,2}[\s]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}$/;
    return phoneRegex.test(phone.replace(/\s/g, ''));
}

// Sanitize HTML content
function sanitizeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// Throttle function
function throttle(func, limit) {
    let inThrottle;
    return function() {
        const args = arguments;
        const context = this;
        if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// Mobile detection
function isMobile() {
    return window.innerWidth <= 768;
}

// Get current page name
function getCurrentPage() {
    return window.location.pathname.split('/').pop().replace('.html', '') || 'index';
}

// Set active navigation item
function setActiveNavItem() {
    const currentPage = getCurrentPage();
    const navLinks = document.querySelectorAll('nav a');
    
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        const pageName = href ? href.replace('.html', '') : '';
        
        if (pageName.includes(currentPage) || 
            (currentPage === 'index' && (href === 'index.html' || href === '/'))) {
            link.classList.add('active');
            link.parentElement.classList.add('active');
        }
    });
}

// Cookie utilities
const CookieUtils = {
    set: function(name, value, days = 7) {
        const expires = new Date();
        expires.setTime(expires.getTime() + (days * 24 * 60 * 60 * 1000));
        document.cookie = `${name}=${value};expires=${expires.toUTCString()};path=/`;
    },
    
    get: function(name) {
        const nameEQ = name + '=';
        const ca = document.cookie.split(';');
        for(let i = 0; i < ca.length; i++) {
            let c = ca[i];
            while (c.charAt(0) === ' ') c = c.substring(1, c.length);
            if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
        }
        return null;
    },
    
    delete: function(name) {
        document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 UTC;path=/;`;
    }
};

// Export utilities for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        getUrlParameter,
        formatPrice,
        debounce,
        isInViewport,
        scrollToElement,
        setButtonLoading,
        generateId,
        isValidEmail,
        isValidPhone,
        sanitizeHtml,
        throttle,
        isMobile,
        getCurrentPage,
        setActiveNavItem,
        CookieUtils
    };
}