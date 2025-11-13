/**
 * KittenWorld - Carousel JavaScript File
 * Handles all carousel, slider, and rotating content functionality across all pages
 */

class KittenCarousel {
    constructor() {
        this.carousels = new Map();
        this.autoPlayIntervals = new Map();
        this.touchStartX = 0;
        this.touchEndX = 0;
        this.isDragging = false;
        this.dragThreshold = 50;
        this.autoPlayDelay = 4000;
        this.transitionDuration = 300;
        this.prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        this.init();
    }
init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupHeroCarousels();
            this.setupTestimonialCarousels();
            this.setupFeatureCarousels();
            this.setupAdoptionCarousels();
            this.setupTipCarousels();
            this.setupImageSliders();
            this.setupKeyboardNavigation();
            this.setupTouchGestures();
            this.setupIntersectionObserver();
            this.setupAutoPlay();
            console.log('KittenCarousel initialized');
        });

        window.addEventListener('resize', this.debounce(() => {
            this.handleResize();
        }, 250));

        window.addEventListener('visibilitychange', () => {
            this.handleVisibilityChange();
        });
    }

    setupHeroCarousels() {
        const heroSections = document.querySelectorAll('.hero-section, #hero, #gallery-hero, #care-hero, #adoption-hero, #contact-hero');
        
        heroSections.forEach(hero => {
            if (this.shouldCreateCarousel(hero)) {
                this.createHeroCarousel(hero);
            }
        });
    }

    shouldCreateCarousel(element) {
        const images = element.querySelectorAll('img');
        const hasMultipleImages = images.length > 1;
        const hasCarouselClass = element.classList.contains('carousel') || element.querySelector('.carousel-container');
        return hasMultipleImages || hasCarouselClass;
    }

    createHeroCarousel(heroSection) {
        const carouselId = this.generateCarouselId();
        const heroImages = this.getHeroImages();
        
        if (heroImages.length === 0) return;

        const carouselContainer = document.createElement('div');
        carouselContainer.className = 'hero-carousel-container';
        carouselContainer.id = carouselId;

        const carousel = document.createElement('div');
        carousel.className = 'hero-carousel';

        const track = document.createElement('div');
        track.className = 'carousel-track';

        heroImages.forEach((imageData, index) => {
            const slide = this.createHeroSlide(imageData, index);
            track.appendChild(slide);
        });

        carousel.appendChild(track);
        
        if (heroImages.length > 1) {
            const controls = this.createCarouselControls();
            const indicators = this.createCarouselIndicators(heroImages.length);
            carousel.appendChild(controls);
            carousel.appendChild(indicators);
        }

        carouselContainer.appendChild(carousel);
        
        const existingImage = heroSection.querySelector('.hero-image img');
        if (existingImage) {
            existingImage.parentElement.replaceWith(carouselContainer);
        } else {
            const heroContent = heroSection.querySelector('.hero-content');
            if (heroContent) {
                heroContent.appendChild(carouselContainer);
            }
        }
this.initializeCarousel(carouselId, {
            autoPlay: !this.prefersReducedMotion,
            showIndicators: true,
            showControls: true,
            loop: true
        });
    }

    getHeroImages() {
        return [
            { src: 'images/hero-kitten-1.jpg', alt: 'Adorable kitten playing', title: 'Welcome to KittenWorld' },
            { src: 'images/hero-kitten-2.jpg', alt: 'Cute kittens sleeping', title: 'Find Your Perfect Companion' },
            { src: 'images/hero-kitten-3.jpg', alt: 'Playful kitten with toy', title: 'Loving Homes Await' },
            { src: 'images/hero-kitten-4.jpg', alt: 'Beautiful kitten portrait', title: 'Join Our Community' }
        ];
    }

    createHeroSlide(imageData, index) {
        const slide = document.createElement('div');
        slide.className = `carousel-slide ${index === 0 ? 'active' : ''}`;
        slide.dataset.index = index;
const img = document.createElement('img');
        img.src = imageData.src;
        img.alt = imageData.alt;
        img.className = 'carousel-image';
        img.loading = index === 0 ? 'eager' : 'lazy';

        if (imageData.title) {
            const overlay = document.createElement('div');
            overlay.className = 'carousel-overlay';
            
            const title = document.createElement('h3');
            title.className = 'carousel-title';
            title.textContent = imageData.title;
            
            overlay.appendChild(title);
            slide.appendChild(overlay);
        }

        slide.appendChild(img);
        return slide;
    }

    setupTestimonialCarousels() {
        const testimonialSections = document.querySelectorAll('.testimonials, .reviews, .success-stories');
        
        testimonialSections.forEach(section => {
            this.createTestimonialCarousel(section);
        });
    }
createTestimonialCarousel(section) {
        const carouselId = this.generateCarouselId();
        const testimonials = this.getTestimonialData();
        
        if (testimonials.length === 0) return;

        const carousel = document.createElement('div');
        carousel.className = 'testimonial-carousel';
        carousel.id = carouselId;

        const track = document.createElement('div');
        track.className = 'carousel-track';

        testimonials.forEach((testimonial, index) => {
            const slide = this.createTestimonialSlide(testimonial, index);
            track.appendChild(slide);
        });

        carousel.appendChild(track);
        
        const controls = this.createCarouselControls();
        const indicators = this.createCarouselIndicators(testimonials.length);
        carousel.appendChild(controls);
        carousel.appendChild(indicators);
section.appendChild(carousel);
        
        this.initializeCarousel(carouselId, {
            autoPlay: !this.prefersReducedMotion,
            showIndicators: true,
            showControls: true,
            loop: true
        });
    }

    getTestimonialData() {
        return [
            { 
                text: "We found our perfect kitten through KittenWorld. The adoption process was smooth and the staff was incredibly helpful!", 
                author: "Sarah Johnson", 
                location: "New York, NY",
                image: "images/testimonial-1