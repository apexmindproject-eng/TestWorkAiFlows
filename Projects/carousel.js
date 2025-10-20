document.addEventListener('DOMContentLoaded', function() {
  const galleryContainer = document.querySelector('.gallery-container');
  const thumbnails = galleryContainer ? galleryContainer.querySelectorAll('.gallery-thumbnail') : [];

  if (thumbnails.length === 0) return;

  let currentIndex = 0;

  // Create the carousel overlay elements
  const overlay = document.createElement('div');
  overlay.id = 'carousel-overlay';
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.width = '100vw';
  overlay.style.height = '100vh';
  overlay.style.backgroundColor = 'rgba(0,0,0,0.8)';
  overlay.style.display = 'flex';
  overlay.style.justifyContent = 'center';
  overlay.style.alignItems = 'center';
  overlay.style.zIndex = '1000';
  overlay.style.visibility = 'hidden';

  const carouselImg = document.createElement('img');
  carouselImg.style.maxWidth = '90vw';
  carouselImg.style.maxHeight = '80vh';
  carouselImg.style.border = '4px solid white';
  carouselImg.style.borderRadius = '8px';

  const prevButton = document.createElement('button');
  prevButton.textContent = '\u276E'; // left arrow
  prevButton.style.position = 'absolute';
  prevButton.style.left = '20px';
  prevButton.style.top = '50%';
  prevButton.style.transform = 'translateY(-50%)';
  prevButton.style.fontSize = '3rem';
  prevButton.style.color = 'white';
  prevButton.style.background = 'transparent';
  prevButton.style.border = 'none';
  prevButton.style.cursor = 'pointer';

  const nextButton = document.createElement('button');
  nextButton.textContent = '\u276F'; // right arrow
  nextButton.style.position = 'absolute';
  nextButton.style.right = '20px';
  nextButton.style.top = '50%';
  nextButton.style.transform = 'translateY(-50%)';
  nextButton.style.fontSize = '3rem';
  nextButton.style.color = 'white';
  nextButton.style.background = 'transparent';
  nextButton.style.border = 'none';
  nextButton.style.cursor = 'pointer';

  const closeButton = document.createElement('button');
  closeButton.textContent = '×';
  closeButton.style.position = 'absolute';
  closeButton.style.top = '20px';
  closeButton.style.right = '20px';
  closeButton.style.fontSize = '3rem';
  closeButton.style.color = 'white';
  closeButton.style.background = 'transparent';
  closeButton.style.border = 'none';
  closeButton.style.cursor = 'pointer';

  overlay.appendChild(carouselImg);
  overlay.appendChild(prevButton);
  overlay.appendChild(nextButton);
  overlay.appendChild(closeButton);
  document.body.appendChild(overlay);

  function showImage(index) {
    if (index < 0) {
      currentIndex = thumbnails.length - 1;
    } else if (index >= thumbnails.length) {
      currentIndex = 0;
    } else {
      currentIndex = index;
    }
    const imgSrc = thumbnails[currentIndex].src;
    const imgAlt = thumbnails[currentIndex].alt || '';
    carouselImg.src = imgSrc;
    carouselImg.alt = imgAlt;
    overlay.style.visibility = 'visible';
  }

  function hideCarousel() {
    overlay.style.visibility = 'hidden';
  }

  thumbnails.forEach((thumbnail, index) => {
    thumbnail.style.cursor = 'pointer';
    thumbnail.addEventListener('click', () => {
      showImage(index);
    });
    thumbnail.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        showImage(index);
      }
    });
  });

  prevButton.addEventListener('click', () => {
    showImage(currentIndex - 1);
  });

  nextButton.addEventListener('click', () => {
    showImage(currentIndex + 1);
  });

  closeButton.addEventListener('click', () => {
    hideCarousel();
  });

  // Hide carousel if click outside image
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
      hideCarousel();
    }
  });

  // Keyboard navigation support
  document.addEventListener('keydown', (e) => {
    if (overlay.style.visibility === 'visible') {
      if (e.key === 'ArrowLeft') {
        showImage(currentIndex - 1);
      } else if (e.key === 'ArrowRight') {
        showImage(currentIndex + 1);
      } else if (e.key === 'Escape') {
        hideCarousel();
      }
    }
  });
});