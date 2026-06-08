import 'package:flutter/material.dart';

import 'package:frontend/data/colors.dart';
import 'package:frontend/features/chat/screens/mate_chat_screen.dart';

import '../models/settlement_calculator.dart';
import '../services/settlement_api.dart';

class IntermediateDropoffScreen extends StatefulWidget {
  const IntermediateDropoffScreen({super.key, this.matchData});

  final Map<String, dynamic>? matchData;

  @override
  State<IntermediateDropoffScreen> createState() =>
      _IntermediateDropoffScreenState();
}

class _IntermediateDropoffScreenState extends State<IntermediateDropoffScreen> {
  SettlementData? _settlementData;
  Map<String, dynamic>? _settlementStatus;
  bool _loading = true;
  bool _transferring = false;
  String? _error;

  int get _reservationId {
    final value =
        widget.matchData?['id'] ?? widget.matchData?['reservation_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get _settlementRequested => _settlementStatus?['requested'] == true;

  double? get _requestedTotalFare {
    final statusFare = _settlementStatus?['total_fare'];
    if (statusFare is num && statusFare > 0) return statusFare.toDouble();
    return null;
  }

  SettlementResult? get _settlement {
    final data = _settlementData;
    final totalFare = _requestedTotalFare;
    if (data == null || !_settlementRequested || totalFare == null) {
      return null;
    }
    return calculateSettlement(
      passengers: data.passengers,
      totalFare: totalFare,
      creatorId: data.reservation.creatorId,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettlement();
  }

  Future<void> _loadSettlement() async {
    final reservationId = _reservationId;
    if (reservationId <= 0) {
      setState(() {
        _loading = false;
        _error = '예약 정보가 없어 정산 정보를 불러올 수 없습니다.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await SettlementApi.fetchSettlement(reservationId);
      final status = await SettlementApi.fetchSettlementStatus(reservationId);
      if (!mounted) return;
      setState(() {
        _settlementData = data;
        _settlementStatus = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _openChat() {
    final reservationId = _reservationId;
    if (reservationId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MateChatScreen(reservationId: reservationId, title: '동승자 채팅방'),
      ),
    );
  }

  Future<void> _transfer() async {
    final reservationId = _reservationId;
    if (reservationId <= 0 || _transferring) return;

    setState(() => _transferring = true);
    try {
      await SettlementApi.transferSettlement(reservationId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('송금이 완료되었습니다.')));
      await _loadSettlement();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _transferring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _settlementData;
    final settlement = _settlement;
    final currentUserId = data?.currentUserId ?? '';
    final currentPassenger = data?.passengers.firstWhere(
      (passenger) => passenger.id == currentUserId,
      orElse: () => data.passengers.first,
    );
    final finalSettler = settlement?.finalSettler;
    final myFare = settlement?.fareByPassenger[currentUserId] ?? 0;
    final isFinalSettler = finalSettler?.id == currentUserId;
    final settlementRequested = _settlementRequested;
    final requestedTotalFare = _requestedTotalFare;
    final paid = _settlementStatus?['paid'] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('중도 하차 정산'),
        actions: [
          IconButton(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadSettlement)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: AuthColors.bluePrimary,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        '중도 하차 정산',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoCard(
                      title: '이동 정보',
                      children: [
                        _InfoRow('출발지', data!.reservation.departureLocation),
                        _InfoRow(
                          '나의 도착지',
                          currentPassenger?.destinationLocation.isNotEmpty ==
                                  true
                              ? currentPassenger!.destinationLocation
                              : data.reservation.destinationLocation,
                        ),
                        _InfoRow(
                          '나의 하차 거리',
                          formatDistanceMeters(
                            currentPassenger?.dropoffDistanceMeters ?? 0,
                          ),
                        ),
                        _InfoRow(
                          '총 결제금액',
                          requestedTotalFare == null
                              ? '정산 요청 대기'
                              : formatCurrency(requestedTotalFare),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: '내 정산',
                      children: settlement == null
                          ? const [
                              Text(
                                '최종 정산자가 총 결제금액 입력 후 정산하기를 누르면 금액이 표시됩니다.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AuthColors.grayText,
                                ),
                              ),
                            ]
                          : [
                              _InfoRow('내 결제금액', formatCurrency(myFare)),
                              _InfoRow(
                                '최종 정산자',
                                finalSettler?.displayName ?? '최종 정산자',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isFinalSettler
                                    ? '최종 정산자는 내 금액만 확인하면 됩니다.'
                                    : '${finalSettler?.displayName ?? '최종 정산자'}에게 ${formatCurrency(myFare)} 송금하세요.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AuthColors.bluePrimary,
                                ),
                              ),
                              if (!isFinalSettler) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed:
                                        !settlementRequested ||
                                            paid ||
                                            _transferring
                                        ? null
                                        : _transfer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AuthColors.bluePrimary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      paid
                                          ? '송금 완료'
                                          : _transferring
                                          ? '송금 중'
                                          : '송금하기',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                    ),
                    const SizedBox(height: 16),
                    if (settlement != null)
                      _InfoCard(
                        title: '참여자별 금액',
                        children: [
                          for (final passenger in data.passengers)
                            _InfoRow(
                              '${passenger.displayName} (${formatDistanceMeters(passenger.dropoffDistanceMeters)})',
                              formatCurrency(
                                settlement.fareByPassenger[passenger.id] ?? 0,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: AuthColors.grayText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
