namespace WebApp.Models
{
    /// <summary>
    /// Represents error information to be displayed in error views
    /// </summary>
    public class ErrorViewModel
    {
        /// <summary>
        /// Gets or sets the unique request identifier for correlation
        /// </summary>
        public string? RequestId { get; set; }

        /// <summary>
        /// Gets or sets the HTTP status code of the error
        /// </summary>
        public int? StatusCode { get; set; }

        /// <summary>
        /// Gets or sets the error message to display to the user
        /// </summary>
        public string? ErrorMessage { get; set; }

        /// <summary>
        /// Gets or sets the detailed exception message (for development/debugging)
        /// </summary>
        public string? ExceptionMessage { get; set; }

        /// <summary>
        /// Gets or sets the type of exception that occurred
        /// </summary>
        public string? ExceptionType { get; set; }

        /// <summary>
        /// Gets or sets the stack trace (for development/debugging)
        /// </summary>
        public string? StackTrace { get; set; }

        /// <summary>
        /// Gets or sets the timestamp when the error occurred
        /// </summary>
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Gets or sets the original request path that caused the error
        /// </summary>
        public string? RequestPath { get; set; }

        /// <summary>
        /// Gets or sets the HTTP method of the original request
        /// </summary>
        public string? HttpMethod { get; set; }

        /// <summary>
        /// Gets a value indicating whether the request ID should be displayed
        /// </summary>
        public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);

        /// <summary>
        /// Gets a user-friendly description of the HTTP status code
        /// </summary>
        public string StatusCodeDescription => GetStatusCodeDescription(StatusCode);

        /// <summary>
        /// Gets a value indicating whether detailed error information should be shown
        /// </summary>
        public bool ShowDetailedError { get; set; }

        /// <summary>
        /// Gets the current environment name
        /// </summary>
        public string Environment { get; set; } = 
#if DEBUG
            "Development";
#else
            "Production";
#endif

        /// <summary>
        /// Creates a new ErrorViewModel with basic information
        /// </summary>
        public ErrorViewModel() { }

        /// <summary>
        /// Creates a new ErrorViewModel with request ID
        /// </summary>
        public ErrorViewModel(string requestId)
        {
            RequestId = requestId;
        }

        /// <summary>
        /// Creates a new ErrorViewModel with status code and request ID
        /// </summary>
        public ErrorViewModel(int statusCode, string requestId)
        {
            StatusCode = statusCode;
            RequestId = requestId;
        }

        /// <summary>
        /// Gets a user-friendly description for HTTP status codes
        /// </summary>
        private static string GetStatusCodeDescription(int? statusCode)
        {
            return statusCode switch
            {
                400 => "Bad Request",
                401 => "Unauthorized",
                403 => "Forbidden",
                404 => "Page Not Found",
                500 => "Internal Server Error",
                502 => "Bad Gateway",
                503 => "Service Unavailable",
                _ => "An error occurred"
            };
        }

        /// <summary>
        /// Gets a safe error message for display (prevents information leakage)
        /// </summary>
        public string GetSafeErrorMessage()
        {
            if (!string.IsNullOrEmpty(ErrorMessage))
                return ErrorMessage;

            if (StatusCode.HasValue)
                return $"An error occurred (Status Code: {StatusCode})";

            return "An unexpected error occurred while processing your request.";
        }

        /// <summary>
        /// Determines if stack trace should be displayed based on environment
        /// </summary>
        public bool ShouldShowStackTrace()
        {
            return ShowDetailedError && 
                   !string.IsNullOrEmpty(StackTrace) && 
                   Environment.Equals("Development", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Determines if exception details should be displayed based on environment
        /// </summary>
        public bool ShouldShowExceptionDetails()
        {
            return ShowDetailedError && 
                   (!string.IsNullOrEmpty(ExceptionMessage) || !string.IsNullOrEmpty(ExceptionType)) &&
                   Environment.Equals("Development", StringComparison.OrdinalIgnoreCase);
        }
    }
}
