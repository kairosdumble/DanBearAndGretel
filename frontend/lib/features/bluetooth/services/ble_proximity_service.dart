import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 약속 장소 BLE 근접 감지용 공통 서비스.
class BleProximityService {
  BleProximityService._();

  /// -60dBm보다 약한(더 작은) 신호는 지나가는 행인으로 간주합니다.
  static const int rssiThresholdDbm = -60;

  /// iOS 광고 이름 길이 제한을 고려한 포맷: D{reservationId}U{userId}
  static final RegExp _shortNamePattern = RegExp(r'^D(\d+)U(\d+)$');
  static final RegExp _legacyNamePattern = RegExp(r'^DGR-(\d+)-(\d+)$');

  static bool passesRssiFilter(int rssi) => rssi >= rssiThresholdDbm;

  static String buildAdvertiseName({
    required int reservationId,
    required int userId,
  }) {
    return 'D${reservationId}U$userId';
  }

  static NearbyBleUser? parseScanResult(
    ScanResult result, {
    required int expectedReservationId,
    int? excludeUserId,
  }) {
    if (!passesRssiFilter(result.rssi)) {
      return null;
    }

    final candidates = <String>[
      result.advertisementData.advName,
      result.device.platformName,
      result.device.advName,
    ];

    for (final name in candidates) {
      final parsed = _parseName(
        name,
        expectedReservationId: expectedReservationId,
        excludeUserId: excludeUserId,
        rssi: result.rssi,
        deviceId: result.device.remoteId.str,
      );
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static NearbyBleUser? _parseName(
    String name, {
    required int expectedReservationId,
    int? excludeUserId,
    required int rssi,
    required String deviceId,
  }) {
    final trimmed = name.trim();
    RegExpMatch? match = _shortNamePattern.firstMatch(trimmed);
    match ??= _legacyNamePattern.firstMatch(trimmed);
    if (match == null) return null;

    final reservationId = int.tryParse(match.group(1) ?? '');
    final userId = int.tryParse(match.group(2) ?? '');
    if (reservationId == null || userId == null) return null;
    if (reservationId != expectedReservationId) return null;
    if (excludeUserId != null && userId == excludeUserId) return null;

    return NearbyBleUser(
      userId: userId,
      reservationId: reservationId,
      rssi: rssi,
      deviceId: deviceId,
    );
  }

  static Map<int, NearbyBleUser> mergeUsers(Iterable<NearbyBleUser> users) {
    final merged = <int, NearbyBleUser>{};
    for (final user in users) {
      final existing = merged[user.userId];
      if (existing == null || user.rssi > existing.rssi) {
        merged[user.userId] = user;
      }
    }
    return merged;
  }
}

class NearbyBleUser {
  final int userId;
  final int reservationId;
  final int rssi;
  final String deviceId;
  final String? name;

  const NearbyBleUser({
    required this.userId,
    required this.reservationId,
    required this.rssi,
    required this.deviceId,
    this.name,
  });

  String get displayLabel => name?.trim().isNotEmpty == true
      ? name!.trim()
      : '사용자 $userId';
}
