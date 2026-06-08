//방장 블루투스 연결 화면
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/core/auth/auth_user_id.dart';
import 'package:frontend/data/colors.dart';
import 'package:frontend/features/bluetooth/screens/bluetooth_connect.dart';
import 'package:frontend/features/bluetooth/services/ble_proximity_service.dart';
import 'package:frontend/features/bluetooth/services/bluetooth_readiness_service.dart';
import 'package:frontend/features/bluetooth/services/proximity_match_api.dart';

/// 예약 생성자(방장)용 BLE 근접 매칭 화면.
class BluetoothLeaderScreen extends StatefulWidget {
  final int reservationId;

  const BluetoothLeaderScreen({
    super.key,
    required this.reservationId,
  });

  @override
  State<BluetoothLeaderScreen> createState() => _BluetoothLeaderScreenState();
}

class _BluetoothLeaderScreenState extends State<BluetoothLeaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _elapsedTimer;
  Timer? _presenceTimer;
  Timer? _nearbyPollTimer;
  Timer? _scanRestartTimer;

  bool _isSubmitting = false;
  bool _isBluetoothReady = false;
  int _elapsedSeconds = 0;
  int _bleNearbyCount = 0;
  int? _leaderId;
  final Set<int> _selectedUserIds = {};
  List<ProximityNearbyUser> _nearbyUsers = [];
  String? _nearbyError;

  bool get _canSubmit =>
      _isBluetoothReady && !_isSubmitting && _selectedUserIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startElapsedTimer();
    _loadLeaderId();
    _initBluetoothMonitoring();
    _startPresenceLoop();
    _startNearbyPolling();
  }

  Future<void> _loadLeaderId() async {
    final token = await AuthTokenStorage.getToken();
    if (!mounted || token == null) return;
    setState(() => _leaderId = parseUserIdFromToken(token));
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _startPresenceLoop() {
    ProximityMatchApi.sendPresence(widget.reservationId);
    _presenceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ProximityMatchApi.sendPresence(widget.reservationId);
    });
  }

  void _startNearbyPolling() {
    _refreshNearbyUsers();
    _nearbyPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshNearbyUsers();
    });
  }

  Future<void> _refreshNearbyUsers() async {
    final result = await ProximityMatchApi.fetchNearbyUsers(widget.reservationId);
    if (!mounted) return;
    setState(() {
      _nearbyUsers = result.users;
      _nearbyError = result.error;
      _selectedUserIds.removeWhere(
        (id) => !result.users.any((user) => user.userId == id),
      );
    });
  }

  Future<void> _initBluetoothMonitoring() async {
    await _refreshBluetoothState(requestPermission: true);
    _adapterSubscription = FlutterBluePlus.adapterState.listen((_) {
      _refreshBluetoothState(requestPermission: false);
    });
  }

  Future<void> _refreshBluetoothState({required bool requestPermission}) async {
    final ready = await BluetoothReadinessService.ensureReady(
      requestPermission: requestPermission,
    );
    if (!mounted) return;

    setState(() => _isBluetoothReady = ready);

    if (ready) {
      await _startNearbyScan();
    } else {
      await _stopNearbyScan();
      if (mounted) setState(() => _bleNearbyCount = 0);
    }
  }

  Future<void> _startNearbyScan() async {
    await _stopNearbyScan();
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;

        final bleUsers = <NearbyBleUser>[];
        for (final result in results) {
          final parsed = BleProximityService.parseScanResult(
            result,
            expectedReservationId: widget.reservationId,
            excludeUserId: _leaderId,
          );
          if (parsed != null) {
            bleUsers.add(parsed);
          }
        }

        setState(() {
          _bleNearbyCount = BleProximityService.mergeUsers(bleUsers).length;
        });
      });
      _scanRestartTimer?.cancel();
      _scanRestartTimer = Timer.periodic(const Duration(seconds: 14), (_) async {
        if (!mounted || !_isBluetoothReady) return;
        try {
          final scanning = await FlutterBluePlus.isScanning.first;
          if (!scanning) {
            await FlutterBluePlus.startScan(
              timeout: const Duration(seconds: 15),
              androidScanMode: AndroidScanMode.lowLatency,
            );
          }
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) setState(() => _bleNearbyCount = 0);
    }
  }

  Future<void> _stopNearbyScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  String get _elapsedLabel {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleUser(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _onConfirmGroup() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);
    try {
      final ok = await ProximityMatchApi.confirmGroup(
        reservationId: widget.reservationId,
        participantIds: _selectedUserIds.toList(),
      );
      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 확정 요청에 실패했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _presenceTimer?.cancel();
    _nearbyPollTimer?.cancel();
    _scanRestartTimer?.cancel();
    _adapterSubscription?.cancel();
    _stopNearbyScan();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Material(
                  color: AuthColors.white,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RadarWavePainter(
                      _animationController.value,
                      waveColor: AuthColors.bluePrimary,
                    ),
                    child: Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AuthColors.bluePrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bluetooth_searching,
                          color: AuthColors.whiteText,
                          size: 44,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Text(
              '동승자 선택 (방장)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AuthColors.blackText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'RSSI ${BleProximityService.rssiThresholdDbm}dBm 이상 · 선택 ${_selectedUserIds.length}명',
              style: const TextStyle(
                fontSize: 12,
                color: AuthColors.grayText,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AuthColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: '감지 동승자',
                          value: '${_nearbyUsers.length}명',
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Color(0xFFE8E8E8),
                      ),
                      Expanded(
                        child: _StatCell(
                          label: 'BLE 신호',
                          value: '$_bleNearbyCount',
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Color(0xFFE8E8E8),
                      ),
                      Expanded(
                        child: _StatCell(
                          label: '지난 시간',
                          value: _elapsedLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _nearbyUsers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _nearbyError ??
                              '주변 동승자가 아직 감지되지 않았습니다.\n'
                              '팀원이 팀원용 매칭 화면에 들어와 있어야 목록에 표시됩니다.\n'
                              '(서로 다른 계정·기기에서 테스트해 주세요)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AuthColors.grayText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _nearbyUsers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = _nearbyUsers[index];
                        final selected = _selectedUserIds.contains(user.userId);
                        return Material(
                          color: selected
                              ? AuthColors.blueSecondary.withValues(alpha: 0.35)
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _toggleUser(user.userId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: selected
                                        ? AuthColors.bluePrimary
                                        : AuthColors.grayText,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      user.displayLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'ID ${user.userId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AuthColors.grayText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _onConfirmGroup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.bluePrimary,
                    foregroundColor: AuthColors.whiteText,
                    disabledBackgroundColor:
                        AuthColors.bluePrimary.withValues(alpha: 0.45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AuthColors.whiteText,
                          ),
                        )
                      : Text(
                          _selectedUserIds.isEmpty
                              ? '동승자를 선택하세요'
                              : '선택 ${_selectedUserIds.length}명 확정 요청',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AuthColors.grayText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AuthColors.bluePrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
