import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class FilesApiService {
  static Future<Map<String, dynamic>> getProjectFiles(String projectId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/files';
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
          'error': 'Failed to fetch files: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error fetching files: $e');
      return {
        'success': false,
        'error': 'Error fetching files: $e',
        'data': [],
      };
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
    String projectId,
    File file,
    String fileName,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/files';
      final headers = await ApiService.getHeaders();

      // Remove content-type header for multipart request
      headers.remove('Content-Type');

      var request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ));

      final streamedResponse =
          await request.send().timeout(ApiService.timeoutDuration);

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to upload file: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error uploading file: $e');
      return {'success': false, 'error': 'Error uploading file: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteFile(
    String projectId,
    String fileId,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/files/$fileId';
      final headers = await ApiService.getHeaders();

      final response = await httpClient
          .delete(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': 'Failed to delete file: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error deleting file: $e');
      return {'success': false, 'error': 'Error deleting file: $e'};
    }
  }

  // Mock implementation to avoid errors
  static final httpClient = ApiService.httpClient;
}
