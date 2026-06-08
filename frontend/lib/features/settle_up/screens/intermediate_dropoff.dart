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
  bool _loading = true;
  String? _error;

  int get _reservationId {
    final value =
        widget.matchData?['id'] ?? widget.matchData?['reservation_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get _totalFare {
    final fare = widget.matchData?['fare'];
    if (fare is num && fare > 0) return fare.toDouble();
    return 18000;
  }

  SettlementResult? get _settlement {
    final data = _settlementData;
    if (data == null) return null;
    return calculateSettlement(
      passengers: data.passengers,
      totalFare: _totalFare,
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
      if (!mounted) return;
      setState(() {
        _settlementData = data;
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
                        _InfoRow('총 결제금액', formatCurrency(_totalFare)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: '내 정산',
                      children: [
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
