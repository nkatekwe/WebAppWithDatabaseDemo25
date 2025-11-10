using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using WebApp.Models;

namespace WebApp.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Index()
        {
            try
            {
                _logger.LogInformation("Home page visited at {Timestamp}", DateTime.UtcNow);
                return View();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred while loading the home page");
                return RedirectToAction(nameof(Error));
            }
        }

        [HttpGet]
        public IActionResult Privacy()
        {
            try
            {
                _logger.LogInformation("Privacy page visited at {Timestamp}", DateTime.UtcNow);
                return View();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred while loading the privacy page");
                return RedirectToAction(nameof(Error));
            }
        }

        [HttpGet]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            var errorViewModel = new ErrorViewModel 
            { 
                RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
                // Additional useful information
                Timestamp = DateTime.UtcNow
            };

            _logger.LogError(
                "Error page displayed with RequestId: {RequestId} at {Timestamp}", 
                errorViewModel.RequestId, 
                errorViewModel.Timestamp
            );

            return View(errorViewModel);
        }

        /// <summary>
        /// Custom error handler for specific status codes
        /// </summary>
        [HttpGet]
        [Route("/Home/Error/{statusCode}")]
        public IActionResult Error(int statusCode)
        {
            var errorViewModel = new ErrorViewModel 
            { 
                RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier,
                StatusCode = statusCode,
                Timestamp = DateTime.UtcNow
            };

            _logger.LogWarning(
                "HTTP {StatusCode} error occurred. RequestId: {RequestId}", 
                statusCode, 
                errorViewModel.RequestId
            );

            return View("Error", errorViewModel);
        }

        /// <summary>
        /// Health check endpoint for monitoring
        /// </summary>
        [HttpGet]
        [Route("/health")]
        public IActionResult Health()
        {
            return Ok(new { status = "Healthy", timestamp = DateTime.UtcNow });
        }
    }
}
