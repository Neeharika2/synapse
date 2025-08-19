import 'dart:convert';
import '../services/api_service.dart';
import '../models/meeting_model.dart';

class MeetingsApiService {
  static Future<Map<String, dynamic>> getProjectMeetings(
      String projectId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/meetings';
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
          'error': 'Failed to fetch meetings: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error fetching meetings: $e');
      return {
        'success': false,
        'error': 'Error fetching meetings: $e',
        'data': [],
      };
    }
  }

  static Future<Map<String, dynamic>> createMeeting(
      ProjectMeeting meeting) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url =
          '${ApiService.baseUrl}/projects/${meeting.projectId}/meetings';
      final headers = await ApiService.getHeaders();

      final response = await httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(meeting.toJson()),
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to create meeting: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error creating meeting: $e');
      return {'success': false, 'error': 'Error creating meeting: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateMeeting(
      ProjectMeeting meeting) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url =
          '${ApiService.baseUrl}/projects/${meeting.projectId}/meetings/${meeting.id}';
      final headers = await ApiService.getHeaders();

      final response = await httpClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(meeting.toJson()),
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to update meeting: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error updating meeting: $e');
      return {'success': false, 'error': 'Error updating meeting: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteMeeting(
    String projectId,
    String meetingId,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url =
          '${ApiService.baseUrl}/projects/$projectId/meetings/$meetingId';
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
          'error': 'Failed to delete meeting: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error deleting meeting: $e');
      return {'success': false, 'error': 'Error deleting meeting: $e'};
    }
  }

  // Mock implementation to avoid errors
  static final httpClient = ApiService.httpClient;
}
