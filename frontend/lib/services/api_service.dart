import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Updated to include multiple potential server URLs
  static const List<String> serverUrls = [
    'http://192.168.193.205:3000', // Primary server
    'http://10.0.2.2:3000', // Android emulator localhost
    'http://localhost:3000', // Direct localhost
    'http://127.0.0.1:3000' // Explicit loopback
  ];

  // Current active server URL (will be set dynamically)
  static String _activeServerUrl = serverUrls[0];
  static String get baseUrl => '$_activeServerUrl/api';
  static String get serverUrl => _activeServerUrl;

  static const Duration timeoutDuration = Duration(seconds: 30);
  static const Duration connectionTestTimeout = Duration(seconds: 5);

  // Add this property to make it available to other services
  static final http.Client httpClient = http.Client();

  // Initialize API service by testing connections
  static Future<bool> initialize() async {
    for (String url in serverUrls) {
      if (await _testServerUrl(url)) {
        _activeServerUrl = url;
        print('🌐 Connected to server at: $_activeServerUrl');
        return true;
      }
    }
    print('❌ Failed to connect to any server endpoint');
    return false;
  }

  // Test if a specific server URL is reachable
  static Future<bool> _testServerUrl(String url) async {
    try {
      print('🔍 Testing server connection to: $url/health');
      final response = await http.get(
        Uri.parse('$url/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(connectionTestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Server at $url not reachable: $e');
      return false;
    }
  }

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

      // First ensure we have a working server connection
      if (!await initialize()) {
        return {
          'success': false,
          'error':
              'Cannot connect to any server. Please check your network settings and server status.',
        };
      }

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
            'Cannot connect to server at $_activeServerUrl. Please check your internet connection and server status.',
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
    } on http.ClientException catch (e) {
      print('❌ Client Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Connection error: ${e.message}\n\nPlease verify the server is running and accessible.',
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

      // First ensure we have a working server connection
      if (!await initialize()) {
        return {
          'success': false,
          'error':
              'Cannot connect to any server. Please check your network settings and server status.',
        };
      }

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
            'Cannot connect to server at $_activeServerUrl. Please check your internet connection.',
      };
    } on http.ClientException catch (e) {
      print('❌ Client Exception: ${e.message}');
      return {
        'success': false,
        'error':
            'Connection error: ${e.message}\n\nPlease verify the server is running and accessible.',
      };
    } catch (e) {
      print('❌ Registration error: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Test server connectivity - Enhanced version
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      bool anyServerReachable = false;
      List<String> errorMessages = [];

      // Try all server URLs to find any that work
      for (String url in serverUrls) {
        try {
          print('🔍 Testing server connection to: $url/health');
          final response = await http.get(
            Uri.parse('$url/health'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(connectionTestTimeout);

          print('📡 Server response from $url: ${response.statusCode}');

          if (response.statusCode == 200) {
            _activeServerUrl = url; // Update the active URL to working one
            anyServerReachable = true;
            return {
              'success': true,
              'message': 'Server is reachable at $url',
              'activeUrl': url
            };
          } else {
            errorMessages.add('Server at $url returned ${response.statusCode}');
          }
        } on SocketException catch (e) {
          errorMessages.add('Cannot reach server at $url: ${e.message}');
        } on TimeoutException catch (_) {
          errorMessages.add('Connection timeout for server at $url');
        } on http.ClientException catch (e) {
          errorMessages.add('Client error for $url: ${e.message}');
        } catch (e) {
          errorMessages.add('Error testing $url: $e');
        }
      }

      if (anyServerReachable) {
        return {
          'success': true,
          'message': 'Server is reachable',
          'activeUrl': _activeServerUrl
        };
      } else {
        return {
          'success': false,
          'error': 'Cannot reach any server endpoint.\n\n'
              'Please check:\n'
              '• Server is running (npm run dev)\n'
              '• Network connectivity\n'
              '• Firewall settings\n'
              '• Correct IP address\n\n'
              'Detailed errors:\n${errorMessages.join('\n')}',
        };
      }
    } catch (e) {
      print('❌ Connection test failed: $e');
      return {'success': false, 'error': 'Connection test failed: $e'};
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      // Ensure connection before proceeding
      if (!await initialize()) {
        return {
          'success': false,
          'error':
              'Cannot connect to server. Please check your network settings.',
        };
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/profile'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'error': 'Connection error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get profile: ${e.toString()}',
      };
    }
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

      final result = _handleResponse(response);

      // Handle the new response format
      if (result['success'] && result['data'] != null) {
        return {'success': true, 'data': result['data']};
      } else {
        return result;
      }
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
      print(
          '📝 Request details - projectId: $projectId, requestId: $requestId, action: $action');

      // Validate inputs to ensure they are not empty or malformed
      if (projectId.isEmpty || requestId.isEmpty) {
        print('❌ Invalid input: projectId or requestId is empty');
        return {
          'success': false,
          'error': 'Invalid request: Missing project ID or request ID'
        };
      }

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

      final result = _handleResponse(response);
      print('🔍 Parsed result: $result');

      // Ensure we return the expected format
      if (result['success'] && result['projects'] != null) {
        return {'success': true, 'projects': result['projects']};
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to fetch created projects',
          'projects': [],
        };
      }
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

      final result = _handleResponse(response);
      print('🔍 Parsed result: $result');

      // Ensure we return the expected format
      if (result['success'] && result['projects'] != null) {
        return {'success': true, 'projects': result['projects']};
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to fetch joined projects',
          'projects': [],
        };
      }
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
        'projects': [],
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
      final dynamic rawData = json.decode(response.body);
      print('🔍 Parsed response data type: ${rawData.runtimeType}');
      print('🔍 Parsed response data: $rawData');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // If the response already has a 'success' field, return it as is
        if (rawData is Map && rawData.containsKey('success')) {
          print('✅ Response has success field, returning as-is');
          return Map<String, dynamic>.from(rawData);
        }
        // If it's an array, wrap it in our standard format
        if (rawData is List) {
          print('✅ Response is array, wrapping in standard format');
          return {'success': true, 'data': rawData};
        }
        // Otherwise, wrap it in our standard format
        print('✅ Response is object, wrapping in standard format');
        return {'success': true, 'data': rawData};
      } else {
        print(
          '❌ Server error ${response.statusCode}: ${rawData is Map ? rawData['error'] : 'Unknown error'}',
        );
        return {
          'success': false,
          'error': rawData is Map
              ? (rawData['error'] ?? 'Server error (${response.statusCode})')
              : 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Failed to parse response: $e');
      print('❌ Response body: ${response.body}');
      return {
        'success': false,
        'error': 'Invalid response from server',
        'statusCode': response.statusCode,
      };
    }
  }
}

