document.addEventListener('DOMContentLoaded', function () {
  // Chart.js is assumed to be included in the project assets for drawing charts

  // Utility function to fetch analytics data (stub for actual API or data source)
  async function fetchAnalyticsData() {
    // Simulate fetching data for orders, inventory, and vendor performance
    return {
      orders: {
        labels: ['January', 'February', 'March', 'April', 'May', 'June'],
        data: [120, 150, 170, 140, 180, 200]
      },
      inventory: {
        labels: ['Item A', 'Item B', 'Item C', 'Item D'],
        data: [300, 250, 400, 220]
      },
      vendors: {
        labels: ['Vendor 1', 'Vendor 2', 'Vendor 3', 'Vendor 4'],
        data: [85, 70, 90, 60]
      },
      detailedReports: [
        { title: 'Monthly Orders Report', content: 'Total orders increased steadily over the last 6 months.' },
        { title: 'Inventory Turnover', content: 'Item C has the highest turnover rate among inventory items.' },
        { title: 'Vendor Performance Highlights', content: 'Vendor 3 consistently delivers highest quality and timeliness.' }
      ]
    };
  }

  // Function to create chart given context, labels, data, and options
  function createChart(ctx, labels, data, chartLabel, chartType = 'line') {
    return new Chart(ctx, {
      type: chartType,
      data: {
        labels: labels,
        datasets: [{
          label: chartLabel,
          data: data,
          backgroundColor: 'rgba(54, 162, 235, 0.5)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1,
          fill: chartType === 'line'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true
          }
        },
        plugins: {
          legend: {
            display: true,
            position: 'top'
          }
        }
      }
    });
  }

  // Render detailed reports section
  function renderDetailedReports(reports) {
    const container = document.getElementById('reportsContainer');
    if (!container) return;
    container.innerHTML = '';

    reports.forEach(report => {
      const reportDiv = document.createElement('div');
      reportDiv.className = 'report-item';

      const title = document.createElement('h3');
      title.textContent = report.title;
      reportDiv.appendChild(title);

      const content = document.createElement('p');
      content.textContent = report.content;
      reportDiv.appendChild(content);

      container.appendChild(reportDiv);
    });
  }

  // Main init function
  async function initAnalytics() {
    const analyticsData = await fetchAnalyticsData();

    // Orders Chart
    const ordersCtx = document.getElementById('ordersChart')?.getContext('2d');
    if (ordersCtx) {
      createChart(ordersCtx, analyticsData.orders.labels, analyticsData.orders.data, 'Orders Over Time', 'line');
    }

    // Inventory Chart
    const inventoryCtx = document.getElementById('inventoryChart')?.getContext('2d');
    if (inventoryCtx) {
      createChart(inventoryCtx, analyticsData.inventory.labels, analyticsData.inventory.data, 'Inventory Levels', 'bar');
    }

    // Vendor Performance Chart
    const vendorCtx = document.getElementById('vendorChart')?.getContext('2d');
    if (vendorCtx) {
      createChart(vendorCtx, analyticsData.vendors.labels, analyticsData.vendors.data, 'Vendor Performance (%)', 'bar');
    }

    // Render Detailed Reports
    renderDetailedReports(analyticsData.detailedReports);
  }

  initAnalytics().catch(console.error);
});