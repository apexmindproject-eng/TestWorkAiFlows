document.addEventListener('DOMContentLoaded', () => {
  const thumbnails = document.querySelectorAll('.gallery-thumbnail');

  function openLightbox(src, alt) {
    let lightbox = document.getElementById('lightbox');

    if (!lightbox) {
      lightbox = document.createElement('div');
      lightbox.id = 'lightbox';
      lightbox.style.position = 'fixed';
      lightbox.style.top = 0;
      lightbox.style.left = 0;
      lightbox.style.width = '100%';
      lightbox.style.height = '100%';
      lightbox.style.backgroundColor = 'rgba(0, 0, 0, 0.8)';
      lightbox.style.display = 'flex';
      lightbox.style.alignItems = 'center';
      lightbox.style.justifyContent = 'center';
      lightbox.style.cursor = 'pointer';
      lightbox.style.zIndex = 1000;

      const img = document.createElement('img');
      img.id = 'lightbox-img';
      img.style.maxWidth = '90%';
      img.style.maxHeight = '90%';

      lightbox.appendChild(img);
      document.body.appendChild(lightbox);

      lightbox.addEventListener('click', () => {
        lightbox.style.display = 'none';
      });
    }

    const lbImg = document.getElementById('lightbox-img');
    lbImg.src = src;
    lbImg.alt = alt;

    lightbox.style.display = 'flex';
  }

  thumbnails.forEach(thumbnail => {
    thumbnail.addEventListener('click', () => {
      openLightbox(thumbnail.src, thumbnail.alt);
    });

    thumbnail.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        openLightbox(thumbnail.src, thumbnail.alt);
      }
    });
  });
});