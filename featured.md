# App Overview

This is a Flutter application designed to help users monitor websites by managing domains and scheduling periodic background watch jobs on URLs. The application tracks the status of these URLs, asserting HTTP status codes and optionally verifying the presence of specific keywords in the response.

## Key Features

*   **Dashboard:** Provides a quick overview of all active watches and their current status (e.g., Up, Down, Error).
*   **Domains Management:** Allows users to add, edit, and manage root domains.
*   **Watches:** Users can create, edit, and delete scheduled monitoring tasks (watches) for specific URLs. Each watch can be configured with:
    *   An expected HTTP status code (e.g., 200).
    *   An optional keyword to search for in the response body.
    *   A customizable check interval (in minutes).
*   **Advanced Assertions:** Beyond basic keyword matching, users can configure watches to check for the *absence* of a keyword (e.g., alerting if "Error" appears on the page).
*   **Latency Monitoring:** The app tracks the response time of requests using `dio` and allows users to define custom latency thresholds, sending alerts if a response is too slow.
*   **SSL Expiry Alerts:** The background service checks SSL certificates for HTTPS URLs and can be configured to alert the user if a certificate is expiring within 14 days.
*   **Reliable Pure-Mobile Background Monitoring:** Using `flutter_background_service`, the app reliably checks configured URLs continuously while running in the background without relying on external servers.
*   **Smart Network Retries:** To prevent false positives and alert fatigue from flaky networks, the app only flags a watch as down and sends a notification after 3 consecutive failures.
*   **Grouped Notifications:** Alerts are smartly grouped into a summary notification to keep the user's notification tray clean.
*   **Logs, Visuals, & History:** The app tracks the history of all status checks, logging response times, status codes, and error messages. Visual line charts (`fl_chart`) display response times over the last 50 checks. Old logs are automatically cleaned up after 31 days using `VACUUM` for optimized SQLite database performance.
*   **Uptime Status Sharing:** Users can export a clean, text-based summary of their current system uptime directly from the dashboard using `share_plus`.
*   **Home Screen Widget:** A convenient native Android home screen widget displays a quick summary of the monitoring status (e.g., how many sites are currently DOWN).
*   **Settings:** Allows configuring the application.
