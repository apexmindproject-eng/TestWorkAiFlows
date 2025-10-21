document.addEventListener('DOMContentLoaded', () => {
    const vendorNameElem = document.getElementById('vendor-name');
    const vendorDescriptionElem = document.getElementById('vendor-description');
    const vendorContactElem = document.getElementById('vendor-contact');
    const vendorPhoneElem = document.getElementById('vendor-phone');
    const vendorAddressElem = document.getElementById('vendor-address');
    const productListElem = document.getElementById('product-list');
    const productSelectElem = document.getElementById('product-select');
    const orderForm = document.getElementById('order-form');

    // Simulated data fetch for vendor info and products (replace with actual API calls if available)
    function fetchVendorDetails() {
        return Promise.resolve({
            name: 'Superior Office Supplies',
            description: 'Leading provider of quality office supplies and equipment.',
            contact: 'info@superioroffice.com',
            phone: '(555) 123-4567',
            address: '456 Business Rd, Metropolis, NY',
            products: [
                { id: 'p1', name: 'Executive Chair' },
                { id: 'p2', name: 'Standing Desk' },
                { id: 'p3', name: 'Wireless Keyboard' },
                { id: 'p4', name: 'Desk Organizer' },
            ]
        });
    }

    function populateVendorDetails(vendor) {
        vendorNameElem.textContent = vendor.name;
        vendorDescriptionElem.textContent = vendor.description;
        vendorContactElem.textContent = vendor.contact;
        vendorPhoneElem.textContent = vendor.phone;
        vendorAddressElem.textContent = vendor.address;

        productListElem.innerHTML = '';
        productSelectElem.innerHTML = '';

        vendor.products.forEach(product => {
            // Add to product list section
            const productDiv = document.createElement('div');
            productDiv.className = 'product-item';
            productDiv.textContent = product.name;
            productListElem.appendChild(productDiv);

            // Add to product select dropdown
            const option = document.createElement('option');
            option.value = product.id;
            option.textContent = product.name;
            productSelectElem.appendChild(option);
        });
    }

    function handleOrderSubmit(event) {
        event.preventDefault();

        const selectedProductId = productSelectElem.value;
        const quantity = parseInt(document.getElementById('quantity').value, 10);

        if (!selectedProductId) {
            alert('Please select a product to order.');
            return;
        }

        if (quantity < 1 || isNaN(quantity)) {
            alert('Please enter a valid quantity.');
            return;
        }

        // Here, implement order submission logic (e.g., API call to place order)
        // For now, just show confirmation alert
        const selectedProductName = productSelectElem.options[productSelectElem.selectedIndex].textContent;
        alert(`Order placed! \nProduct: ${selectedProductName}\nQuantity: ${quantity}`);

        // Reset form
        orderForm.reset();
    }

    fetchVendorDetails().then(vendor => {
        populateVendorDetails(vendor);
    }).catch(err => {
        console.error('Failed to load vendor details:', err);
        alert('Failed to load vendor details. Please try again later.');
    });

    orderForm.addEventListener('submit', handleOrderSubmit);
});