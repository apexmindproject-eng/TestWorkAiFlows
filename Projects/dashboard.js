document.addEventListener('DOMContentLoaded', () => {
  // Simulated function to fetch dashboard data (could be replaced with real API calls)
  function fetchDashboardData() {
    return new Promise((resolve) => {
      // Dummy data simulating fetched stats and recent activity
      const data = {
        ordersToday: 123,
        pendingDeliveries: 8,
        scheduledShifts: 24,
        activeVendors: 6,
        recentActivity: [
          'Order #4583 completed',
          'New vendor added: Fresh Farms',
          'Shift updated for employee John Doe',
          'Pending delivery #231 processed'
        ]
      };
      setTimeout(() => resolve(data), 500); // Simulate network delay
    });
  }

  function updateDashboardUI(data) {
    document.getElementById('orders-today').textContent = data.ordersToday;
    document.getElementById('pending-deliveries').textContent = data.pendingDeliveries;
    document.getElementById('scheduled-shifts').textContent = data.scheduledShifts;
    document.getElementById('active-vendors').textContent = data.activeVendors;

    const activityList = document.getElementById('activity-list');
    activityList.innerHTML = '';
    if (data.recentActivity && data.recentActivity.length > 0) {
      data.recentActivity.forEach(activity => {
        const li = document.createElement('li');
        li.textContent = activity;
        activityList.appendChild(li);
      });
    } else {
      const li = document.createElement('li');
      li.textContent = 'No recent activity available.';
      activityList.appendChild(li);
    }
  }

  // Fetch dashboard data and update UI
  fetchDashboardData().then(updateDashboardUI).catch(error => {
    console.error('Error loading dashboard data:', error);
  });
});