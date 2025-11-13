/**
 * KittenWorld - Gallery JavaScript File
 * Handles image galleries, lightboxes, filtering, and image interactions across all pages
 */

class KittenGallery {
    constructor() {
        this.currentFilter = 'all';
        this.currentLightboxIndex = 0;
        this.lightboxImages = [];
        this.isLightboxOpen = false;
        this.touchStartX = 0;
        this.touchEndX = 0;
        this.preloadedImages = new Map();
        this.observerOptions = {
            root: null,
            rootMargin: '50px',
            threshold: 0.1
        };
        this.init();
    }
init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.setupGalleryGrid();
            this.setupLightbox();
            this.setupFiltering();
            this.setupImageLazyLoading();
            this.setupTouchGestures();
            this.setupKeyboardNavigation();
            this.setupImagePreloading();
            this.setupInfiniteScroll();
            console.log('KittenGallery initialized');
        });
    }

    setupGalleryGrid() {
        const galleryContainers = document.querySelectorAll('.gallery-grid, .kitten-grid, .adoption-grid, .image-grid');
        
        galleryContainers.forEach(container => {
            this.createGalleryItems(container);
            this.setupGridInteractions(container);
        });

        // Setup masonry layout if applicable
        this.setupMasonryLayout();
    }

    createGalleryItems(container) {
        if (container.children.length > 0) return; // Already has items

        const galleryData = this.getGalleryData(container);
        
        galleryData.forEach((item, index) => {
            const galleryItem = this.createGalleryItem(item, index);
            container.appendChild(galleryItem);
        });
    }

    getGalleryData(container) {
        const containerClass = container.className;
        
        if (containerClass.includes('gallery-grid')) {
            return this.getMainGalleryData();
        } else if (containerClass.includes('adoption-grid')) {
            return this.getAdoptionGalleryData();
        } else if (containerClass.includes('kitten-grid')) {
            return this.getKittenGridData();
        }
        
        return this.getDefaultGalleryData();
    }
getMainGalleryData() {
        return [
            { src: '../images/persian-kitten.jpg', alt: 'Persian kitten', category: 'persian', title: 'Fluffy Persian Kitten', description: 'Adorable Persian kitten with beautiful blue eyes' },
            { src: '../images/tabby-kitten.jpg', alt: 'Tabby kitten', category: 'tabby', title: 'Playful Tabby Kitten', description: 'Active tabby kitten ready for adventure' },
            { src: '../images/siamese-kitten.jpg', alt: 'Siamese kitten', category: 'siamese', title: 'Elegant Siamese Kitten', description: 'Graceful Siamese with striking blue eyes' },
            { src: '../images/maine-coon.jpg', alt: 'Maine Coon kitten', category: 'maine-coon', title: 'Majestic Maine Coon', description: 'Large and fluffy Maine Coon kitten' },
            { src: '../images/ragdoll-kitten.jpg', alt: 'Ragdoll kitten', category: 'ragdoll', title: 'Gentle Ragdoll Kitten', description: 'Sweet-natured Ragdoll with soft fur' },
            { src: '../images/british-shorthair.jpg', alt: 'British Shorthair', category: 'british-shorthair', title: 'British Shorthair Kitten', description: 'Round-faced British Shorthair cutie' },
            { src: '../images/bengal-kitten.jpg', alt: 'Bengal kitten', category: 'bengal', title: 'Wild Bengal Kitten', description: 'Spotted Bengal with wild markings' },
            { src: '../images/russian-blue.jpg', alt: 'Russian Blue kitten', category: 'russian-blue', title: 'Russian Blue Beauty', description: 'Elegant Russian Blue with silver coat' }
        ];
    }
getAdoptionGalleryData() {
        return [
            { src: '../images/adopt-luna.jpg', alt: 'Luna - available for adoption', category: 'available', title: 'Luna', description: '8 weeks old, playful and loving', age: '8 weeks', breed: 'Mixed' },
            { src: '../images/adopt-max.jpg', alt: 'Max - available for adoption', category: 'available', title: 'Max', description: '10 weeks old, calm and gentle', age: '10 weeks', breed: 'Tabby' },
            { src: '../images/adopt-bella.jpg', alt: 'Bella - available for adoption', category: 'available', title: 'Bella', description: '12 weeks old, very social', age: '12 weeks', breed: 'Calico' },
            { src: '../images/adopt-oscar.jpg', alt: 'Oscar - available for adoption', category: 'available', title: 'Oscar', description: '9 weeks old, loves to play', age: '9 weeks', breed: 'Orange Tabby' }
        ];
    }
getKittenGridData() {
        return [
            { src: '../images/kitten-1.jpg', alt: 'Cute kitten playing', category: 'playing', title: 'Playful Moment' },
            { src: '../images/kitten-2.jpg', alt: 'Sleeping kitten', category: 'sleeping', title: 'Sweet Dreams' },
            { src: '../images/kitten-3.jpg', alt: 'Curious kitten', category: 'exploring', title: 'Curious Explorer' },
            { src: '../images/kitten-4.jpg', alt: 'Kitten with toy', category: 'playing', title: 'Toy Time' }
        ];
    }

    getDefaultGalleryData() {
        return [
            { src: '../images/default-kitten-1.jpg', alt: 'Adorable kitten', category: 'general', title: 'Adorable Kitten' },
            { src: '../images/default-kitten-2.jpg', alt: 'Cute kitten', category: 'general', title: 'Cute Kitten' }
        ];
    }
createGalleryItem(item, index) {
        const galleryItem = document.createElement('div');
        galleryItem.className = `gallery-item ${item.category || 'general'}`;
        galleryItem.dataset.category = item.category || 'general';
        galleryItem.dataset.index = index;

        const img = document.createElement('img');
        img.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDMwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N