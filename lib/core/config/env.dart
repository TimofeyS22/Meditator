import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get openaiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get elevenlabsApiKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  static String get demoPartnerId => dotenv.env['DEMO_PARTNER_ID'] ?? '';
}
