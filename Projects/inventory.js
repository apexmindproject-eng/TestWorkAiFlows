document.addEventListener('DOMContentLoaded', () => {
  const inventoryItemsEl = document.getElementById('inventory-items');
  const addItemBtn = document.getElementById('add-item-btn');
  const inventoryFormSection = document.getElementById('inventory-form-section');
  const inventoryForm = document.getElementById('inventory-form');
  const cancelBtn = document.getElementById('cancel-btn');
  const searchInput = document.getElementById('search-inventory');

  let inventoryData = [];
  let editItemId = null;

  function loadInventory() {
    const data = localStorage.getItem('inventoryData');
    inventoryData = data ? JSON.parse(data) : [];
  }

  function saveInventory() {
    localStorage.setItem('inventoryData', JSON.stringify(inventoryData));
  }

  function renderInventory(items) {
    inventoryItemsEl.innerHTML = '';
    if (items.length === 0) {
      const tr = document.createElement('tr');
      const td = document.createElement('td');
      td.colSpan = 6;
      td.textContent = 'No items found';
      td.style.textAlign = 'center';
      tr.appendChild(td);
      inventoryItemsEl.appendChild(tr);
      return;
    }
    items.forEach((item, index) => {
      const tr = document.createElement('tr');

      tr.innerHTML = `
        <td>${item.name}</td>
        <td>${item.sku}</td>
        <td>${item.quantity}</td>
        <td>${item.vendor}</td>
        <td>${new Date(item.lastUpdated).toLocaleString()}</td>
        <td>
          <button class="edit-btn" data-index="${index}">Edit</button>
          <button class="delete-btn" data-index="${index}">Delete</button>
        </td>
      `;

      inventoryItemsEl.appendChild(tr);
    });
  }

  function showForm(edit = false, item = null) {
    inventoryFormSection.classList.remove('hidden');
    if (edit && item) {
      inventoryForm['item-name'].value = item.name;
      inventoryForm['item-sku'].value = item.sku;
      inventoryForm['item-quantity'].value = item.quantity;
      inventoryForm['item-vendor'].value = item.vendor;
    } else {
      inventoryForm.reset();
    }
  }

  function hideForm() {
    inventoryFormSection.classList.add('hidden');
    editItemId = null;
  }

  addItemBtn.addEventListener('click', () => {
    showForm();
  });

  cancelBtn.addEventListener('click', () => {
    hideForm();
  });

  inventoryForm.addEventListener('submit', e => {
    e.preventDefault();

    const name = inventoryForm['item-name'].value.trim();
    const sku = inventoryForm['item-sku'].value.trim();
    const quantity = Number(inventoryForm['item-quantity'].value);
    const vendor = inventoryForm['item-vendor'].value.trim();

    if (!name || !sku || quantity < 0 || !vendor) {
      alert('Please fill out all fields with valid values.');
      return;
    }

    const now = new Date().toISOString();

    if (editItemId !== null) {
      // Edit existing item
      inventoryData[editItemId] = {
        ...inventoryData[editItemId],
        name,
        sku,
        quantity,
        vendor,
        lastUpdated: now,
      };
    } else {
      // Add new item
      inventoryData.push({
        name,
        sku,
        quantity,
        vendor,
        lastUpdated: now,
      });
    }

    saveInventory();
    renderInventory(inventoryData);
    hideForm();
  });

  inventoryItemsEl.addEventListener('click', e => {
    if (e.target.classList.contains('edit-btn')) {
      const index = parseInt(e.target.dataset.index, 10);
      if (index >= 0 && index < inventoryData.length) {
        editItemId = index;
        showForm(true, inventoryData[index]);
      }
    }

    if (e.target.classList.contains('delete-btn')) {
      const index = parseInt(e.target.dataset.index, 10);
      if (index >= 0 && index < inventoryData.length) {
        if (confirm(`Are you sure you want to delete the item "${inventoryData[index].name}"?`)) {
          inventoryData.splice(index, 1);
          saveInventory();
          renderInventory(inventoryData);
        }
      }
    }
  });

  searchInput.addEventListener('input', () => {
    const query = searchInput.value.toLowerCase();
    const filtered = inventoryData.filter(item => {
      return (
        item.name.toLowerCase().includes(query) ||
        item.sku.toLowerCase().includes(query) ||
        item.vendor.toLowerCase().includes(query)
      );
    });
    renderInventory(filtered);
  });

  // Initial load
  loadInventory();
  renderInventory(inventoryData);
});