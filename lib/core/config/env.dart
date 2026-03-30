import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class Env {
  static String get apiUrl {
    final url = dotenv.env['API_URL'];
    if (url == null || url.isEmpty) return 'http://localhost:8080';
    return url;
  }

  static String get demoPartnerId => dotenv.env['DEMO_PARTNER_ID'] ?? '';
}
