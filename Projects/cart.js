document.addEventListener('DOMContentLoaded', function () {
    const cartItemsContainer = document.getElementById('cart-items');
    const cartSubtotalEl = document.getElementById('cart-subtotal');
    const cartTaxEl = document.getElementById('cart-tax');
    const cartTotalEl = document.getElementById('cart-total');
    const orderConfirmation = document.getElementById('orderConfirmation');
    const checkoutForm = document.getElementById('checkoutForm');

    const TAX_RATE = 0.07; // 7% tax rate

    // Sample cart data structure stored in localStorage for demo; an array of items
    // Each item: { id, name, price, quantity }
    function getCartItems() {
        const items = localStorage.getItem('cartItems');
        return items ? JSON.parse(items) : [];
    }

    function saveCartItems(items) {
        localStorage.setItem('cartItems', JSON.stringify(items));
    }

    function formatCurrency(amount) {
        return `$${amount.toFixed(2)}`;
    }

    function renderCartItems() {
        const items = getCartItems();
        cartItemsContainer.innerHTML = '';

        if (items.length === 0) {
            cartItemsContainer.innerHTML = '<p>Your cart is empty.</p>';
            updateTotals(0);
            return;
        }

        items.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'cart-item';
            itemDiv.dataset.itemId = item.id;

            itemDiv.innerHTML = `
                <div class="cart-item-details">
                    <span class="cart-item-name">${item.name}</span>
                    <span class="cart-item-price">${formatCurrency(item.price)}</span>
                </div>
                <div class="cart-item-quantity">
                    <label for="qty-${item.id}">Qty:</label>
                    <input type="number" id="qty-${item.id}" class="qty-input" min="1" value="${item.quantity}" aria-label="Quantity for ${item.name}">
                </div>
                <button class="btn-remove" aria-label="Remove ${item.name} from cart">&times;</button>
            `;

            cartItemsContainer.appendChild(itemDiv);
        });

        addCartItemListeners();
        updateTotals();
    }

    function updateTotals() {
        const items = getCartItems();
        const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
        const tax = subtotal * TAX_RATE;
        const total = subtotal + tax;

        cartSubtotalEl.textContent = formatCurrency(subtotal);
        cartTaxEl.textContent = formatCurrency(tax);
        cartTotalEl.textContent = formatCurrency(total);
    }

    function addCartItemListeners() {
        const qtyInputs = cartItemsContainer.querySelectorAll('.qty-input');
        qtyInputs.forEach(input => {
            input.addEventListener('change', function (e) {
                let newQty = parseInt(e.target.value, 10);
                if (isNaN(newQty) || newQty < 1) {
                    newQty = 1;
                    e.target.value = '1';
                }
                const itemId = e.target.id.replace('qty-', '');
                updateItemQuantity(itemId, newQty);
            });
        });

        const removeButtons = cartItemsContainer.querySelectorAll('.btn-remove');
        removeButtons.forEach(button => {
            button.addEventListener('click', function (e) {
                const itemDiv = e.target.closest('.cart-item');
                const itemId = itemDiv.dataset.itemId;
                removeItem(itemId);
            });
        });
    }

    function updateItemQuantity(itemId, quantity) {
        const items = getCartItems();
        const itemIndex = items.findIndex(item => item.id === itemId);
        if (itemIndex !== -1) {
            items[itemIndex].quantity = quantity;
            saveCartItems(items);
            updateTotals();
        }
    }

    function removeItem(itemId) {
        let items = getCartItems();
        items = items.filter(item => item.id !== itemId);
        saveCartItems(items);
        renderCartItems();
    }

    checkoutForm.addEventListener('submit', function (e) {
        e.preventDefault();

        // Simple form validation
        if (!checkoutForm.checkValidity()) {
            checkoutForm.reportValidity();
            return;
        }

        // Here you would normally process the payment and order
        // For demo, we just show confirmation

        // Clear cart
        localStorage.removeItem('cartItems');

        // Hide form and cart after order
        checkoutForm.style.display = 'none';
        cartItemsContainer.style.display = 'none';
        document.querySelector('.cart-totals').style.display = 'none';

        // Show confirmation message
        orderConfirmation.style.display = 'block';

        // Reset form
        checkoutForm.reset();
    });

    renderCartItems();
});