import '../models/circle_member.dart';
import '../models/circle_summary.dart';
import 'api_client.dart';

class CircleActionResult {
  const CircleActionResult({required this.message, required this.circle});

  final String message;
  final CircleSummary circle;
}

class CircleService {
  CircleService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // --- FUNGSI BARU: Membuat circle baru ke backend ---
  Future<CircleActionResult> createCircle(String name) async {
    final response = await _apiClient.post(
      '/circles',
      body: {'name': name},
      requiresAuth: true,
    );

    return _parseResult(response);
  }

  // --- Mengirim lokasi perangkat saat ini ke backend ---
  Future<void> updateMyLocation(
    double latitude,
    double longitude,
    int battery,
  ) async {
    await _apiClient.post(
      '/location',
      body: {'latitude': latitude, 'longitude': longitude, 'battery': battery},
      requiresAuth: true,
    );
  }

  // --- Mengambil seluruh data lokasi anggota di satu circle ---
  Future<List<dynamic>> getCircleLocations(int circleId) async {
    final response = await _apiClient.get(
      '/circles/$circleId/locations',
      requiresAuth: true,
    );

    if (response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  Future<CircleActionResult> joinCircle(String referalCode) async {
    final response = await _apiClient.post(
      '/circles/join',
      body: {'referal_code': referalCode},
      requiresAuth: true,
    );

    return _parseResult(response);
  }

  Future<CircleActionResult> leaveCircle() async {
    final response = await _apiClient.post(
      '/circles/leave',
      body: <String, dynamic>{},
      requiresAuth: true,
    );

    return _parseResult(response);
  }

  Future<List<CircleMember>> getCircleMembers(int circleId) async {
    final response = await _apiClient.get(
      '/circles/$circleId/members',
      requiresAuth: true,
    );

    final rawMembers =
        _extractMembersList(response['data']) ??
        _extractMembersList(response['members']) ??
        _extractMembersList(response);
    if (rawMembers is! List) {
      throw ApiException('Response members tidak valid.');
    }

    return rawMembers
        .whereType<Map>()
        .map(
          (item) => CircleMember.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  List<dynamic>? _extractMembersList(dynamic value) {
    if (value is List) {
      return value;
    }

    final map = _asMap(value);
    if (map == null) {
      return null;
    }

    final members = map['members'];
    if (members is List) {
      return members;
    }

    final nestedData = map['data'];
    if (nestedData is List) {
      return nestedData;
    }

    return null;
  }

  CircleActionResult _parseResult(Map<String, dynamic> response) {
    final rawData =
        _extractCircleMap(response['data']) ??
        _extractCircleMap(response['circle']) ??
        _extractCircleMap(response);

    if (rawData == null) {
      throw ApiException('Response circle tidak valid.');
    }

    return CircleActionResult(
      message: (response['message'] ?? 'Circle updated').toString(),
      circle: CircleSummary.fromJson(rawData),
    );
  }

  Map<String, dynamic>? _extractCircleMap(dynamic value) {
    final map = _asMap(value);
    if (map == null) {
      return null;
    }

    final nestedCircle =
        _asMap(map['circle']) ??
        _asMap(map['current_circle']) ??
        _asMap(map['active_circle']) ??
        _asMap(map['default_circle']) ??
        _asMap(map['own_circle']);

    if (nestedCircle != null) {
      return nestedCircle;
    }

    if (map.containsKey('id') || map.containsKey('circle_id')) {
      return map;
    }

    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return null;
  }
}
