# App Overview

This is a Flutter application designed to help users monitor websites by managing domains and scheduling periodic background watch jobs on URLs. The application tracks the status of these URLs, asserting HTTP status codes and optionally verifying the presence of specific keywords in the response.

## Key Features

*   **Dashboard:** Provides a quick overview of all active watches and their current status (e.g., Up, Down, Error).
*   **Domains Management:** Allows users to add, edit, and manage root domains.
*   **Watches:** Users can create, edit, and delete scheduled monitoring tasks (watches) for specific URLs. Each watch can be configured with:
    *   An expected HTTP status code (e.g., 200).
    *   An optional keyword to search for in the response body.
    *   A customizable check interval (in minutes).
*   **Background Monitoring:** The app utilizes a background service (`workmanager`) to periodically check the configured URLs, even when the app is not actively running. If a watch fails (e.g., unexpected status code, keyword not found, connection error), the app sends a local push notification to alert the user.
*   **Logs & History:** The app tracks the history of all status checks, logging timestamps, status codes, and any error messages, allowing users to review the historical performance of their monitored URLs. Old logs are automatically cleaned up after 31 days.
*   **Settings:** Allows configuring the application.
