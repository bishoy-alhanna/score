import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/dashboard.dart';

class ApiService {
  // Use local CORS proxy to avoid browser CORS issues
  static const String baseUrl = 'http://localhost:3001';
  static const String apiPrefix = '/api';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService() : _dio = Dio(), _storage = const FlutterSecureStorage() {
    _dio.options.baseUrl = baseUrl + apiPrefix;
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Configure for web requests - remove incorrect CORS headers
    // CORS headers should be set by the server, not the client

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  // Connectivity test method
  Future<bool> testConnectivity() async {
    try {
      print('Testing connectivity to: ${_dio.options.baseUrl}/health');
      final response = await _dio.get('/health');
      print('Connectivity test response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Connectivity test failed: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      print('Connectivity test error: $e');
      return false;
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> login(
    String username,
    String password,
    String organizationName,
  ) async {
    try {
      print('Attempting login to: ${_dio.options.baseUrl}/auth/login');
      print('Login data: username=$username, org=$organizationName');

      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'organization_name': organizationName,
        },
      );

      print('Login response status: ${response.statusCode}');
      print('Login response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        // Backend returns 'token' not 'access_token'
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
          print('Token saved successfully: ${token.substring(0, 20)}...');
        }
        return data;
      }
      throw Exception('Login failed: ${response.statusMessage}');
    } on DioException catch (e) {
      print('Dio Exception: ${e.type}');
      print('Error message: ${e.message}');
      print('Response: ${e.response?.data}');

      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout - cannot reach backend at score.al-hanna.com',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Response timeout - backend may be slow');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Network error - cannot reach backend at score.al-hanna.com. Check internet connection or try refreshing.',
        );
      } else if (e.response != null) {
        final errorData = e.response!.data;
        if (errorData is Map && errorData['detail'] != null) {
          throw Exception('Login failed: ${errorData['detail']}');
        }
        throw Exception('Login failed: ${e.response!.statusMessage}');
      } else {
        throw Exception('Network error - cannot reach backend at $baseUrl');
      }
    } catch (e) {
      print('Unexpected error: $e');
      throw Exception('Login error: $e');
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      print(
        'Attempting registration to: ${_dio.options.baseUrl}/auth/register',
      );
      print('Registration data: $userData');

      final response = await _dio.post('/auth/register', data: userData);

      print('Registration response status: ${response.statusCode}');
      print('Registration response data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        // Backend returns 'token' not 'access_token'
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
          print('Registration token saved successfully');
        }
        return data;
      }
      throw Exception('Registration failed: ${response.statusMessage}');
    } on DioException catch (e) {
      print('Registration Dio Exception: ${e.type}');
      print('Registration error message: ${e.message}');
      print('Registration response: ${e.response?.data}');

      if (e.response != null) {
        final errorData = e.response!.data;
        if (errorData is Map && errorData['detail'] != null) {
          throw Exception('Registration failed: ${errorData['detail']}');
        }
        throw Exception('Registration failed: ${e.response!.statusMessage}');
      } else {
        throw Exception('Network error - cannot reach backend at $baseUrl');
      }
    } catch (e) {
      print('Unexpected registration error: $e');
      throw Exception('Registration error: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> verifyToken() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      final response = await _dio.get('/auth/verify');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // User profile methods
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to get user: ${e.message}');
    }
  }

  Future<User> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _dio.put('/auth/profile', data: profileData);
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update profile: ${e.message}');
    }
  }

  // Dashboard data methods
  Future<UserStats> getUserStats() async {
    try {
      final response = await _dio.get('/dashboard/stats');
      return UserStats.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to get user stats: ${e.message}');
    }
  }

  Future<List<WeeklyData>> getWeeklyData({int weeks = 12}) async {
    try {
      final response = await _dio.get(
        '/dashboard/weekly-data',
        queryParameters: {'weeks': weeks},
      );

      final List<dynamic> data = response.data;
      return data.map((item) => WeeklyData.fromJson(item)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to get weekly data: ${e.message}');
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/dashboard/leaderboard',
        queryParameters: {'limit': limit},
      );

      final List<dynamic> data = response.data;
      return data.map((item) => LeaderboardEntry.fromJson(item)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to get leaderboard: ${e.message}');
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get('/categories');

      final List<dynamic> data = response.data;
      return data.map((item) => Category.fromJson(item)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to get categories: ${e.message}');
    }
  }

  Future<List<Group>> getGroups() async {
    try {
      final response = await _dio.get('/groups');

      final List<dynamic> data = response.data;
      return data.map((item) => Group.fromJson(item)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to get groups: ${e.message}');
    }
  }

  Future<List<Organization>> getOrganizations() async {
    try {
      final response = await _dio.get('/organizations');

      final List<dynamic> data = response.data;
      return data.map((item) => Organization.fromJson(item)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to get organizations: ${e.message}');
    }
  }

  // Self-reporting methods
  Future<Map<String, dynamic>> submitSelfReport({
    required String categoryId,
    required double score,
    String? description,
    String? groupId,
  }) async {
    try {
      final response = await _dio.post(
        '/scores/self-report',
        data: {
          'category_id': categoryId,
          'score': score,
          'description': description,
          'group_id': groupId,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to submit report: ${e.message}');
    }
  }
}
