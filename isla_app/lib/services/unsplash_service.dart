import 'package:dio/dio.dart';
import '../config/app_config.dart';

class UnsplashPhoto {
  final String url;
  final String photographerName;
  final String photographerUrl;

  const UnsplashPhoto({
    required this.url,
    required this.photographerName,
    required this.photographerUrl,
  });
}

class UnsplashService {
  static final Dio _dio = Dio();

  static Future<UnsplashPhoto?> fetchPhoto(String keyword) async {
    if (keyword.trim().isEmpty || !AppConfig.hasUnsplashKey) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.unsplash.com/search/photos',
        queryParameters: {
          'query': keyword,
          'per_page': 1,
          'orientation': 'landscape',
        },
        options: Options(
          headers: {
            'Authorization': 'Client-ID ${AppConfig.unsplashAccessKey}',
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final results = response.data?['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final photo = results.first as Map<String, dynamic>;
      final urls = photo['urls'] as Map<String, dynamic>?;
      final user = photo['user'] as Map<String, dynamic>?;
      final links = user?['links'] as Map<String, dynamic>?;

      return UnsplashPhoto(
        url: (urls?['small'] ?? urls?['regular'] ?? '').toString(),
        photographerName: (user?['name'] ?? 'Unknown').toString(),
        photographerUrl: (links?['html'] ?? 'https://unsplash.com').toString(),
      );
    } catch (e) {
      print('[ISLA] Unsplash fetch failed: $e');
      return null;
    }
  }
}
