import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/circle_summary.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    this.currentCircle,
  });

  final AppUser user;
  final CircleSummary? currentCircle;
}

class AuthService {
  AuthService({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _authStorage = authStorage ?? AuthStorage(),
        _apiClient =
            apiClient ?? ApiClient(authStorage: authStorage ?? AuthStorage());

  final AuthStorage _authStorage;
  final ApiClient _apiClient;

  Future<AuthSession> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    String phone,
  ) async {
    final response = await _apiClient.post(
      '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'phone': phone,
      },
    );

    return _persistAuthResponse(response);
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _apiClient.post(
      '/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    return _persistAuthResponse(response);
  }

  Future<AuthSession> getCurrentUser() async {
    final response = await _apiClient.get(
      '/user',
      requiresAuth: true,
    );

    final userMap = _extractUserMap(response);
    final user = AppUser.fromJson(userMap);
    final currentCircle = _extractCircle(response, user, userMap);

    await _authStorage.saveUser(user);
    if (currentCircle != null) {
      await _authStorage.saveCurrentCircle(currentCircle);
    }

    return AuthSession(
      user: user,
      currentCircle: currentCircle,
    );
  }

  Future<AppUser> uploadProfilePhoto(XFile photo) async {
    final response = await _apiClient.postMultipartFile(
      '/user/photo',
      fieldName: 'photo',
      file: photo,
      requiresAuth: true,
    );

    final userMap = Map<String, dynamic>.from(_extractUserMap(response));
    final data = response['data'];
    final nestedPhotoUrl =
        data is Map<String, dynamic> ? data['photo_url'] : null;
    final photoUrl = (response['photo_url'] ?? nestedPhotoUrl)?.toString();
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      userMap['photo_url'] = photoUrl;
    }

    final cachedUser = await _authStorage.readUser();
    userMap['phone'] ??= cachedUser?.phone;

    final user = AppUser.fromJson(userMap);
    await _authStorage.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(
        '/logout',
        body: <String, dynamic>{},
        requiresAuth: true,
      );
    } finally {
      await _authStorage.clearSession();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _authStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<AppUser?> getCachedUser() {
    return _authStorage.readUser();
  }

  Future<void> clearLocalSession() {
    return _authStorage.clearSession();
  }

  Future<AuthSession> _persistAuthResponse(Map<String, dynamic> response) async {
    final token = _extractToken(response);
    final userMap = _extractUserMap(response);
    final user = AppUser.fromJson(userMap);
    final currentCircle = _extractCircle(response, user, userMap);

    await _authStorage.saveToken(token);
    await _authStorage.saveUser(user);
    if (currentCircle != null) {
      await _authStorage.saveCurrentCircle(currentCircle);
    }

    return AuthSession(
      user: user,
      currentCircle: currentCircle,
    );
  }

  String _extractToken(Map<String, dynamic> response) {
    final directToken = response['token'];
    if (directToken != null && directToken.toString().isNotEmpty) {
      return directToken.toString();
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nestedToken = data['token'];
      if (nestedToken != null && nestedToken.toString().isNotEmpty) {
        return nestedToken.toString();
      }
    }

    throw ApiException('Response auth tidak valid.');
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic> response) {
    final directUser = response['user'];
    if (directUser is Map<String, dynamic>) {
      return directUser;
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) {
        return nestedUser;
      }

      if (data.containsKey('id') && data.containsKey('email')) {
        return data;
      }
    }

    if (response.containsKey('id') && response.containsKey('email')) {
      return response;
    }

    throw ApiException('Response user tidak valid.');
  }

  CircleSummary? _extractCircle(
    Map<String, dynamic> response,
    AppUser user,
    Map<String, dynamic> userMap,
  ) {
    final directCircle =
        _findCircleMap(response) ??
        _findCircleMap(response['data']) ??
        _findCircleMap(userMap);

    if (directCircle != null) {
      return CircleSummary.fromJson(directCircle);
    }

    final referalCode = _firstString(
      userMap['referal_code'],
      userMap['referral_code'],
      userMap['invite_code'],
      user.referalCode,
    );
    final circleId = _parseNullableInt(
      userMap['circle_id'] ??
          userMap['current_circle_id'] ??
          userMap['default_circle_id'] ??
          user.circleId,
    );

    if (circleId == null || referalCode == null || referalCode.isEmpty) {
      return null;
    }

    return CircleSummary(
      id: circleId,
      name: userMap['circle_name']?.toString(),
      ownerId: user.id,
      referalCode: referalCode,
      createdAt: '',
      updatedAt: '',
    );
  }

  Map<String, dynamic>? _findCircleMap(dynamic value) {
    final map = _asMap(value);
    if (map == null) {
      return null;
    }

    for (final key in const [
      'current_circle',
      'active_circle',
      'default_circle',
      'own_circle',
      'circle',
      'joined_circle',
      'my_circle',
    ]) {
      final nested = _findCircleMap(map[key]);
      if (nested != null) {
        return nested;
      }
    }

    if (_looksLikeCircle(map)) {
      return map;
    }

    return null;
  }

  bool _looksLikeCircle(Map<String, dynamic> map) {
    if (map.containsKey('email')) {
      return false;
    }

    final code = _firstString(
      map['referal_code'],
      map['referral_code'],
      map['invite_code'],
    );
    final id = _parseNullableInt(map['id'] ?? map['circle_id']);

    return id != null && code != null && code.isNotEmpty;
  }

  String? _firstString(Object? first, [Object? second, Object? third, Object? fourth]) {
    for (final value in [first, second, third, fourth]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  int? _parseNullableInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    return null;
  }
}
