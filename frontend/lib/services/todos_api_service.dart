import 'dart:convert';
import '../services/api_service.dart';
import '../models/todo_model.dart';

class TodosApiService {
  static Future<Map<String, dynamic>> getProjectTodos(String projectId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/todos';
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
          'error': 'Failed to fetch todos: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error fetching todos: $e');
      return {
        'success': false,
        'error': 'Error fetching todos: $e',
        'data': [],
      };
    }
  }

  static Future<Map<String, dynamic>> createTodo(Todo todo) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/${todo.projectId}/todos';
      final headers = await ApiService.getHeaders();

      final response = await httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(todo.toJson()),
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to create todo: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error creating todo: $e');
      return {'success': false, 'error': 'Error creating todo: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateTodo(Todo todo) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url =
          '${ApiService.baseUrl}/projects/${todo.projectId}/todos/${todo.id}';
      final headers = await ApiService.getHeaders();

      final response = await httpClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(todo.toJson()),
          )
          .timeout(ApiService.timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Failed to update todo: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error updating todo: $e');
      return {'success': false, 'error': 'Error updating todo: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTodo(
    String projectId,
    String todoId,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final url = '${ApiService.baseUrl}/projects/$projectId/todos/$todoId';
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
          'error': 'Failed to delete todo: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error deleting todo: $e');
      return {'success': false, 'error': 'Error deleting todo: $e'};
    }
  }

  // Mock implementation to avoid errors
  static final httpClient = ApiService.httpClient;
}
