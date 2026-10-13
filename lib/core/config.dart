/// Build-time configuration (`--dart-define`). No secrets live in the app.
///
///   flutter run --dart-define=API_URL=https://api.latoscanapizzeria.es
class AppConfig {
  /// Backend base URL. The default reaches a local API from the Android emulator.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

  /// Public website, for legal pages opened in the browser.
  static const websiteUrl = String.fromEnvironment('WEBSITE_URL', defaultValue: 'https://www.latoscanapizzeria.es');

  /// API contract the app was built against (project-docs/api/openapi.v1.json).
  static const apiContractVersion = '1.3.0';

  static const timezone = 'Europe/Madrid';
}
