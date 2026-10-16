/// Configuración de entorno. Se pasa al compilar:
///
///   flutter run --dart-define=API_URL=https://api.ejemplo.co/api \
///               --dart-define=KIOSK_API_KEY=... --dart-define=USE_MOCKS=false
///
/// - API_URL: base del API Gateway (kiora-backend).
/// - KIOSK_API_KEY: llave pública del kiosco para pedidos sin JWT.
/// - USE_MOCKS: `true` por defecto; los servicios usan datos locales
///   etiquetados como mock cuando no hay backend.
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api');
  static const kioskApiKey = String.fromEnvironment('KIOSK_API_KEY');
  static const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  /// Origen del gateway (sin `/api`), para imágenes servidas en /uploads.
  static String get apiOrigin => apiUrl.replaceFirst(RegExp(r'/api/?$'), '');
}
