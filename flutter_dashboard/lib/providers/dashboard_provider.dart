import 'package:flutter/foundation.dart';
import '../models/dashboard.dart' as models;
import '../models/user.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  models.UserStats? _userStats;
  List<models.WeeklyData> _weeklyData = [];
  List<models.LeaderboardEntry> _leaderboard = [];
  List<models.Category> _categories = [];
  List<models.Group> _groups = [];
  List<Organization> _organizations = [];

  bool _isLoading = false;
  String? _error;

  // Getters
  models.UserStats? get userStats => _userStats;
  List<models.WeeklyData> get weeklyData => List.unmodifiable(_weeklyData);
  List<models.LeaderboardEntry> get leaderboard =>
      List.unmodifiable(_leaderboard);
  List<models.LeaderboardEntry> get weeklyLeaderboard =>
      List.unmodifiable(_leaderboard);
  List<models.Category> get categories => List.unmodifiable(_categories);

  bool get hasData =>
      _userStats != null || _weeklyData.isNotEmpty || _leaderboard.isNotEmpty;
  List<models.Group> get groups => _groups;
  List<Organization> get organizations => _organizations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all dashboard data
  Future<void> loadDashboardData() async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        loadUserStats(),
        loadWeeklyData(),
        loadLeaderboard(),
        loadCategories(),
        loadGroups(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Individual data loading methods
  Future<void> loadUserStats() async {
    try {
      _userStats = await _apiService.getUserStats();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadWeeklyData({int weeks = 12}) async {
    try {
      _weeklyData = await _apiService.getWeeklyData(weeks: weeks);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadLeaderboard({int limit = 50}) async {
    try {
      _leaderboard = await _apiService.getLeaderboard(limit: limit);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _apiService.getCategories();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadGroups() async {
    try {
      _groups = await _apiService.getGroups();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadOrganizations() async {
    try {
      _organizations = await _apiService.getOrganizations();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Self-reporting
  Future<bool> submitSelfReport({
    required String categoryId,
    required double score,
    String? description,
    String? groupId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.submitSelfReport(
        categoryId: categoryId,
        score: score,
        description: description,
        groupId: groupId,
      );

      // Refresh data after successful submission
      await Future.wait([loadUserStats(), loadWeeklyData(), loadLeaderboard()]);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Refresh methods
  Future<void> refresh() async {
    await loadDashboardData();
  }

  Future<void> refreshStats() async {
    await loadUserStats();
  }

  Future<void> refreshLeaderboard() async {
    await loadLeaderboard();
  }

  Future<void> refreshWeeklyData() async {
    await loadWeeklyData();
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Get category by ID
  models.Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // Get group by ID
  models.Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((group) => group.id == groupId);
    } catch (e) {
      return null;
    }
  }

  // Get organization by ID
  Organization? getOrganizationById(String organizationId) {
    try {
      return _organizations.firstWhere((org) => org.id == organizationId);
    } catch (e) {
      return null;
    }
  }
}
