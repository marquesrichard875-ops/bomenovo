import 'package:flutter/foundation.dart';

/// Endereço da API FastAPI.
///
/// Pode ser sobrescrito ao rodar:  flutter run --dart-define=API_URL=http://192.168.0.10:8000
/// Padrões:
///  - Emulador Android: 10.0.2.2 aponta para o "localhost" do computador.
///  - Web / Desktop: localhost.
String get apiUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
