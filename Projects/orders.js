document.addEventListener('DOMContentLoaded', () => {
  const ordersTableBody = document.querySelector('#orders-list tbody');
  const filterForm = document.getElementById('filter-form');
  const vendorSelect = document.getElementById('vendor');

  // Sample orders data, in real app this would come from server or local storage
  let orders = [
    { id: '1001', date: '2024-05-01', vendor: 'Vendor A', status: 'pending', total: 150.0 },
    { id: '1002', date: '2024-05-04', vendor: 'Vendor B', status: 'shipped', total: 89.99 },
    { id: '1003', date: '2024-05-10', vendor: 'Vendor C', status: 'delivered', total: 250.25 },
    { id: '1004', date: '2024-05-15', vendor: 'Vendor A', status: 'processing', total: 120.0 },
    { id: '1005', date: '2024-06-01', vendor: 'Vendor B', status: 'canceled', total: 99.99 }
  ];

  // Extract unique vendors from orders
  const vendors = Array.from(new Set(orders.map(order => order.vendor)));

  // Populate vendor dropdown
  vendors.forEach(vendor => {
    const option = document.createElement('option');
    option.value = vendor;
    option.textContent = vendor;
    vendorSelect.appendChild(option);
  });

  // Render orders in the table
  function renderOrders(filteredOrders) {
    ordersTableBody.innerHTML = '';
    if (!filteredOrders.length) {
      const row = document.createElement('tr');
      const cell = document.createElement('td');
      cell.colSpan = 6;
      cell.textContent = 'No orders found for the selected filters.';
      row.appendChild(cell);
      ordersTableBody.appendChild(row);
      return;
    }

    filteredOrders.forEach(order => {
      const row = document.createElement('tr');

      // Order ID
      let cell = document.createElement('td');
      cell.textContent = order.id;
      row.appendChild(cell);

      // Date
      cell = document.createElement('td');
      cell.textContent = order.date;
      row.appendChild(cell);

      // Vendor
      cell = document.createElement('td');
      cell.textContent = order.vendor;
      row.appendChild(cell);

      // Status
      cell = document.createElement('td');
      cell.textContent = capitalizeFirstLetter(order.status);
      row.appendChild(cell);

      // Total
      cell = document.createElement('td');
      cell.textContent = `$${order.total.toFixed(2)}`;
      row.appendChild(cell);

      // Actions
      cell = document.createElement('td');
      const viewBtn = document.createElement('button');
      viewBtn.textContent = 'View';
      viewBtn.addEventListener('click', () => alert(`Viewing details for order ${order.id}`));

      const cancelBtn = document.createElement('button');
      cancelBtn.textContent = 'Cancel';
      cancelBtn.disabled = (order.status === 'canceled' || order.status === 'delivered');
      cancelBtn.addEventListener('click', () => cancelOrder(order.id));

      cell.appendChild(viewBtn);
      cell.appendChild(document.createTextNode(' '));
      cell.appendChild(cancelBtn);
      row.appendChild(cell);

      ordersTableBody.appendChild(row);
    });
  }

  function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
  }

  function cancelOrder(orderId) {
    const orderIndex = orders.findIndex(o => o.id === orderId);
    if (orderIndex !== -1) {
      if (confirm('Are you sure you want to cancel this order?')) {
        orders[orderIndex].status = 'canceled';
        applyFilters();
      }
    }
  }

  // Apply filters based on form inputs
  function applyFilters() {
    const statusFilter = filterForm.status.value;
    const vendorFilter = filterForm.vendor.value;
    const startDate = filterForm['start-date'].value;
    const endDate = filterForm['end-date'].value;

    let filtered = orders.slice();

    if (statusFilter !== 'all') {
      filtered = filtered.filter(order => order.status === statusFilter);
    }

    if (vendorFilter !== 'all') {
      filtered = filtered.filter(order => order.vendor === vendorFilter);
    }

    if (startDate) {
      filtered = filtered.filter(order => order.date >= startDate);
    }

    if (endDate) {
      filtered = filtered.filter(order => order.date <= endDate);
    }

    renderOrders(filtered);
  }

  filterForm.addEventListener('submit', (event) => {
    event.preventDefault();
    applyFilters();
  });

  // Initial load
  renderOrders(orders);
});