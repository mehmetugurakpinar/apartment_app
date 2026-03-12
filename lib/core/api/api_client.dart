import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final Box _authBox = Hive.box('auth');

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _authBox.get('accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the original request
            final opts = error.requestOptions;
            opts.headers['Authorization'] =
                'Bearer ${_authBox.get('accessToken')}';
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = _authBox.get('refreshToken');
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
      )).post('/auth/refresh', data: {'refresh_token': refreshToken});

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await _authBox.put('accessToken', data['access_token']);
        await _authBox.put('refreshToken', data['refresh_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Dio get dio => _dio;

  // Auth
  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/auth/register', data: data);

  Future<Response> login(Map<String, dynamic> data) =>
      _dio.post('/auth/login', data: data);

  Future<Response> logout(String refreshToken) =>
      _dio.post('/auth/logout', data: {'refresh_token': refreshToken});

  Future<Response> getProfile() => _dio.get('/auth/me');

  Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.patch('/auth/me', data: data);

  // Buildings
  Future<Response> createBuilding(Map<String, dynamic> data) =>
      _dio.post('/buildings', data: data);

  Future<Response> getBuilding(String id) => _dio.get('/buildings/$id');

  Future<Response> getBuildingDashboard(String id) =>
      _dio.get('/buildings/$id/dashboard');

  Future<Response> getUnits(String buildingId) =>
      _dio.get('/buildings/$buildingId/units');

  Future<Response> createUnit(String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/units', data: data);

  Future<Response> updateUnit(
          String buildingId, String unitId, Map<String, dynamic> data) =>
      _dio.patch('/buildings/$buildingId/units/$unitId', data: data);

  Future<Response> deleteUnit(String buildingId, String unitId) =>
      _dio.delete('/buildings/$buildingId/units/$unitId');

  Future<Response> getResidents(String buildingId) =>
      _dio.get('/buildings/$buildingId/residents');

  Future<Response> getMembers(String buildingId) =>
      _dio.get('/buildings/$buildingId/members');

  Future<Response> removeMember(String buildingId, String userId) =>
      _dio.delete('/buildings/$buildingId/members/$userId');

  // Financial
  Future<Response> getDuesPlans(String buildingId) =>
      _dio.get('/buildings/$buildingId/dues');

  Future<Response> createDuesPlan(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/dues', data: data);

  Future<Response> payDues(
          String buildingId, String planId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/dues/$planId/pay', data: data);

  Future<Response> getDuesReport(String buildingId,
          {int? month, int? year}) =>
      _dio.get('/buildings/$buildingId/dues/report',
          queryParameters: {'month': month, 'year': year});

  Future<Response> getExpenses(String buildingId,
          {int page = 1, int limit = 20}) =>
      _dio.get('/buildings/$buildingId/expenses',
          queryParameters: {'page': page, 'limit': limit});

  Future<Response> createExpense(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/expenses', data: data);

  Future<Response> updateDuesPlan(
          String buildingId, String planId, Map<String, dynamic> data) =>
      _dio.patch('/buildings/$buildingId/dues/$planId', data: data);

  Future<Response> deleteDuesPlan(String buildingId, String planId) =>
      _dio.delete('/buildings/$buildingId/dues/$planId');

  Future<Response> updateExpense(
          String buildingId, String expenseId, Map<String, dynamic> data) =>
      _dio.patch('/buildings/$buildingId/expenses/$expenseId', data: data);

  Future<Response> deleteExpense(String buildingId, String expenseId) =>
      _dio.delete('/buildings/$buildingId/expenses/$expenseId');

  // Maintenance
  Future<Response> getMaintenanceRequests(String buildingId,
          {int page = 1, int limit = 20}) =>
      _dio.get('/buildings/$buildingId/maintenance',
          queryParameters: {'page': page, 'limit': limit});

  Future<Response> createMaintenanceRequest(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/maintenance', data: data);

  Future<Response> updateMaintenanceRequest(
          String buildingId, String reqId, Map<String, dynamic> data) =>
      _dio.patch('/buildings/$buildingId/maintenance/$reqId', data: data);

  Future<Response> getVendors(String buildingId) =>
      _dio.get('/buildings/$buildingId/vendors');

  Future<Response> createVendor(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/vendors', data: data);

  Future<Response> updateVendor(
          String buildingId, String vendorId, Map<String, dynamic> data) =>
      _dio.patch('/buildings/$buildingId/vendors/$vendorId', data: data);

  Future<Response> deleteVendor(String buildingId, String vendorId) =>
      _dio.delete('/buildings/$buildingId/vendors/$vendorId');

  Future<Response> deleteMaintenanceRequest(String buildingId, String reqId) =>
      _dio.delete('/buildings/$buildingId/maintenance/$reqId');

  // Notifications
  Future<Response> getNotifications({int page = 1, int limit = 20}) =>
      _dio.get('/notifications',
          queryParameters: {'page': page, 'limit': limit});

  Future<Response> markNotificationRead(String id) =>
      _dio.patch('/notifications/$id/read');

  Future<Response> sendAnnouncement(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/announcements', data: data);

  Future<Response> getNotificationPreferences() =>
      _dio.get('/notifications/preferences');

  Future<Response> updateNotificationPreferences(
          Map<String, dynamic> data) =>
      _dio.patch('/notifications/preferences', data: data);

  // Forum
  Future<Response> getForumCategories(String buildingId) =>
      _dio.get('/buildings/$buildingId/forum/categories');

  Future<Response> getForumPosts(String buildingId,
          {String? categoryId, int page = 1, int limit = 20}) =>
      _dio.get('/buildings/$buildingId/forum/posts', queryParameters: {
        'page': page,
        'limit': limit,
        if (categoryId != null) 'category_id': categoryId,
      });

  Future<Response> createForumPost(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/forum/posts', data: data);

  Future<Response> getForumPost(String buildingId, String postId) =>
      _dio.get('/buildings/$buildingId/forum/posts/$postId');

  Future<Response> addForumComment(
          String buildingId, String postId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/forum/posts/$postId/comments',
          data: data);

  Future<Response> voteForumPost(
          String buildingId, String postId, int value) =>
      _dio.post('/buildings/$buildingId/forum/posts/$postId/vote',
          data: {'value': value});

  // Timeline
  Future<Response> getTimelineFeed({int page = 1, int limit = 20}) =>
      _dio.get('/timeline',
          queryParameters: {'page': page, 'limit': limit});

  Future<Response> createTimelinePost(Map<String, dynamic> data) =>
      _dio.post('/timeline', data: data);

  Future<Response> likeTimelinePost(String postId) =>
      _dio.post('/timeline/$postId/like');

  Future<Response> addTimelineComment(
          String postId, Map<String, dynamic> data) =>
      _dio.post('/timeline/$postId/comments', data: data);

  Future<Response> votePoll(String pollId, String optionId) =>
      _dio.post('/timeline/polls/$pollId/vote',
          data: {'option_id': optionId});

  Future<Response> getNearbyPosts(
          double lat, double lng, double radius) =>
      _dio.get('/timeline/nearby',
          queryParameters: {'lat': lat, 'lng': lng, 'radius': radius});

  // Social / Follow
  Future<Response> searchUsers(String query) =>
      _dio.get('/users/search', queryParameters: {'q': query});

  Future<Response> followUser(String userId) =>
      _dio.post('/users/$userId/follow');

  Future<Response> unfollowUser(String userId) =>
      _dio.delete('/users/$userId/follow');

  Future<Response> getFollowers(String userId,
          {int page = 1, int limit = 20}) =>
      _dio.get('/users/$userId/followers',
          queryParameters: {'page': page, 'limit': limit});

  Future<Response> getFollowing(String userId,
          {int page = 1, int limit = 20}) =>
      _dio.get('/users/$userId/following',
          queryParameters: {'page': page, 'limit': limit});

  // Repost
  Future<Response> repostPost(String postId) =>
      _dio.post('/timeline/$postId/repost');

  Future<Response> unrepostPost(String postId) =>
      _dio.delete('/timeline/$postId/repost');

  // Invitations
  Future<Response> inviteUser(
          String buildingId, Map<String, dynamic> data) =>
      _dio.post('/buildings/$buildingId/invitations', data: data);

  Future<Response> getInvitations(String buildingId) =>
      _dio.get('/buildings/$buildingId/invitations');

  Future<Response> acceptInvitation(String token) =>
      _dio.post('/auth/accept-invitation', data: {'token': token});

  // User buildings
  Future<Response> getUserBuildings() => _dio.get('/buildings');

  // Change password
  Future<Response> changePassword(Map<String, dynamic> data) =>
      _dio.patch('/auth/password', data: data);
}