// End of API service
// Note: Project feature-specific API services are defined in their own files

// Todos API
class TodosApiService {
  static const String baseUrl = 'http://192.168.193.205:3000/api';
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

  // Enhanced response handler
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final dynamic rawData = json.decode(response.body);
      print('🔍 Parsed response data type: ${rawData.runtimeType}');
      print('🔍 Parsed response data: $rawData');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // If the response already has a 'success' field, return it as is
        if (rawData is Map && rawData.containsKey('success')) {
          print('✅ Response has success field, returning as-is');
          return Map<String, dynamic>.from(rawData);
        }
        // If it's an array, wrap it in our standard format
        if (rawData is List) {
          print('✅ Response is array, wrapping in standard format');
          return {'success': true, 'data': rawData};
        }
        // Otherwise, wrap it in our standard format
        print('✅ Response is object, wrapping in standard format');
        return {'success': true, 'data': rawData};
      } else {
        print(
          '❌ Server error ${response.statusCode}: ${rawData is Map ? rawData['error'] : 'Unknown error'}',
        );
        return {
          'success': false,
          'error': rawData is Map
              ? (rawData['error'] ?? 'Server error (${response.statusCode})')
              : 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Failed to parse response: $e');
      print('❌ Response body: ${response.body}');
      return {
        'success': false,
        'error': 'Invalid response from server',
        'statusCode': response.statusCode,
      };
    }
  }

  // Get project todos
  static Future<Map<String, dynamic>> getProjectTodos(String projectId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/$projectId/todos'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to fetch todos: $e'};
    }
  }

  // Create todo
  static Future<Map<String, dynamic>> createTodo(
    String projectId,
    Map<String, dynamic> todoData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/projects/$projectId/todos'),
            headers: await getHeaders(),
            body: json.encode(todoData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to create todo: $e'};
    }
  }

  // Update todo
  static Future<Map<String, dynamic>> updateTodo(
    String projectId,
    String todoId,
    Map<String, dynamic> todoData,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/projects/$projectId/todos/$todoId'),
            headers: await getHeaders(),
            body: json.encode(todoData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to update todo: $e'};
    }
  }

  // Delete todo
  static Future<Map<String, dynamic>> deleteTodo(
    String projectId,
    String todoId,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/projects/$projectId/todos/$todoId'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete todo: $e'};
    }
  }
}

