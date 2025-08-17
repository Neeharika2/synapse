import 'package:flutter/foundation.dart';
import '../models/idea_model.dart';
import '../services/api_service.dart';

class IdeaProvider with ChangeNotifier {
  List<Idea> _ideas = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = true;

  List<Idea> get ideas => _ideas;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> fetchIdeas({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _currentPage = 1;
      _ideas = [];
      _hasMore = true;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.getIdeas(page: _currentPage, limit: 10);

      if (response['success']) {
        final List<dynamic> ideasData = response['data']['ideas'] ?? [];
        final pagination = response['data']['pagination'] ?? {};

        final List<Idea> newIdeas =
            ideasData.map((ideaJson) => Idea.fromJson(ideaJson)).toList();

        if (refresh) {
          _ideas = newIdeas;
        } else {
          _ideas.addAll(newIdeas);
        }

        _currentPage = pagination['currentPage'] ?? _currentPage;
        _totalPages = pagination['totalPages'] ?? 1;
        _hasMore = _currentPage <= _totalPages;
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to fetch ideas';
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Network error. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createIdea({
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await ApiService.createIdea(
        title: title,
        description: description,
        tags: tags,
      );

      if (response['success']) {
        final newIdea = Idea.fromJson(response['data']['idea']);
        _ideas.insert(0, newIdea);
        return true;
      } else {
        _hasError = true;
        _errorMessage = response['error'] ?? 'Failed to create idea';
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

  Future<bool> toggleLike(String ideaId) async {
    try {
      final response = await ApiService.toggleIdeaLike(ideaId);

      if (response['success']) {
        final ideaIndex = _ideas.indexWhere((idea) => idea.id == ideaId);
        if (ideaIndex != -1) {
          final updatedIdea = Idea.fromJson(response['data']['idea']);
          _ideas[ideaIndex] = updatedIdea;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}
