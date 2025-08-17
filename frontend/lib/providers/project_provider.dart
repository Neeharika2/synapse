import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../services/api_service.dart';

class ProjectProvider with ChangeNotifier {
  List<Project> _projects = [];
  List<Project> _myProjects = [];
  Project? _currentProject;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = true;

  List<Project> get projects => _projects;
  List<Project> get myProjects => _myProjects;
  Project? get currentProject => _currentProject;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> fetchProjects({
    bool refresh = false,
    String? search,
    String? status,
  }) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _currentPage = 1;
      _projects = [];
      _hasMore = true;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.getProjects(
        search: search,
        status: status,
        page: _currentPage,
        limit: 10,
      );

      if (response['success']) {
        final List<dynamic> projectsData = response['data']['projects'] ?? [];
        final pagination = response['data']['pagination'] ?? {};

        final List<Project> newProjects =
            projectsData
                .map((projectJson) => Project.fromJson(projectJson))
                .toList();

        if (refresh) {
          _projects = newProjects;
        } else {
          _projects.addAll(newProjects);
        }

        _currentPage = pagination['currentPage'] ?? _currentPage;
        _totalPages = pagination['totalPages'] ?? 1;
        _hasMore = _currentPage <= _totalPages;
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to fetch projects';
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyProjects({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.getProjects(
        status: 'my',
        page: 1,
        limit: 50,
      );

      if (response['success']) {
        final List<dynamic> projectsData = response['data']['projects'] ?? [];

        _myProjects =
            projectsData
                .map((projectJson) => Project.fromJson(projectJson))
                .toList();
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to fetch your projects';
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> getProjectDetails(String projectId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final response = await ApiService.getProjectDetails(projectId);

      if (response['success'] && response['data'] != null) {
        final projectData = response['data'];

        // Add pending requests to the project data
        if (projectData['pending_requests'] != null) {
          projectData['pending_requests'] = projectData['pending_requests'];
        } else {
          projectData['pending_requests'] = [];
        }

        _currentProject = Project.fromJson(projectData);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Failed to load project details';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinProject(String projectId) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.joinProject(projectId);

      if (response['success']) {
        final updatedProject = Project.fromJson(response['data']['project']);

        // Update project in the list
        final projectIndex = _projects.indexWhere((p) => p.id == projectId);
        if (projectIndex != -1) {
          _projects[projectIndex] = updatedProject;
        }

        // Update current project if it's the one being joined
        if (_currentProject?.id == projectId) {
          _currentProject = updatedProject;
        }

        // Add to my projects if not already there
        if (!_myProjects.any((p) => p.id == projectId)) {
          _myProjects.add(updatedProject);
        }

        return true;
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to join project';
        return false;
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> leaveProject(String projectId) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.leaveProject(projectId);

      if (response['success']) {
        // Remove from my projects since user left
        _myProjects.removeWhere((p) => p.id == projectId);

        // Update the project in the main list if it exists
        final projectIndex = _projects.indexWhere((p) => p.id == projectId);
        if (projectIndex != -1 &&
            response['data'] != null &&
            response['data']['project'] != null) {
          _projects[projectIndex] = Project.fromJson(
            response['data']['project'],
          );
        }

        // Clear current project if it's the one being left
        if (_currentProject?.id == projectId) {
          _currentProject = null;
        }

        return true;
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to leave project';
        return false;
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCurrentProject() {
    _currentProject = null;
    notifyListeners();
  }

  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}
