import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothReadinessService {

  /// 블루투스 사용권한이 있는지 확인
  static Future<bool> hasPermissions() async {
    //IOS는 권한 요청 필요 없음
    if (Platform.isIOS) {
      return true;
    }
    //Android인 경우만 권한 확인
    if (!Platform.isAndroid) {
      return false;
    }
    final connect = await Permission.bluetoothConnect.status; //블루투스 연결 권한 저장
    final scan = await Permission.bluetoothScan.status; //블루투스 스캔 권한 저장
    return connect.isGranted && scan.isGranted; //블루투스 연결 권한과 블루투스 스캔 권한이 모두 있는지 리턴
  }

  /// 권한 요청
  static Future<bool> requestPermissions() async {
    //IOS는 권한 요청 필요 없음
    if (Platform.isIOS) {
      return true;
    }
    //Android인 경우만 권한 요청
    if (!Platform.isAndroid) {
      return false;
    }
    //블루투스 연결 권한과 블루투스 스캔 권한 요청
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    //블루투스 연결 권한과 블루투스 스캔 권한이 모두 있는지 리턴
    return statuses.values.every((status) => status.isGranted);
  }

  /// 블루투스가 켜져 있는지 확인
  static Future<bool> isBluetoothOn() async {
    //IOS와 Android가 아닌 경우 블루투스 켜져 있는지 확인 불가
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    //블루투스 켜져 있는지 확인
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
    //블루투스 켜져 있는지 확인
    return isBluetoothOn();
  }
  static Future<bool> turnOnBluetooth({bool requestPermission = false}) async {
    var granted = await hasPermissions();
  if (!granted && requestPermission) {
    granted = await requestPermissions();
  }
  if (!granted) {
    return false;
  }
  // 권한 승인 직후: 블루투스가 꺼져 있으면 켜기 요청 (Android만)
  if (Platform.isAndroid && !await isBluetoothOn()) {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
    }
  }
  return isBluetoothOn();
  }
}
