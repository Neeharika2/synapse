import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        final response = await ApiService.getProfile();
        if (response['success']) {
          _isAuthenticated = true;
          _user = response['data'];
        } else {
          await ApiService.clearToken();
          _isAuthenticated = false;
        }
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _error = null;
      notifyListeners();

      final response = await ApiService.login(email, password);

      if (response['success']) {
        await ApiService.setToken(response['data']['token']);
        _isAuthenticated = true;
        _user = response['data']['user'];
        notifyListeners();
        return true;
      } else {
        _error = response['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      _error = null;
      notifyListeners();

      final response = await ApiService.register(name, email, password);

      if (response['success']) {
        await ApiService.setToken(response['data']['token']);
        _isAuthenticated = true;
        _user = response['data']['user'];
        notifyListeners();
        return true;
      } else {
        _error = response['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _isAuthenticated = false;
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
