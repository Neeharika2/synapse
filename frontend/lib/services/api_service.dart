import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/idea_model.dart';
import '../models/project_model.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.193.205:3000/api';
  static const String serverUrl = 'http://192.168.193.205:3000';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Store token
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Get headers with auth token
  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Login with better error handling
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      print('🚀 Attempting login to: $baseUrl/auth/login');
      print('📧 Email: $email');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(timeoutDuration);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Cannot connect to server. Please check your internet connection and server status.',
      };
    } on HttpException catch (e) {
      print('❌ HTTP Exception: ${e.message}');
      return {'success': false, 'error': 'HTTP error: ${e.message}'};
    } on FormatException catch (e) {
      print('❌ Format Exception: ${e.message}');
      return {
        'success': false,
        'error': 'Invalid response format from server.',
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Register with better error handling
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      print('🚀 Attempting registration to: $baseUrl/auth/register');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(timeoutDuration);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Cannot connect to server. Please check your internet connection.',
      };
    } catch (e) {
      print('❌ Registration error: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Test server connectivity
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      print('🔍 Testing server connection to: $serverUrl/health');

      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print('✅ Server response: ${response.statusCode}');
      print('📡 Server body: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Server is reachable'};
      } else {
        return {
          'success': false,
          'error': 'Server returned ${response.statusCode}',
        };
      }
    } on SocketException catch (e) {
      print('❌ Cannot reach server: ${e.message}');
      return {
        'success': false,
        'error':
            'Cannot reach server at 192.168.193.205:3000. Please check:\n'
            '• Server is running (npm run dev)\n'
            '• IP address 192.168.193.205 is correct\n'
            '• Both devices are on same network\n'
            '• Server firewall allows port 3000\n'
            '• Try: curl http://192.168.193.205:3000/health',
      };
    } on TimeoutException catch (e) {
      print('❌ Connection timeout: $e');
      return {
        'success': false,
        'error': 'Connection timeout. Server may be slow or unreachable.',
      };
    } on http.ClientException catch (e) {
      print('❌ Client Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Network error: ${e.message}\n\n'
            'This usually means:\n'
            '• Server is not running\n'
            '• Wrong IP address\n'
            '• Network connectivity issue\n'
            '• CORS/firewall blocking the request',
      };
    } catch (e) {
      print('❌ Connection test failed: $e');
      return {'success': false, 'error': 'Connection test failed: $e'};
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: await getHeaders(),
    );

    return _handleResponse(response);
  }

  // Setup profile
  static Future<Map<String, dynamic>> setupProfile({
    required String branch,
    required String yearOfStudy,
    required List<String> skills,
    String? bio,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/setup'),
      headers: await getHeaders(),
      body: json.encode({
        'branch': branch,
        'yearOfStudy': yearOfStudy,
        'skills': skills,
        'bio': bio,
      }),
    );

    return _handleResponse(response);
  }

  // Get projects
  static Future<Map<String, dynamic>> getProjects({
    String? search,
    String? status,
    int? page,
    int? limit,
  }) async {
    try {
      String url = '$baseUrl/projects';
      bool firstParam = true;

      if (search != null && search.isNotEmpty) {
        url += '${firstParam ? '?' : '&'}search=${Uri.encodeComponent(search)}';
        firstParam = false;
      }

      if (status != null && status.isNotEmpty) {
        url += '${firstParam ? '?' : '&'}status=$status';
        firstParam = false;
      }

      if (page != null && limit != null) {
        url += '${firstParam ? '?' : '&'}page=$page&limit=$limit';
      }

      print('🚀 Fetching projects from: $url');

      final response = await http
          .get(Uri.parse(url), headers: await getHeaders())
          .timeout(timeoutDuration);

      print('📡 Projects response status: ${response.statusCode}');
      print('📡 Projects response body length: ${response.body.length}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get projects error: $e');
      return {'success': false, 'error': 'Failed to fetch projects: $e'};
    }
  }

  // Create project
  static Future<Map<String, dynamic>> createProject({
    required String title,
    required String description,
    required List<String> requiredSkills,
    int? maxMembers,
    String? visibility,
  }) async {
    try {
      print('🚀 Creating project: $title');

      final response = await http
          .post(
            Uri.parse('$baseUrl/projects'),
            headers: await getHeaders(),
            body: json.encode({
              'title': title,
              'description': description,
              'requiredSkills': requiredSkills,
              'maxMembers': maxMembers,
              'visibility': visibility,
            }),
          )
          .timeout(timeoutDuration);

      print('📡 Create project response status: ${response.statusCode}');
      print('📡 Create project response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Create project error: $e');
      return {'success': false, 'error': 'Failed to create project: $e'};
    }
  }

  // Get ideas
  static Future<Map<String, dynamic>> getIdeas({int? page, int? limit}) async {
    String url = '$baseUrl/ideas';
    if (page != null && limit != null) {
      url += '?page=$page&limit=$limit';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await getHeaders(),
    );

    return _handleResponse(response);
  }

  // Create idea
  static Future<Map<String, dynamic>> createIdea({
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ideas'),
      headers: await getHeaders(),
      body: json.encode({
        'title': title,
        'description': description,
        'tags': tags,
      }),
    );

    return _handleResponse(response);
  }

  // Like/Unlike an idea
  static Future<Map<String, dynamic>> toggleIdeaLike(String ideaId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ideas/$ideaId/like'),
      headers: await getHeaders(),
    );

    return _handleResponse(response);
  }

  // Get project details with pending requests
  static Future<Map<String, dynamic>> getProjectDetails(
    String projectId,
  ) async {
    try {
      print('🚀 Fetching project details: $projectId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/$projectId'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Project details response status: ${response.statusCode}');

      final result = _handleResponse(response);

      // If successful, also fetch pending join requests for this project
      if (result['success'] && result['data'] != null) {
        try {
          final requestsResponse = await http
              .get(
                Uri.parse('$baseUrl/projects/$projectId/requests'),
                headers: await getHeaders(),
              )
              .timeout(timeoutDuration);

          print(
            '📡 Join requests response status: ${requestsResponse.statusCode}',
          );

          final requestsResult = _handleResponse(requestsResponse);
          if (requestsResult['success'] && requestsResult['data'] != null) {
            // Add the pending requests to the project data
            result['data']['pending_requests'] = requestsResult['data'] ?? [];
          }
        } catch (e) {
          print('❌ Error fetching join requests: $e');
          // Don't fail the whole request if just the requests part fails
        }
      }

      return result;
    } catch (e) {
      print('❌ Get project details error: $e');
      return {'success': false, 'error': 'Failed to fetch project details: $e'};
    }
  }

  // Leave project
  static Future<Map<String, dynamic>> leaveProject(String projectId) async {
    try {
      print('🚀 Leaving project: $projectId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/projects/$projectId/leave'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Leave project response status: ${response.statusCode}');
      print('📡 Leave project response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Cannot connect to server. Please check your internet connection.',
      };
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      return {
        'success': false,
        'error': 'Request timed out. Server may be unavailable.',
      };
    } catch (e) {
      print('❌ Leave project error: $e');
      return {'success': false, 'error': 'Failed to leave project: $e'};
    }
  }

  // Request to join project with optional message
  static Future<Map<String, dynamic>> joinProject(
    String projectId, {
    String? message,
  }) async {
    try {
      print('🚀 Requesting to join project: $projectId');

      final Map<String, dynamic> requestBody = {};
      if (message != null && message.isNotEmpty) {
        requestBody['message'] = message;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/projects/$projectId/join'),
            headers: await getHeaders(),
            body: json.encode(requestBody),
          )
          .timeout(timeoutDuration);

      print('📡 Join project response status: ${response.statusCode}');
      print('📡 Join project response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Join project error: $e');
      return {
        'success': false,
        'error': 'Failed to request joining project: $e',
      };
    }
  }

  // Respond to a join request (accept/reject)
  static Future<Map<String, dynamic>> respondToJoinRequest(
    String projectId,
    String requestId,
    bool accept,
  ) async {
    try {
      final action = accept ? 'accept' : 'reject';
      print('🚀 ${action}ing join request: $requestId for project: $projectId');

      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/projects/$projectId/requests/$requestId/$action',
            ),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Respond to join request error: $e');
      return {'success': false, 'error': 'Failed to process join request: $e'};
    }
  }

  // Get all pending join requests for projects owned by the user
  static Future<Map<String, dynamic>> getProjectRequests() async {
    try {
      print('🚀 Fetching project join requests');

      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/requests'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Join requests response status: ${response.statusCode}');
      print('📡 Join requests response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get join requests error: $e');
      return {'success': false, 'error': 'Failed to fetch join requests: $e'};
    }
  }

  // Get all pending join requests for projects owned by the user (received requests)
  static Future<Map<String, dynamic>> getReceivedRequests() async {
    try {
      print('🚀 Fetching received join requests');

      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/requests/received'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Received requests response status: ${response.statusCode}');
      print('📡 Received requests response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get received requests error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch received join requests: $e',
      };
    }
  }

  // Get all join requests sent by the current user (sent requests)
  static Future<Map<String, dynamic>> getSentRequests() async {
    try {
      print('🚀 Fetching sent join requests');

      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/requests/sent'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Sent requests response status: ${response.statusCode}');
      print('📡 Sent requests response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get sent requests error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch sent join requests: $e',
      };
    }
  }

  // Cancel a join request
  static Future<Map<String, dynamic>> cancelJoinRequest(
    String requestId,
  ) async {
    try {
      print('🚀 Cancelling join request: $requestId');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/projects/requests/$requestId'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Cancel request response status: ${response.statusCode}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Cancel join request error: $e');
      return {'success': false, 'error': 'Failed to cancel join request: $e'};
    }
  }

  // Get created projects
  static Future<Map<String, dynamic>> getCreatedProjects() async {
    try {
      print('🚀 Fetching created projects from: $baseUrl/projects/created');

      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/created'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Created projects response status: ${response.statusCode}');
      print('📡 Created projects response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Server connection failed. Please check your network and server status.',
        'projects': [], // Return empty array to prevent null errors
      };
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      return {
        'success': false,
        'error': 'Request timed out. Server may be slow or unreachable.',
        'projects': [], // Return empty array to prevent null errors
      };
    } catch (e) {
      print('❌ Get created projects error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch created projects: $e',
        'projects': [], // Return empty array to prevent null errors
      };
    }
  }

  // Get joined projects
  static Future<Map<String, dynamic>> getJoinedProjects() async {
    try {
      print('🚀 Fetching joined projects from: $baseUrl/projects/joined');

      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/joined'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      print('📡 Joined projects response status: ${response.statusCode}');
      print('📡 Joined projects response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException catch (e) {
      print('❌ Socket Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Server connection failed. Please check your network and server status.',
        'projects': [], // Return empty array to prevent null errors
      };
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      return {
        'success': false,
        'error': 'Request timed out. Server may be slow or unreachable.',
        'projects': [], // Return empty array to prevent null errors
      };
    } catch (e) {
      print('❌ Get joined projects error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch joined projects: $e',
        'projects': [], // Return empty array to prevent null errors
      };
    }
  }

  // Enhanced response handler
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        print('❌ Server error ${response.statusCode}: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Failed to parse response: $e');
      return {
        'success': false,
        'error': 'Invalid response from server',
        'statusCode': response.statusCode,
      };
    }
  }
}
