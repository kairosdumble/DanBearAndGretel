import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/data/colors.dart';

import 'package:frontend/core/auth/auth_token_storage.dart';
import 'package:frontend/core/auth/auth_user_id.dart';
import 'package:frontend/features/bluetooth/screens/bluetooth_connect.dart';
import 'package:frontend/features/bluetooth/screens/bluetooth_leader.dart';
import 'package:frontend/features/bluetooth/services/proximity_match_api.dart';
import 'package:frontend/features/nearby_mate_list/screens/nearby_mate_list.dart';

//[TODO] 나중에 isMatching/Matched 상태 성리 필요

class MateChatScreen extends StatefulWidget {
  final int reservationId;
  final String? title;

  const MateChatScreen({super.key, required this.reservationId, this.title});

  @override
  State<MateChatScreen> createState() => _MateChatScreenState();
}

class _MateChatScreenState extends State<MateChatScreen> {
  static const List<String> _weekdayLabels = [
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];
  final List<_ChatParticipant> _participants = [];
  final Set<String> _messageIds = {};
  Map<String, dynamic>? _reservation;
  bool _loadingReservation = true;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  http.Client? _streamClient;
  StreamSubscription<String>? _streamSubscription;
  String? _streamEventName;
  bool _disposed = false;
  bool? _isMatching; /// null: DB 조회 중, true/false: reservation_bluetooth_participants 존재 여부
  

  @override
  void initState() {
    super.initState();
    _loadReservation();
    _loadMessages();
    _loadMatchingStatus();
  }

