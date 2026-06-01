import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frontend/features/bluetooth/services/bluetooth_readiness_service.dart';
import 'package:frontend/features/bluetooth/services/proximity_match_api.dart';

class BluetoothMatchingScreen extends StatefulWidget {
  final int reservationId;
  const BluetoothMatchingScreen({
    super.key,
    required this.reservationId, //현재 예약 ID를 받아서, 매칭 버튼을 누르면 DB에 해당 사용자가 해당 예약을 매칭 완료했다고 표시하게 된다.
  });
  @override
  State<BluetoothMatchingScreen> createState() => _BluetoothMatchingScreenState();
}

class _BluetoothMatchingScreenState extends State<BluetoothMatchingScreen>
    with SingleTickerProviderStateMixin { // 블루투스 파장 애니메이션을 위해 사용
  late AnimationController _animationController; // 애니메이션 컨트롤러 선언
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription; // 블루투스 상태 모니터링을 위해 사용 
  bool _isSubmitting = false; // 매칭 완료 버튼이 눌렸는지 여부를 나타내는 상태 변수
  bool _isBluetoothReady = false; // 블루투스가 사용 가능한 상태인지 여부를 나타내는 상태 변수
  // 매칭 완료 버튼이 활성화될 수 있는 조건: 블루투스가 사용 가능하고, 매칭 완료 요청이 진행 중이지 않을 때
  bool get _canCompleteMatch => _isBluetoothReady && !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 애니메이션이 한 사이클을 도는 데 걸리는 시간
    )..repeat();
    _initBluetoothMonitoring();
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
    if (mounted) {
      setState(() => _isBluetoothReady = ready);
    }
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onConfirmMatch() async {
    if (!_canCompleteMatch) return; // 매칭 실패 시

    setState(() => _isSubmitting = true); 
    try {
      final ok = await ProximityMatchApi.confirm(widget.reservationId);
      if (!mounted) return;
      // 매칭 완료 API 호출이 성공적으로 완료된 경우
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      // 매칭 확정에 실패한 경우
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매칭 확정에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false); //원상 복귀해두기
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. 상단 영역 (뒤로가기 버튼 + 블루투스 애니메이션)
          Expanded(
            flex: 6,
            child: SafeArea(
              child: Stack(
                children: [
                  // 뒤로가기 화살표 버튼
                  Positioned(
                    top: 10,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        color: Colors.black54,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                  // 중앙 블루투스 애니메이션 영역
                  Center(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: RadarWavePainter(_animationController.value),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: const BoxDecoration(
                              color: Color(0xff4D7CFC), // 블루투스 배경 파란색
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bluetooth,
                              color: Colors.white,
                              size: 70,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 하단 영역 (파란색 배경 + 안내 문구 + 노란색 버튼)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: const Color(0xff2B57A7), // 이미지의 진한 파란색 배경
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 안내 텍스트
                  const Text(
                    '블루투스를 켜서\n 동승자를 확인하세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  // 매칭 완료 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _canCompleteMatch ? _onConfirmMatch : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffFFF200),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            const Color(0xffFFF200).withValues(alpha: 0.45),
                        disabledForegroundColor:
                            Colors.black.withValues(alpha: 0.45),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              '매칭 완료',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 블루투스 주변으로 퍼지는 잔물결(Wave) 효과를 그리는 Painter
class RadarWavePainter extends CustomPainter {
  final double progress;
  RadarWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 1.3; // 파동이 퍼질 최대 반경

    for (int i = 3; i >= 1; i--) {
      // 시간차를 두고 퍼지는 3개의 원형 파동 계산
      double currentProgress = (progress + (i * 0.33)) % 1.0;
      double radius = maxRadius * currentProgress;
      double opacity = 1.0 - currentProgress; // 멀어질수록 투명해짐

      final paint = Paint()
        ..color = const Color(0xff4D7CFC).withOpacity(opacity * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}