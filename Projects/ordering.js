document.addEventListener('DOMContentLoaded', () => {
  const vendorSearchInput = document.getElementById('vendorSearch');
  const vendorList = document.getElementById('vendorList');
  const vendorNameInput = document.getElementById('vendorName');
  const productSearchInput = document.getElementById('productSearch');
  const productSuggestions = document.getElementById('productSuggestions');
  const orderItemsBody = document.getElementById('orderItemsBody');
  const subtotalDisplay = document.getElementById('subtotal');
  const taxDisplay = document.getElementById('tax');
  const totalDisplay = document.getElementById('total');
  const orderForm = document.getElementById('orderForm');

  let vendors = [];
  let products = [];
  let selectedVendor = null;
  let orderItems = [];
  const TAX_RATE = 0.07; // Example 7% tax

  // Utility functions
  function formatCurrency(amount) {
    return `$${amount.toFixed(2)}`;
  }

  // Fetch vendors to populate vendor list and search
  function fetchVendors() {
    // Simulate API or local data fetch
    // Vendors should have: id, name, products array
    // For demo, we'll hardcode some sample vendors
    vendors = [
      {
        id: 1,
        name: 'Vendor One',
        products: [
          { id: 101, name: 'Paper A4 Pack', price: 5.5 },
          { id: 102, name: 'Ink Cartridge', price: 35.0 }
        ]
      },
      {
        id: 2,
        name: 'Vendor Two',
        products: [
          { id: 201, name: 'Stapler', price: 12.25 },
          { id: 202, name: 'Pen Set', price: 7.95 }
        ]
      }
    ];
  }

  // Render the filtered vendor list
  function renderVendorList(filter='') {
    vendorList.innerHTML = '';
    const filtered = vendors.filter(v =>
      v.name.toLowerCase().includes(filter.toLowerCase())
    );
    filtered.forEach(vendor => {
      const li = document.createElement('li');
      li.textContent = vendor.name;
      li.tabIndex = 0;
      li.setAttribute('role', 'button');
      li.addEventListener('click', () => {
        selectVendor(vendor.id);
      });
      li.addEventListener('keydown', e => {
        if(e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          selectVendor(vendor.id);
        }
      });
      vendorList.appendChild(li);
    });
  }

  // Select vendor by id
  function selectVendor(vendorId) {
    selectedVendor = vendors.find(v => v.id === vendorId) || null;
    if(selectedVendor) {
      vendorNameInput.value = selectedVendor.name;
      products = selectedVendor.products;
      orderItems = [];
      renderOrderItems();
      updateTotals();
      productSearchInput.disabled = false;
      productSearchInput.value = '';
      productSuggestions.innerHTML = '';
      vendorSearchInput.value = selectedVendor.name;
      vendorList.innerHTML = '';
    }
  }

  // Filter product suggestions based on input
  function filterProductSuggestions(query) {
    productSuggestions.innerHTML = '';
    if(!query || !selectedVendor) return;

    const filtered = products.filter(p =>
      p.name.toLowerCase().includes(query.toLowerCase())
    );

    filtered.slice(0, 5).forEach(product => {
      const li = document.createElement('li');
      li.textContent = `${product.name} - ${formatCurrency(product.price)}`;
      li.tabIndex = 0;
      li.setAttribute('role', 'button');
      li.addEventListener('click', () => {
        addProductToOrder(product);
        productSearchInput.value = '';
        productSuggestions.innerHTML = '';
      });
      li.addEventListener('keydown', e => {
        if(e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          addProductToOrder(product);
          productSearchInput.value = '';
          productSuggestions.innerHTML = '';
        }
      });
      productSuggestions.appendChild(li);
    });
  }

  // Add product to order or increase quantity if already added
  function addProductToOrder(product) {
    let item = orderItems.find(i => i.product.id === product.id);
    if(item) {
      item.quantity += 1;
    } else {
      orderItems.push({ product: product, quantity: 1 });
    }
    renderOrderItems();
    updateTotals();
  }

  // Render order items list
  function renderOrderItems() {
    orderItemsBody.innerHTML = '';
    orderItems.forEach((item, index) => {
      const tr = document.createElement('tr');

      const tdProduct = document.createElement('td');
      tdProduct.textContent = item.product.name;

      const tdQuantity = document.createElement('td');
      const qtyInput = document.createElement('input');
      qtyInput.type = 'number';
      qtyInput.min = '1';
      qtyInput.value = item.quantity;
      qtyInput.addEventListener('change', e => {
        const val = parseInt(e.target.value, 10);
        if(val < 1 || isNaN(val)) {
          e.target.value = item.quantity;
          return;
        }
        item.quantity = val;
        updateTotals();
      });
      tdQuantity.appendChild(qtyInput);

      const tdUnitPrice = document.createElement('td');
      tdUnitPrice.textContent = formatCurrency(item.product.price);

      const tdTotal = document.createElement('td');
      tdTotal.textContent = formatCurrency(item.product.price * item.quantity);

      const tdAction = document.createElement('td');
      const removeBtn = document.createElement('button');
      removeBtn.type = 'button';
      removeBtn.textContent = 'Remove';
      removeBtn.addEventListener('click', () => {
        orderItems.splice(index, 1);
        renderOrderItems();
        updateTotals();
      });
      tdAction.appendChild(removeBtn);

      tr.appendChild(tdProduct);
      tr.appendChild(tdQuantity);
      tr.appendChild(tdUnitPrice);
      tr.appendChild(tdTotal);
      tr.appendChild(tdAction);

      orderItemsBody.appendChild(tr);
    });

    if(orderItems.length === 0) {
      const emptyRow = document.createElement('tr');
      const td = document.createElement('td');
      td.colSpan = 5;
      td.style.textAlign = 'center';
      td.textContent = 'No products added to order.';
      emptyRow.appendChild(td);
      orderItemsBody.appendChild(emptyRow);
    }
  }

  // Update subtotal, tax, total
  function updateTotals() {
    const subtotal = orderItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0);
    const tax = subtotal * TAX_RATE;
    const total = subtotal + tax;

    subtotalDisplay.textContent = formatCurrency(subtotal);
    taxDisplay.textContent = formatCurrency(tax);
    totalDisplay.textContent = formatCurrency(total);
  }

  // Handle order form submission
  orderForm.addEventListener('submit', e => {
    e.preventDefault();
    if(!selectedVendor) {
      alert('Please select a vendor before placing an order.');
      return;
    }
    if(orderItems.length === 0) {
      alert('Please add at least one product to your order.');
      return;
    }

    const specialInstructions = document.getElementById('specialInstructions').value;

    // Prepare order data
    const orderData = {
      vendorId: selectedVendor.id,
      items: orderItems.map(item => ({ productId: item.product.id, quantity: item.quantity })),
      specialInstructions: specialInstructions.trim(),
      date: new Date().toISOString()
    };

    // Simulate API call or local handling
    console.log('Order placed:', orderData);
    alert('Order placed successfully!');

    // Reset form and state
    vendorNameInput.value = '';
    vendorSearchInput.value = '';
    productSearchInput.value = '';
    productSuggestions.innerHTML = '';
    orderItems = [];
    selectedVendor = null;
    renderOrderItems();
    updateTotals();
    productSearchInput.disabled = true;
    orderForm.reset();
  });

  // Event listeners

  vendorSearchInput.addEventListener('input', e => {
    selectedVendor = null;
    vendorNameInput.value = '';
    products = [];
    orderItems = [];
    renderOrderItems();
    updateTotals();
    productSearchInput.value = '';
    productSuggestions.innerHTML = '';
    productSearchInput.disabled = true;
    renderVendorList(e.target.value);
  });

  productSearchInput.addEventListener('input', e => {
    filterProductSuggestions(e.target.value);
  });

  productSearchInput.disabled = true; // Initially disabled until vendor selected

  // Initialization
  fetchVendors();
  renderVendorList();
});