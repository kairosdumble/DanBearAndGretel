import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// 블루투스 권한·전원 상태를 확인합니다.
class BluetoothReadinessService {
  static Future<bool> hasPermissions() async {
    if (Platform.isIOS) {
      return true;
    }
    if (!Platform.isAndroid) {
      return false;
    }

    final connect = await Permission.bluetoothConnect.status;
    final scan = await Permission.bluetoothScan.status;
    return connect.isGranted && scan.isGranted;
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return true;
    }
    if (!Platform.isAndroid) {
      return false;
    }

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  static Future<bool> isBluetoothOn() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// 권한 요청(필요 시) 후 블루투스가 켜져 있으면 true.
  static Future<bool> ensureReady({bool requestPermission = false}) async {
    var granted = await hasPermissions();
    if (!granted && requestPermission) {
      granted = await requestPermissions();
    }
    if (!granted) {
      return false;
    }

    return isBluetoothOn();
  }
}
