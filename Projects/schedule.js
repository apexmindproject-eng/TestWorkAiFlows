document.addEventListener('DOMContentLoaded', () => {
  // Highlight the current day in the class schedule table
  const today = new Date().getDay(); // Sunday = 0, Monday = 1, ... Saturday = 6
  const dayMap = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    0: 'Sunday'
  };

  const scheduleTable = document.querySelector('.schedule-details table tbody');

  if (scheduleTable) {
    [...scheduleTable.rows].forEach(row => {
      const dayCell = row.cells[0];
      if (dayCell && dayCell.textContent.trim() === dayMap[today]) {
        row.classList.add('highlight-today');
      }
    });
  }
});