import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _setLoading(true);
    try {
      final isValid = await _apiService.verifyToken();
      if (isValid) {
        _user = await _apiService.getCurrentUser();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(
    String username,
    String password,
    String organizationName,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.login(
        username,
        password,
        organizationName,
      );

      if (response['user'] != null) {
        _user = User.fromJson(response['user']);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String organizationName,
    String? firstName,
    String? lastName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userData = {
        'username': username,
        'email': email,
        'password': password,
        'organization_name': organizationName,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      };

      final response = await _apiService.register(userData);

      if (response['user'] != null) {
        _user = User.fromJson(response['user']);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiService.logout();
      _user = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final profileData = <String, dynamic>{};
      if (firstName != null) profileData['first_name'] = firstName;
      if (lastName != null) profileData['last_name'] = lastName;
      if (email != null) profileData['email'] = email;

      if (profileData.isNotEmpty) {
        _user = await _apiService.updateProfile(profileData);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
}
