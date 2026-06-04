import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frontend/data/colors.dart';
import 'package:frontend/features/bluetooth/services/bluetooth_readiness_service.dart';
import 'package:frontend/features/bluetooth/services/proximity_match_api.dart';

class BluetoothMatchingScreen extends StatefulWidget {
  final int reservationId;
  const BluetoothMatchingScreen({
    super.key,
    required this.reservationId,
  });

  @override
  State<BluetoothMatchingScreen> createState() =>
      _BluetoothMatchingScreenState();
}

class _BluetoothMatchingScreenState extends State<BluetoothMatchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _elapsedTimer;

  bool _isSubmitting = false;
  bool _isBluetoothReady = false;
  int _nearbyCount = 0;
  int _elapsedSeconds = 0;

  bool get _canCompleteMatch => _isBluetoothReady && !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startElapsedTimer();
    _initBluetoothMonitoring();
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
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
      if (mounted) setState(() => _nearbyCount = 0);
    }
  }

  Future<void> _startNearbyScan() async {
    await _stopNearbyScan();
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
      );
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        final uniqueDevices = results
            .map((result) => result.device.remoteId.str)
            .toSet()
            .length;
        setState(() => _nearbyCount = uniqueDevices);
      });
    } catch (_) {
      if (mounted) setState(() => _nearbyCount = 0);
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

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _adapterSubscription?.cancel();
    _stopNearbyScan();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onConfirmMatch() async {
    if (!_canCompleteMatch) return;

    setState(() => _isSubmitting = true);
    try {
      final ok = await ProximityMatchApi.confirm(widget.reservationId);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매칭 확정에 실패했습니다. 다시 시도해 주세요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _canCompleteMatch ? '매칭 완료' : '검색 중...';

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
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
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
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AuthColors.bluePrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AuthColors.bluePrimary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bluetooth,
                          color: AuthColors.whiteText,
                          size: 56,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Text(
              '주변 동승자 검색 중',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AuthColors.blackText,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AuthColors.bluePrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '블루투스를 통해 주변 동승자를 찾고 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AuthColors.grayText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
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
                          label: '주변 동승자 수',
                          value: '$_nearbyCount명',
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canCompleteMatch ? _onConfirmMatch : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.bluePrimary,
                    foregroundColor: AuthColors.whiteText,
                    disabledBackgroundColor:
                        AuthColors.bluePrimary.withValues(alpha: 0.45),
                    disabledForegroundColor:
                        AuthColors.whiteText.withValues(alpha: 0.8),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bluetooth, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              buttonLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AuthColors.bluePrimary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '블루투스는 위치 정보를 수집하지 않으며, '
                        '검색 데이터는 기기에만 저장됩니다.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AuthColors.grayText,
                        ),
                      ),
                    ),
                  ],
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AuthColors.grayText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AuthColors.bluePrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class RadarWavePainter extends CustomPainter {
  final double progress;
  final Color waveColor;

  RadarWavePainter(this.progress, {required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const centerIconRadius = 60.0;
    const maxWaveRadius = centerIconRadius + 46;

    for (int i = 3; i >= 1; i--) {
      final currentProgress = (progress + (i * 0.33)) % 1.0;
      final radius =
          centerIconRadius + (maxWaveRadius - centerIconRadius) * currentProgress;
      final opacity = 1.0 - currentProgress;

      final ringPaint = Paint()
        ..color = waveColor.withValues(alpha: opacity * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveColor != waveColor;
  }
}
