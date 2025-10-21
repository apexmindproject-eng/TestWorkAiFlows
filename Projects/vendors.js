document.addEventListener('DOMContentLoaded', function() {
  const vendorContainer = document.getElementById('vendorContainer');

  // Sample vendors data - this could be fetched from an API or other data source
  const vendors = [
    { id: 1, name: 'Fresh Farms Produce', description: 'High-quality fresh fruits and vegetables.', logo: 'vendor1.png' },
    { id: 2, name: 'Bakery Delights', description: 'Artisan breads and pastries.', logo: 'vendor2.png' },
    { id: 3, name: 'Seafood Co.', description: 'Fresh and frozen seafood.', logo: 'vendor3.png' },
    { id: 4, name: 'Dairy Best', description: 'Organic dairy products.', logo: 'vendor4.png' }
  ];

  function createVendorCard(vendor) {
    const card = document.createElement('div');
    card.className = 'vendor-card';

    const img = document.createElement('img');
    img.src = vendor.logo || 'vendor-icon.png';
    img.alt = vendor.name + ' Logo';
    img.className = 'vendor-logo';
    card.appendChild(img);

    const name = document.createElement('h3');
    name.textContent = vendor.name;
    card.appendChild(name);

    const desc = document.createElement('p');
    desc.textContent = vendor.description;
    card.appendChild(desc);

    const detailLink = document.createElement('a');
    detailLink.href = 'vendor-detail.html?vendorId=' + vendor.id;
    detailLink.textContent = 'View Details';
    detailLink.className = 'btn-view-details';
    card.appendChild(detailLink);

    return card;
  }

  function loadVendors() {
    vendorContainer.innerHTML = '';
    vendors.forEach(vendor => {
      const vendorCard = createVendorCard(vendor);
      vendorContainer.appendChild(vendorCard);
    });
  }

  loadVendors();
});