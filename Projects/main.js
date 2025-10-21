// Main JavaScript functionality for USDA Karate website

// DOM Content Loaded - Initialize all functionality
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    initializeMobileMenu();
    initializeScrollEffects();
    initializeImageLoading();
    console.log('USDA Karate website initialized');
});

// Navigation functionality
function initializeNavigation() {
    const navLinks = document.querySelectorAll('.nav-menu a');
    const currentPage = window.location.pathname.split('/').pop();
    
    // Set active navigation link
    navLinks.forEach(link => {
        const href = link.getAttribute('href');
        if (href === currentPage || (currentPage === '' && href === 'index.html')) {
            link.classList.add('active');
        } else {
            link.classList.remove('active');
        }
    });
}

// Mobile hamburger menu functionality
function initializeMobileMenu() {
    const hamburger = document.querySelector('.hamburger');
    const navToggle = document.querySelector('.nav-toggle');
    const navMenu = document.querySelector('.nav-menu');
    
    // Handle different hamburger selectors across pages
    const mobileToggle = hamburger || navToggle;
    
    if (mobileToggle && navMenu) {
        mobileToggle.addEventListener('click', function() {
            mobileToggle.classList.toggle('active');
            navMenu.classList.toggle('active');
            
            // Toggle aria-expanded for accessibility
            const isExpanded = navMenu.classList.contains('active');
            mobileToggle.setAttribute('aria-expanded', isExpanded);
        });
        
        // Close mobile menu when clicking on nav links
        const navLinks = navMenu.querySelectorAll('a');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                mobileToggle.classList.remove('active');
                navMenu.classList.remove('active');
                mobileToggle.setAttribute('aria-expanded', 'false');
            });
        });
        
        // Close mobile menu when clicking outside
        document.addEventListener('click', function(event) {
            if (!mobileToggle.contains(event.target) && !navMenu.contains(event.target)) {
                mobileToggle.classList.remove('active');
                navMenu.classList.remove('active');
                mobileToggle.setAttribute('aria-expanded', 'false');
            }
        });
    }
}

// Smooth scroll effects for internal links
function initializeScrollEffects() {
    const smoothScrollLinks = document.querySelectorAll('a[href^="#"]');
    
    smoothScrollLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

// Image loading optimization
function initializeImageLoading() {
    const images = document.querySelectorAll('img');
    
    images.forEach(img => {
        // Add loading class initially
        img.classList.add('loading');
        
        // Remove loading class when image loads
        img.addEventListener('load', function() {
            this.classList.remove('loading');
            this.classList.add('loaded');
        });
        
        // Handle image load errors
        img.addEventListener('error', function() {
            this.classList.remove('loading');
            this.classList.add('error');
            console.warn('Failed to load image:', this.src);
        });
    });
}

// Utility function to handle URL parameters
function getUrlParameter(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}

// Form validation helper
function validateForm(formElement) {
    const requiredFields = formElement.querySelectorAll('[required]');
    let isValid = true;
    
    requiredFields.forEach(field => {
        if (!field.value.trim()) {
            field.classList.add('error');
            isValid = false;
        } else {
            field.classList.remove('error');
        }
    });
    
    return isValid;
}

// Generic event handler for CTA buttons
function initializeCTAButtons() {
    const ctaButtons = document.querySelectorAll('.cta-button, .learn-more');
    
    ctaButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            // Add click animation
            this.classList.add('clicked');
            setTimeout(() => {
                this.classList.remove('clicked');
            }, 200);
        });
    });
}

// Initialize CTA buttons when DOM is ready
document.addEventListener('DOMContentLoaded', initializeCTAButtons);

// Handle category filtering from URL parameters (for catalog page)
if (window.location.pathname.includes('catalog.html')) {
    document.addEventListener('DOMContentLoaded', function() {
        const category = getUrlParameter('category');
        if (category) {
            const categoryFilter = document.getElementById('category-filter');
            if (categoryFilter) {
                categoryFilter.value = category;
                // Trigger filter event if catalog filtering is available
                if (typeof filterProducts === 'function') {
                    filterProducts();
                }
            }
        }
    });
}