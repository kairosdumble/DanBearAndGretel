import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/auth/auth_token_storage.dart';

class MateChatScreen extends StatefulWidget {
  final int reservationId;
  final String? title;

  const MateChatScreen({super.key, required this.reservationId, this.title});

  static const Color _primaryBlue = Color(0xFF2F5DB3);

  @override
  State<MateChatScreen> createState() => _MateChatScreenState();
}

class _MateChatScreenState extends State<MateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];
  final List<_ChatParticipant> _participants = [];
  final Set<String> _messageIds = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;
  http.Client? _streamClient;
  StreamSubscription<String>? _streamSubscription;
  String? _streamEventName;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
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
              title: widget.title,
              participants: _participants,
              onBack: () => Navigator.of(context).maybePop(),
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
            const _ActionButtons(),
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
            return _ChatMessage(text: message.text, isMine: message.isMine);
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String? title;
  final List<_ChatParticipant> participants;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.title,
    required this.participants,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: MateChatScreen._primaryBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _HeaderIconButton(icon: Icons.chevron_left, onTap: onBack),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ParticipantProfileStrip(participants: participants),
                if (title != null && title!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.settings, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: MateChatScreen._primaryBlue, size: 28),
      ),
    );
  }
}

class _ParticipantProfileStrip extends StatelessWidget {
  final List<_ChatParticipant> participants;

  const _ParticipantProfileStrip({required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const SizedBox(height: 36);
    }

    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final participant in participants) ...[
              _ProfileCircle(participant: participant),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCircle extends StatelessWidget {
  final _ChatParticipant participant;

  const _ProfileCircle({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        participant.label,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String text;
  final bool isMine;

  const _ChatMessage({required this.text, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine
                ? MateChatScreen._primaryBlue
                : const Color(0xFFE9E9E9),
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
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMine) ...[
          const _MessageProfileCircle(),
          const SizedBox(width: 8),
        ],
        bubble,
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

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: MateChatScreen._primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '매칭 하기',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE7E7E7),
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '나가기',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
      color: MateChatScreen._primaryBlue,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '무엇이든 입력하세요',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: MateChatScreen._primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
