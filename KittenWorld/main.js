/**
 * KittenWorld - Main JavaScript File
 * Handles core functionality, navigation, and global features across all pages
 */

class KittenWorld {
    constructor() {
        this.currentPage = this.getCurrentPage();
        this.mobileMenuOpen = false;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.handleNavigation();
        this.setupMobileMenu();
        this.setupSmoothScrolling();
        this.setupFormValidation();
        this.setupScrollAnimations();
        this.setupAccessibility();
        this.setupPerformanceOptimizations();
    }

    setupEventListeners() {
        document.addEventListener('DOMContentLoaded', () => {
            this.onDOMContentLoaded();
        });

        window.addEventListener('resize', this.debounce(() => {
            this.handleResize();
        }, 250));

        window.addEventListener('scroll', this.throttle(() => {
            this.handleScroll();
        }, 16));

        document.addEventListener('click', (e) => {
            this.handleGlobalClicks(e);
        });

        document.addEventListener('keydown', (e) => {
            this.handleKeyboardNavigation(e);
        });
    }

    onDOMContentLoaded() {
        this.updateActiveNavigation();
        this.initializePageSpecificFeatures();
        this.setupLazyLoading();
        this.showPageContent();
        console.log(`KittenWorld initialized on ${this.currentPage}`);
    }

    getCurrentPage() {
        const path = window.location.pathname;
        const page = path.split('/').pop() || 'index.html';
        return page.replace('.html', '') || 'index';
    }

    setupMobileMenu() {
        const mobileToggle = document.querySelector('.mobile-menu-toggle');
        const navMenu = document.querySelector('.nav-menu');
        
        if (!mobileToggle || !navMenu) return;

        mobileToggle.addEventListener('click', (e) => {
            e.preventDefault();
            this.toggleMobileMenu();
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', (e) => {
            if (this.mobileMenuOpen && !e.target.closest('.navbar')) {
                this.closeMobileMenu();
            }
        });
// Close mobile menu when clicking nav links
        navMenu.addEventListener('click', (e) => {
            if (e.target.classList.contains('nav-link')) {
                this.closeMobileMenu();
            }
        });
    }

    toggleMobileMenu() {
        const mobileToggle = document.querySelector('.mobile-menu-toggle');
        const navMenu = document.querySelector('.nav-menu');
        const body = document.body;

        this.mobileMenuOpen = !this.mobileMenuOpen;

        mobileToggle?.classList.toggle('active', this.mobileMenuOpen);
        navMenu?.classList.toggle('active', this.mobileMenuOpen);
        body.classList.toggle('menu-open', this.mobileMenuOpen);

        // Update ARIA attributes
        mobileToggle?.setAttribute('aria-expanded', this.mobileMenuOpen.toString());
    }

closeMobileMenu() {
        if (!this.mobileMenuOpen) return;
        this.toggleMobileMenu();
    }

    handleNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        
        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                // Allow default navigation behavior
                this.trackPageNavigation(link.getAttribute('href'));
            });
        });
    }
updateActiveNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        const currentPath = window.location.pathname;
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            
            const href = link.getAttribute('href');
            const isHomePage = currentPath.endsWith('index.html') || currentPath === '/';
            const isCurrentPage = href.includes(this.currentPage + '.html') || 
                                (isHomePage && href.includes('index.html'));
            
            if (isCurrentPage) {
                link.classList.add('active');
                link.setAttribute('aria-current', 'page');
            } else {
                link.removeAttribute('aria-current');
            }
        });
    }
setupSmoothScrolling() {
        const smoothScrollLinks = document.querySelectorAll('a[href^="#"]');
        
        smoothScrollLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                const targetId = link.getAttribute('href').substring(1);
                const targetElement = document.getElementById(targetId);
                
                if (targetElement) {
                    e.preventDefault();
                    this.smoothScrollTo(targetElement);
                }
            });
        });
    }

    smoothScrollTo(element, offset = 80) {
        const targetPosition = element.offsetTop - offset;
        
        window.scrollTo({
            top: targetPosition,
            behavior: 'smooth'
        });
    }
setupFormValidation() {
        const forms = document.querySelectorAll('form');
        
        forms.forEach(form => {
            form.addEventListener('submit', (e) => {
                if (!this.validateForm(form)) {
                    e.preventDefault();
                }
            });

            // Real-time validation
            const inputs = form.querySelectorAll('input, textarea, select');
            inputs.forEach(input => {
                input.addEventListener('blur', () => {
                    this.validateField(input);
                });
                
                input.addEventListener('input', () => {
                    this.clearFieldError(input);
                });
            });
        });
    }
validateForm(form) {
        const inputs = form.querySelectorAll('[required]');
        let isValid = true;
        
        inputs.forEach(input => {
            if (!this.validateField(input)) {
                isValid = false;
            }
        });
        
        return isValid;
    }
validateField(field) {
        const value = field.value.trim();
        const type = field.type;
        let isValid = true;
        let errorMessage = '';
        
        // Required field validation
        if (field.hasAttribute('required') && !value) {
            isValid = false;
            errorMessage = 'This field is required';
        }
        
        // Email validation
        else if (type === 'email' && value) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(value)) {
                isValid = false;
                errorMessage = 'Please enter a valid email address';
            }
        }
        
        // Phone validation
        else if (type === 'tel' && value) {
            const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/;
            if (!phoneRegex.test(value.replace(/[\s\-\(\)]/g, ''))) {
                isValid = false;
                errorMessage