document.addEventListener('DOMContentLoaded', function() {
  const calendarEl = document.getElementById('calendar');

  // Simple Calendar rendering
  function renderCalendar() {
    const today = new Date();
    const year = today.getFullYear();
    const month = today.getMonth();

    // Get first day of the month
    const firstDay = new Date(year, month, 1);
    const startingDay = firstDay.getDay();

    // Get number of days in the month
    const monthLength = new Date(year, month + 1, 0).getDate();

    // Array of day names
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    let html = '<table class="calendar-table">';
    html += '<thead><tr>';
    dayNames.forEach(day => {
      html += `<th>${day}</th>`;
    });
    html += '</tr></thead><tbody><tr>';

    // Fill in blank cells before 1st day
    for (let i = 0; i < startingDay; i++) {
      html += '<td class="empty"></td>';
    }

    // Fill in the days
    for (let day = 1; day <= monthLength; day++) {
      const currentDate = new Date(year, month, day);

      // Highlight today
      const isToday = 
        day === today.getDate() && 
        year === today.getFullYear() && 
        month === today.getMonth();

      html += `<td class="${isToday ? 'today' : ''}" data-date="${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}">${day}</td>`;

      // New row after Saturday
      if ((day + startingDay) % 7 === 0 && day !== monthLength) {
        html += '</tr><tr>';
      }
    }

    // Fill in remaining cells after last day
    const remainingCells = (7 - ((monthLength + startingDay) % 7)) % 7;
    for (let i = 0; i < remainingCells; i++) {
      html += '<td class="empty"></td>';
    }

    html += '</tr></tbody></table>';

    calendarEl.innerHTML = html;
  }

  renderCalendar();

  // Optionally, add click events or interactivity for the calendar days
});