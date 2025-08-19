import 'dart:convert';
import '../services/api_service.dart';

class ChatApiService {
  static Future<Map<String, dynamic>> getChatHistory(String projectId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/chat';
      final headers = await ApiService.getHeaders();

      final response = await ApiService.httpClient
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch chat history: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error fetching chat history: $e');
      return {
        'success': false,
        'error': 'Error fetching chat history: $e',
        'data': [],
      };
    }
  }
}
