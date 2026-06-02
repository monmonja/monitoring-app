# Website Uptime Monitor

A robust, pure-mobile Flutter application designed to help users monitor their websites by scheduling periodic background checks.

## Advanced Features
This application is fully featured and entirely localized to the device (no external backend servers).

*   **Reliable Background Checks:** Uses `flutter_background_service` to run scheduled jobs.
*   **Latency & SSL Monitoring:** Tracks response times and alerts on impending SSL certificate expirations.
*   **Advanced Assertions:** Asserts HTTP status codes and allows asserting the *presence* or *absence* of specific keywords.
*   **Anti-Spam & Retries:** Requires 3 consecutive check failures before triggering an alert, and groups notifications to prevent alert fatigue.
*   **Data Visualization:** Uses `fl_chart` to render historical latency logs.
*   **Home Widget:** Includes an Android Home Screen Widget to view system status at a glance.
*   **Status Sharing:** Easily share your current uptime status to messaging apps using `share_plus`.