  Future<void> _loadReservation() async {
    setState(() => _loadingReservation = true);
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _loadingReservation = false);
        return;
      }
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
      final response = await http.get(
        Uri.parse('$baseUrl/api/reservations/${widget.reservationId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          setState(() {
            _reservation = Map<String, dynamic>.from(decoded);
            _loadingReservation = false;
          });
          return;
        }
      }
      setState(() => _loadingReservation = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReservation = false);
    }
  }

  String get _routeTitle {
    final reservation = _reservation;
    if (reservation != null) {
      final dep = reservation['departure_location']?.toString() ?? '';
      final dest = reservation['destination_location']?.toString() ?? '';
      if (dep.isNotEmpty && dest.isNotEmpty) {
        return '$dep → $dest';
      }
    }
    final title = widget.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title.replaceAll(' -> ', ' → ');
    }
    return '예약 정보';
  }

  int get _participantCount {
    final online = _participants.length;
    if (online > 0) return online;
    final raw = _reservation?['participant_count'];
    if (raw is num && raw.toInt() > 0) return raw.toInt();
    return 1;
  }

  DateTime? get _departureDateTime {
    final value = _reservation?['departure_time'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatReservationDate(DateTime? departure) {
    if (departure == null) return '미정';
    final weekday = _weekdayLabels[departure.weekday - 1];
    return '${departure.year}. ${departure.month.toString().padLeft(2, '0')}. ${departure.day.toString().padLeft(2, '0')} ($weekday)';
  }

  String _formatReservationTime(DateTime? departure) {
    if (departure == null) return '미정';
    final period = departure.hour < 12 ? '오전' : '오후';
    final hourOfPeriod = departure.hour % 12;
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minute = departure.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }

  Future<void> _loadMatchingStatus() async {
    final exists = await ProximityMatchApi.get(widget.reservationId);
    if (!mounted) return;
    setState(() => _isMatching = exists);
  }

  @override
  void dispose() {
    _disposed = true;
    _streamSubscription?.cancel();
    _streamClient?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _isReservationLeader() async {
    final token = await AuthTokenStorage.getToken();
    final currentUserId = token == null ? null : parseUserIdFromToken(token);
    final ownerId = int.tryParse(_reservation?['user_id']?.toString() ?? '');
    if (currentUserId == null || ownerId == null) return false;
    return currentUserId == ownerId;
  }

  Future<void> _openBluetoothMatching() async {
    final isLeader = await _isReservationLeader();
    if (!mounted) return;

    final matched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => isLeader
            ? BluetoothLeaderScreen(reservationId: widget.reservationId)
            : BluetoothMatchingScreen(reservationId: widget.reservationId),
      ),
    );
    if (matched == true && mounted) {
      setState(() => _isMatching = true);
    }
  }

  Future<void> _onCancelMatching() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '정말로 나가시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C55A1),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF2C55A1),
                        ),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        child: const Text(
                          '예',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF2C55A1),
                        ),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        child: const Text(
                          '아니요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldExit != true || !mounted) return;

    final ok = await ProximityMatchApi.cancel(widget.reservationId);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매칭 취소에 실패했습니다. 다시 시도해 주세요.')),
      );
      return;
    }

    setState(() => _isMatching = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NearbyMateList()),
      (route) => route.isFirst,
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '로그인이 필요합니다.';
        });
        return;
      }

      final response = await http.get(
        _messagesUri(),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = '채팅 내역을 불러오지 못했습니다. (${response.statusCode})';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final list = decoded is List ? decoded : <dynamic>[];
      final loaded = list
          .whereType<Map>()
          .map((entry) => _ChatEntry.fromJson(Map<String, dynamic>.from(entry)))
          .where((entry) => entry.text.isNotEmpty)
          .toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
        _messageIds
          ..clear()
          ..addAll(loaded.map((entry) => entry.id));
        _loading = false;
      });
      _scrollToBottom();
      _startMessageStream();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '채팅 내역을 불러오지 못했습니다: $error';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _messageController.clear();
    });

    try {
      final token = await AuthTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = '로그인이 필요합니다.';
        });
        return;
      }

      final response = await http.post(
        _messagesUri(),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': text}),
      );

      if (!mounted) return;

      if (response.statusCode != 201) {
        setState(() {
          _sending = false;
          _error = '메시지를 저장하지 못했습니다. (${response.statusCode})';
          _messageController.text = text;
        });
        return;
      }

      final created = _ChatEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
      setState(() {
        _addMessage(created);
        _sending = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '메시지를 저장하지 못했습니다: $error';
        _messageController.text = text;
      });
    }
  }

  Uri _messagesUri() {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    return Uri.parse(
      '$baseUrl/api/chats/reservations/${widget.reservationId}/messages',
    );
  }

  Uri _streamUri() {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    return Uri.parse(
      '$baseUrl/api/chats/reservations/${widget.reservationId}/messages/stream',
    );
  }

  Future<void> _startMessageStream() async {
    await _streamSubscription?.cancel();
    _streamClient?.close();

    final token = await AuthTokenStorage.getToken();
    if (_disposed || token == null || token.isEmpty) {
      return;
    }

    final client = http.Client();
    _streamClient = client;

    try {
      final request = http.Request('GET', _streamUri())
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);
      if (_disposed || response.statusCode != 200) {
        client.close();
        return;
      }

      _streamSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStreamLine,
            onDone: _scheduleStreamReconnect,
            onError: (_) => _scheduleStreamReconnect(),
            cancelOnError: true,
          );
    } catch (_) {
      client.close();
      _scheduleStreamReconnect();
    }
  }

  void _scheduleStreamReconnect() {
    if (_disposed) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        _startMessageStream();
      }
    });
  }

  void _handleStreamLine(String line) {
    if (line.startsWith('event: ')) {
      _streamEventName = line.substring(7).trim();
      return;
    }

    if (!line.startsWith('data: ')) {
      return;
    }

    try {
      final eventName = _streamEventName;
      _streamEventName = null;
      final decoded = jsonDecode(line.substring(6));

      if (eventName == 'presence') {
        _handlePresenceEvent(decoded);
        return;
      }

      if (eventName == 'message') {
        if (decoded is! Map || decoded['message'] == null) {
          return;
        }

        final entry = _ChatEntry.fromJson(Map<String, dynamic>.from(decoded));
        if (!mounted || entry.text.isEmpty) return;

        setState(() {
          _addMessage(entry);
        });
        _scrollToBottom();
      }
    } catch (_) {
      return;
    }
  }

  void _handlePresenceEvent(dynamic decoded) {
    if (decoded is! Map || !mounted) {
      return;
    }

    final list = decoded['participants'] is List
        ? decoded['participants'] as List
        : <dynamic>[];
    final loaded = list
        .whereType<Map>()
        .map(
          (entry) =>
              _ChatParticipant.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();

    setState(() {
      _participants
        ..clear()
        ..addAll(loaded);
    });
  }

  void _addMessage(_ChatEntry entry) {
    if (!_messageIds.add(entry.id)) {
      return;
    }
    _messages.add(entry);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              routeTitle: _routeTitle,
              participantCount: _participantCount,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            _ReservationInfoCard(
              loading: _loadingReservation,
              departure: _reservation?['departure_location']?.toString() ?? '미정',
              destination:
                  _reservation?['destination_location']?.toString() ?? '미정',
              dateLabel: _formatReservationDate(_departureDateTime),
              timeLabel: _formatReservationTime(_departureDateTime),
              participantCount: _participantCount,
              isMatching: _isMatching,
              onMatch: _openBluetoothMatching,
              onCancelMatch: _onCancelMatching,
            ),
            Expanded(
              child: _ChatMessageList(
                loading: _loading,
                error: _error,
                messages: _messages,
                scrollController: _scrollController,
                onRetry: _loadMessages,
              ),
            ),
            _MessageInput(
              controller: _messageController,
              enabled: !_sending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEntry {
  final String id;
  final String text;
  final bool isMine;
  final DateTime createdAt;

  _ChatEntry({
    required this.id,
    required this.text,
    required this.isMine,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory _ChatEntry.fromJson(Map<String, dynamic> json) {
    return _ChatEntry(
      id: json['id']?.toString() ?? '',
      text: (json['message'] ?? json['text'])?.toString() ?? '',
      isMine: json['is_mine'] == true || json['isMine'] == true,
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'])?.toString() ?? '',
      ),
    );
  }

  String get formattedTime {
    final local = createdAt.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hourOfPeriod = local.hour % 12;
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$period $hour:$minute';
  }
}

class _ChatParticipant {
  final String id;
  final String name;
  final String email;

  const _ChatParticipant({
    required this.id,
    required this.name,
    required this.email,
  });

  factory _ChatParticipant.fromJson(Map<String, dynamic> json) {
    return _ChatParticipant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  String get label {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return '?';
    return String.fromCharCode(source.runes.first).toUpperCase();
  }
}

class _ChatMessageList extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_ChatEntry> messages;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  const _ChatMessageList({
    required this.loading,
    required this.error,
    required this.messages,
    required this.scrollController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    final reversedMessages = messages.reversed.toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ListView.separated(
          controller: scrollController,
          reverse: true,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          itemCount: reversedMessages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final message = reversedMessages[index];
            return _ChatMessage(
              text: message.text,
              isMine: message.isMine,
              timeLabel: message.formattedTime,
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String routeTitle;
  final int participantCount;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.routeTitle,
    required this.participantCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFF222222),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '참여자 $participantCount명',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AuthColors.bluePrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.settings_outlined,
              size: 22,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationInfoCard extends StatelessWidget {
  final bool loading;
  final String departure;
  final String destination;
  final String dateLabel;
  final String timeLabel;
  final int participantCount;
  final bool? isMatching;
  final VoidCallback onMatch;
  final VoidCallback onCancelMatch;

  const _ReservationInfoCard({
    required this.loading,
    required this.departure,
    required this.destination,
    required this.dateLabel,
    required this.timeLabel,
    required this.participantCount,
    required this.isMatching,
    required this.onMatch,
    required this.onCancelMatch,
  });

  @override
  Widget build(BuildContext context) {
    final matched = isMatching == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RouteTimeline(
                        departure: departure,
                        destination: destination,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _InfoDetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: '날짜',
                              value: dateLabel,
                            ),
                            const SizedBox(height: 10),
                            _InfoDetailRow(
                              icon: Icons.schedule_outlined,
                              label: '시간',
                              value: timeLabel,
                            ),
                            const SizedBox(height: 10),
                            _InfoDetailRow(
                              icon: Icons.people_outline_rounded,
                              label: '참여자',
                              value: '$participantCount명',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: isMatching == null
                          ? null
                          : (matched ? onCancelMatch : onMatch),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: matched
                            ? const Color(0xFF8A8A8A)
                            : AuthColors.bluePrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        matched ? '매칭 취소' : '매칭 하기',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

class _RouteTimeline extends StatelessWidget {
  final String departure;
  final String destination;

  const _RouteTimeline({
    required this.departure,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _RouteIconCircle(
                icon: Icons.train_rounded,
                color: AuthColors.bluePrimary,
              ),
              SizedBox(
                height: 28,
                child: CustomPaint(
                  size: const Size(2, 28),
                  painter: _DashedLinePainter(color: AuthColors.bluePrimary),
                ),
              ),
              _RouteIconCircle(
                icon: Icons.home_rounded,
                color: AuthColors.green,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteLabelBlock(label: '출발지', value: departure),
                const SizedBox(height: 18),
                _RouteLabelBlock(label: '도착지', value: destination),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteIconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RouteIconCircle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

class _RouteLabelBlock extends StatelessWidget {
  final String label;
  final String value;

  const _RouteLabelBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AuthColors.grayText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _InfoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: AuthColors.blueSecondary, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AuthColors.bluePrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AuthColors.grayText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatMessage extends StatelessWidget {
  final String text;
  final bool isMine;
  final String timeLabel;

  const _ChatMessage({
    required this.text,
    required this.isMine,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = Text(
      timeLabel,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AuthColors.grayText,
        height: 1.2,
      ),
    );

    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine ? AuthColors.bluePrimary : const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          const _MessageProfileCircle(),
          const SizedBox(width: 8),
          bubble,
          const SizedBox(width: 6),
          timeText,
        ] else ...[
          timeText,
          const SizedBox(width: 6),
          bubble,
        ],
      ],
    );
  }
}

class _MessageProfileCircle extends StatelessWidget {
  const _MessageProfileCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AuthColors.bluePrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