// Files API
class FilesApiService {
  static const String baseUrl = 'http://192.168.193.205:3000/api';
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

  // Enhanced response handler
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final dynamic rawData = json.decode(response.body);
      print('🔍 Parsed response data type: ${rawData.runtimeType}');
      print('🔍 Parsed response data: $rawData');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // If the response already has a 'success' field, return it as is
        if (rawData is Map && rawData.containsKey('success')) {
          print('✅ Response has success field, returning as-is');
          return Map<String, dynamic>.from(rawData);
        }
        // If it's an array, wrap it in our standard format
        if (rawData is List) {
          print('✅ Response is array, wrapping in standard format');
          return {'success': true, 'data': rawData};
        }
        // Otherwise, wrap it in our standard format
        print('✅ Response is object, wrapping in standard format');
        return {'success': true, 'data': rawData};
      } else {
        print(
          '❌ Server error ${response.statusCode}: ${rawData is Map ? rawData['error'] : 'Unknown error'}',
        );
        return {
          'success': false,
          'error': rawData is Map
              ? (rawData['error'] ?? 'Server error (${response.statusCode})')
              : 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Failed to parse response: $e');
      print('❌ Response body: ${response.body}');
      return {
        'success': false,
        'error': 'Invalid response from server',
        'statusCode': response.statusCode,
      };
    }
  }

  // Get project files
  static Future<Map<String, dynamic>> getProjectFiles(String projectId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/$projectId/files'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to fetch files: $e'};
    }
  }

  // Upload file
  static Future<Map<String, dynamic>> uploadFile(
    String projectId,
    Map<String, dynamic> fileData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/projects/$projectId/files'),
            headers: await getHeaders(),
            body: json.encode(fileData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload file: $e'};
    }
  }

  // Delete file
  static Future<Map<String, dynamic>> deleteFile(
    String projectId,
    String fileId,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/projects/$projectId/files/$fileId'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete file: $e'};
    }
  }
}

// Meetings API
class MeetingsApiService {
  static const String baseUrl = 'http://192.168.193.205:3000/api';
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

  // Enhanced response handler
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final dynamic rawData = json.decode(response.body);
      print('🔍 Parsed response data type: ${rawData.runtimeType}');
      print('🔍 Parsed response data: $rawData');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // If the response already has a 'success' field, return it as is
        if (rawData is Map && rawData.containsKey('success')) {
          print('✅ Response has success field, returning as-is');
          return Map<String, dynamic>.from(rawData);
        }
        // If it's an array, wrap it in our standard format
        if (rawData is List) {
          print('✅ Response is array, wrapping in standard format');
          return {'success': true, 'data': rawData};
        }
        // Otherwise, wrap it in our standard format
        print('✅ Response is object, wrapping in standard format');
        return {'success': true, 'data': rawData};
      } else {
        print(
          '❌ Server error ${response.statusCode}: ${rawData is Map ? rawData['error'] : 'Unknown error'}',
        );
        return {
          'success': false,
          'error': rawData is Map
              ? (rawData['error'] ?? 'Server error (${response.statusCode})')
              : 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Failed to parse response: $e');
      print('❌ Response body: ${response.body}');
      return {
        'success': false,
        'error': 'Invalid response from server',
        'statusCode': response.statusCode,
      };
    }
  }

  // Get project meetings
  static Future<Map<String, dynamic>> getProjectMeetings(
    String projectId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/projects/$projectId/meetings'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to fetch meetings: $e'};
    }
  }

  // Create meeting
  static Future<Map<String, dynamic>> createMeeting(
    String projectId,
    Map<String, dynamic> meetingData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/projects/$projectId/meetings'),
            headers: await getHeaders(),
            body: json.encode(meetingData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to create meeting: $e'};
    }
  }

  // Update meeting
  static Future<Map<String, dynamic>> updateMeeting(
    String projectId,
    String meetingId,
    Map<String, dynamic> meetingData,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/projects/$projectId/meetings/$meetingId'),
            headers: await getHeaders(),
            body: json.encode(meetingData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to update meeting: $e'};
    }
  }

  // Delete meeting
  static Future<Map<String, dynamic>> deleteMeeting(
    String projectId,
    String meetingId,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/projects/$projectId/meetings/$meetingId'),
            headers: await getHeaders(),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete meeting: $e'};
    }
  }
}
