document.addEventListener('DOMContentLoaded', () => {
  const employeesTableBody = document.querySelector('#employees-table tbody');
  const addEmployeeBtn = document.getElementById('add-employee-btn');
  const searchInput = document.getElementById('search-employees');

  // Sample employees data (could be replace with API call or dynamic data load)
  let employees = [
    { id: 1, name: 'Alice Johnson', position: 'Manager', shift: 'Morning', contact: 'alice.johnson@example.com' },
    { id: 2, name: 'Bob Smith', position: 'Cashier', shift: 'Afternoon', contact: 'bob.smith@example.com' },
    { id: 3, name: 'Charlie Brown', position: 'Cook', shift: 'Evening', contact: 'charlie.brown@example.com' },
  ];

  function renderEmployees(data) {
    employeesTableBody.innerHTML = '';
    if (data.length === 0) {
      const tr = document.createElement('tr');
      const td = document.createElement('td');
      td.colSpan = 5;
      td.textContent = 'No employees found.';
      td.style.textAlign = 'center';
      tr.appendChild(td);
      employeesTableBody.appendChild(tr);
      return;
    }

    data.forEach(employee => {
      const tr = document.createElement('tr');

      const nameTd = document.createElement('td');
      nameTd.textContent = employee.name;
      tr.appendChild(nameTd);

      const positionTd = document.createElement('td');
      positionTd.textContent = employee.position;
      tr.appendChild(positionTd);

      const shiftTd = document.createElement('td');
      shiftTd.textContent = employee.shift;
      tr.appendChild(shiftTd);

      const contactTd = document.createElement('td');
      contactTd.textContent = employee.contact;
      tr.appendChild(contactTd);

      const actionsTd = document.createElement('td');
      // Edit button
      const editBtn = document.createElement('button');
      editBtn.textContent = 'Edit';
      editBtn.addEventListener('click', () => editEmployee(employee.id));
      actionsTd.appendChild(editBtn);
      // Delete button
      const deleteBtn = document.createElement('button');
      deleteBtn.textContent = 'Delete';
      deleteBtn.style.marginLeft = '8px';
      deleteBtn.addEventListener('click', () => deleteEmployee(employee.id));
      actionsTd.appendChild(deleteBtn);

      tr.appendChild(actionsTd);

      employeesTableBody.appendChild(tr);
    });
  }

  function addEmployee(employee) {
    employee.id = employees.length ? employees[employees.length - 1].id + 1 : 1;
    employees.push(employee);
    renderEmployees(employees);
  }

  function editEmployee(id) {
    const employee = employees.find(emp => emp.id === id);
    if (!employee) return;

    const name = prompt('Edit Name:', employee.name);
    if (name === null) return;
    const position = prompt('Edit Position:', employee.position);
    if (position === null) return;
    const shift = prompt('Edit Shift:', employee.shift);
    if (shift === null) return;
    const contact = prompt('Edit Contact:', employee.contact);
    if (contact === null) return;

    employee.name = name.trim();
    employee.position = position.trim();
    employee.shift = shift.trim();
    employee.contact = contact.trim();

    renderEmployees(employees);
  }

  function deleteEmployee(id) {
    if (confirm('Are you sure you want to delete this employee?')) {
      employees = employees.filter(emp => emp.id !== id);
      renderEmployees(employees);
    }
  }

  addEmployeeBtn.addEventListener('click', () => {
    const name = prompt('Enter employee name:');
    if (!name || !name.trim()) {
      alert('Name is required');
      return;
    }

    const position = prompt('Enter position:');
    if (!position || !position.trim()) {
      alert('Position is required');
      return;
    }

    const shift = prompt('Enter shift timing:');
    if (!shift || !shift.trim()) {
      alert('Shift is required');
      return;
    }

    const contact = prompt('Enter contact info:');
    if (!contact || !contact.trim()) {
      alert('Contact info is required');
      return;
    }

    addEmployee({ name: name.trim(), position: position.trim(), shift: shift.trim(), contact: contact.trim() });
  });

  searchInput.addEventListener('input', () => {
    const searchTerm = searchInput.value.toLowerCase();
    const filteredEmployees = employees.filter(emp =>
      emp.name.toLowerCase().includes(searchTerm) ||
      emp.position.toLowerCase().includes(searchTerm) ||
      emp.shift.toLowerCase().includes(searchTerm) ||
      emp.contact.toLowerCase().includes(searchTerm)
    );
    renderEmployees(filteredEmployees);
  });

  // Initial render
  renderEmployees(employees);
});