import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> load() async {
    await dotenv.load(fileName: "assets/.env");
  }

  static String get apiKey => dotenv.get('API_KEY');
  static String get baseUrl => dotenv.get('BASE_URL');
  static bool get debugMode => dotenv.get('DEBUG_MODE') == 'true';

  static int get zegoAppID => int.parse(dotenv.get('ZEGO_APP_ID'));
  static String get zegoAppSign => dotenv.get('ZEGO_APP_SIGN');
  static String get zegoServerSecret => dotenv.get('ZEGO_SERVER_SECRET');

  static String get flutterwavePKey => dotenv.get('FLUTTERWAVE_PKEY');
  static String get flutterwaveSKey => dotenv.get('FLUTTERWAVE_SKEY');
  static String get flutterwaveEKey => dotenv.get('FLUTTERWAVE_EKEY');

  static String get awsBucketName => dotenv.get('AWS_BUCKET_NAME');
  static String get awsRegion => dotenv.get('AWS_REGION');
  static String get awsAccessKey => dotenv.get('AWS_ACCESS_KEY');
  static String get awsSecretKey => dotenv.get('AWS_SECRET_KEY');
}

// Or using the config class
// String baseUrl = Env.baseUrl;