using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using WebApp.Models;
using WebApp.Data;

namespace WebApp.Controllers
{
    public class EmployeesController : Controller
    {
        private readonly WebAppContext _context;
        private readonly ILogger<EmployeesController> _logger;

        public EmployeesController(WebAppContext context, ILogger<EmployeesController> logger)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        // GET: Employees
        public async Task<IActionResult> Index()
        {
            try
            {
                var employees = await _context.Employee
                    .OrderBy(e => e.Fullname)
                    .AsNoTracking()
                    .ToListAsync();
                
                return View(employees);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while retrieving employees list");
                TempData["ErrorMessage"] = "An error occurred while retrieving employees.";
                return View(new List<Employee>());
            }
        }

        // GET: Employees/Details/5
        public async Task<IActionResult> Details(int? id)
        {
            if (id == null || id <= 0)
            {
                _logger.LogWarning("Details method called with invalid ID: {Id}", id);
                return NotFound();
            }

            try
            {
                var employee = await _context.Employee
                    .AsNoTracking()
                    .FirstOrDefaultAsync(m => m.Id == id);

                if (employee == null)
                {
                    _logger.LogWarning("Employee with ID {Id} not found", id);
                    return NotFound();
                }

                return View(employee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while retrieving employee details for ID: {Id}", id);
                TempData["ErrorMessage"] = "An error occurred while retrieving employee details.";
                return RedirectToAction(nameof(Index));
            }
        }

        // GET: Employees/Create
        public IActionResult Create()
        {
            try
            {
                PopulateDepartmentsViewBag();
                return View();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred in Create GET method");
                TempData["ErrorMessage"] = "An error occurred while loading the create form.";
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: Employees/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("Id,Fullname,Department,Email,Phone,Address")] Employee employee)
        {
            try
            {
                if (ModelState.IsValid)
                {
                    // Additional validation
                    if (await EmployeeEmailExists(employee.Email))
                    {
                        ModelState.AddModelError(nameof(Employee.Email), "An employee with this email already exists.");
                        PopulateDepartmentsViewBag();
                        return View(employee);
                    }

                    _context.Add(employee);
                    await _context.SaveChangesAsync();
                    
                    _logger.LogInformation("Employee created successfully: {EmployeeName} (ID: {EmployeeId})", employee.Fullname, employee.Id);
                    TempData["SuccessMessage"] = "Employee created successfully.";
                    return RedirectToAction(nameof(Index));
                }

                PopulateDepartmentsViewBag();
                return View(employee);
            }
            catch (DbUpdateException dbEx)
            {
                _logger.LogError(dbEx, "Database error occurred while creating employee");
                ModelState.AddModelError("", "Unable to save changes. Please try again.");
                PopulateDepartmentsViewBag();
                return View(employee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error occurred while creating employee");
                TempData["ErrorMessage"] = "An unexpected error occurred while creating the employee.";
                PopulateDepartmentsViewBag();
                return View(employee);
            }
        }

        // GET: Employees/Edit/5
        public async Task<IActionResult> Edit(int? id)
        {
            if (id == null || id <= 0)
            {
                return NotFound();
            }

            try
            {
                var employee = await _context.Employee.FindAsync(id);
                if (employee == null)
                {
                    return NotFound();
                }

                PopulateDepartmentsViewBag();
                return View(employee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while loading edit form for employee ID: {Id}", id);
                TempData["ErrorMessage"] = "An error occurred while loading the edit form.";
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: Employees/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, [Bind("Id,Fullname,Department,Email,Phone,Address")] Employee employee)
        {
            if (id != employee.Id)
            {
                return NotFound();
            }

            try
            {
                if (ModelState.IsValid)
                {
                    // Check if email is being used by another employee
                    if (await EmployeeEmailExists(employee.Email, employee.Id))
                    {
                        ModelState.AddModelError(nameof(Employee.Email), "An employee with this email already exists.");
                        PopulateDepartmentsViewBag();
                        return View(employee);
                    }

                    _context.Update(employee);
                    await _context.SaveChangesAsync();
                    
                    _logger.LogInformation("Employee updated successfully: {EmployeeName} (ID: {EmployeeId})", employee.Fullname, employee.Id);
                    TempData["SuccessMessage"] = "Employee updated successfully.";
                    return RedirectToAction(nameof(Index));
                }

                PopulateDepartmentsViewBag();
                return View(employee);
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!await EmployeeExists(employee.Id))
                {
                    return NotFound();
                }
                throw;
            }
            catch (DbUpdateException dbEx)
            {
                _logger.LogError(dbEx, "Database error occurred while updating employee ID: {Id}", id);
                ModelState.AddModelError("", "Unable to save changes. Please try again.");
                PopulateDepartmentsViewBag();
                return View(employee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error occurred while updating employee ID: {Id}", id);
                TempData["ErrorMessage"] = "An unexpected error occurred while updating the employee.";
                PopulateDepartmentsViewBag();
                return View(employee);
            }
        }

        // GET: Employees/Delete/5
        public async Task<IActionResult> Delete(int? id)
        {
            if (id == null || id <= 0)
            {
                return NotFound();
            }

            try
            {
                var employee = await _context.Employee
                    .AsNoTracking()
                    .FirstOrDefaultAsync(m => m.Id == id);

                if (employee == null)
                {
                    return NotFound();
                }

                return View(employee);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while loading delete confirmation for employee ID: {Id}", id);
                TempData["ErrorMessage"] = "An error occurred while loading the delete confirmation.";
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: Employees/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            try
            {
                var employee = await _context.Employee.FindAsync(id);
                if (employee == null)
                {
                    _logger.LogWarning("Attempted to delete non-existent employee with ID: {Id}", id);
                    return NotFound();
                }

                _context.Employee.Remove(employee);
                await _context.SaveChangesAsync();
                
                _logger.LogInformation("Employee deleted successfully: {EmployeeName} (ID: {EmployeeId})", employee.Fullname, id);
                TempData["SuccessMessage"] = "Employee deleted successfully.";
                return RedirectToAction(nameof(Index));
            }
            catch (DbUpdateException dbEx)
            {
                _logger.LogError(dbEx, "Database error occurred while deleting employee ID: {Id}", id);
                TempData["ErrorMessage"] = "Unable to delete the employee. Please try again.";
                return RedirectToAction(nameof(Delete), new { id });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error occurred while deleting employee ID: {Id}", id);
                TempData["ErrorMessage"] = "An unexpected error occurred while deleting the employee.";
                return RedirectToAction(nameof(Delete), new { id });
            }
        }

        #region Helper Methods

        private async Task<bool> EmployeeExists(int id)
        {
            return await _context.Employee.AnyAsync(e => e.Id == id);
        }

        private async Task<bool> EmployeeEmailExists(string email, int? excludeId = null)
        {
            if (string.IsNullOrWhiteSpace(email))
                return false;

            return excludeId.HasValue
                ? await _context.Employee.AnyAsync(e => e.Email == email && e.Id != excludeId.Value)
                : await _context.Employee.AnyAsync(e => e.Email == email);
        }

        private void PopulateDepartmentsViewBag()
        {
            // You can populate this from a database table or configuration
            var departments = new List<string>
            {
                "Human Resources",
                "Information Technology",
                "Finance",
                "Marketing",
                "Sales",
                "Operations",
                "Customer Service",
                "Research and Development"
            };

            ViewBag.Departments = new SelectList(departments);
        }

        #endregion
    }
}
