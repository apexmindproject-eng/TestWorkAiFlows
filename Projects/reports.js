document.addEventListener('DOMContentLoaded', () => {
  const vendorSelect = document.getElementById('vendor');
  const reportFilterForm = document.getElementById('reportFilterForm');
  const reportContent = document.getElementById('reportContent');

  // Fetch vendor list and populate dropdown
  function loadVendors() {
    // Simulated fetch vendors from a data source
    const vendors = [
      { id: 'vendor1', name: 'Vendor One' },
      { id: 'vendor2', name: 'Vendor Two' },
      { id: 'vendor3', name: 'Vendor Three' },
    ];

    vendors.forEach(vendor => {
      let option = document.createElement('option');
      option.value = vendor.id;
      option.textContent = vendor.name;
      vendorSelect.appendChild(option);
    });
  }

  // Utility to format date to yyyy-mm-dd
  function formatDate(date) {
    let d = new Date(date);
    let month = '' + (d.getMonth() + 1);
    let day = '' + d.getDate();
    const year = d.getFullYear();

    if (month.length < 2) month = '0' + month;
    if (day.length < 2) day = '0' + day;

    return [year, month, day].join('-');
  }

  // Fetch reports with filters, simulated here
  function fetchReports(filters) {
    // Simulated report data
    const allReports = [
      { id: 1, vendor: 'vendor1', date: '2024-05-01', summary: 'Order volume high', details: 'The order volume increased by 20% compared to last month.' },
      { id: 2, vendor: 'vendor2', date: '2024-05-02', summary: 'Delayed deliveries', details: 'Delivery times averaged 2 days longer than expected.' },
      { id: 3, vendor: 'vendor3', date: '2024-05-03', summary: 'Excellent vendor rating', details: 'Vendor received highest satisfaction score last quarter.' },
      { id: 4, vendor: 'vendor1', date: '2024-05-04', summary: 'Cost savings on bulk orders', details: 'Bulk ordering resulted in 15% cost savings.' },
    ];

    return allReports.filter(report => {
      let reportDate = new Date(report.date);
      let fromDateCheck = filters.dateFrom ? reportDate >= new Date(filters.dateFrom) : true;
      let toDateCheck = filters.dateTo ? reportDate <= new Date(filters.dateTo) : true;
      let vendorCheck = filters.vendor === 'all' ? true : report.vendor === filters.vendor;
      return fromDateCheck && toDateCheck && vendorCheck;
    });
  }

  function renderReports(reports) {
    reportContent.innerHTML = '';

    if (reports.length === 0) {
      reportContent.innerHTML = '<p>No reports match the selected filters.</p>';
      return;
    }

    reports.forEach(report => {
      const div = document.createElement('div');
      div.classList.add('report-item');

      const date = document.createElement('p');
      date.classList.add('report-date');
      date.textContent = `Date: ${report.date}`;

      const vendor = document.createElement('p');
      vendor.classList.add('report-vendor');
      vendor.textContent = `Vendor: ${vendorSelect.querySelector(`option[value="${report.vendor}"]`).textContent}`;

      const summary = document.createElement('h3');
      summary.textContent = report.summary;

      const details = document.createElement('p');
      details.textContent = report.details;

      div.appendChild(summary);
      div.appendChild(date);
      div.appendChild(vendor);
      div.appendChild(details);

      reportContent.appendChild(div);
    });
  }

  reportFilterForm.addEventListener('submit', (e) => {
    e.preventDefault();

    const filters = {
      dateFrom: reportFilterForm.dateFrom.value || null,
      dateTo: reportFilterForm.dateTo.value || null,
      vendor: reportFilterForm.vendor.value || 'all',
    };

    const filteredReports = fetchReports(filters);
    renderReports(filteredReports);
  });

  // Initialization
  loadVendors();
  // Load reports with default filters (all)
  renderReports(fetchReports({ dateFrom: null, dateTo: null, vendor: 'all' }));
});