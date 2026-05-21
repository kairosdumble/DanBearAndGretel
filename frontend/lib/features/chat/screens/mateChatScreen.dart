import 'package:flutter/material.dart';
import 'package:frontend/features/bluetooth/screens/bluetoothConnect.dart';
import 'package:frontend/features/bluetooth/services/proximity_match_api.dart';
import 'package:frontend/features/nearbyMateList/screens/nearbyMateList.dart';

class MateChatScreen extends StatefulWidget {
  final int reservationId;

  const MateChatScreen({
    super.key,
    required this.reservationId,
  });

  static const Color _primaryBlue = Color(0xFF2F5DB3);
  @override
  State<MateChatScreen> createState() => _MateChatScreenState();
}

class _MateChatScreenState extends State<MateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatEntry> _messages = [];
  bool _isMatching = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openBluetoothMatching() async {
    final matched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BluetoothMatchingScreen(
          reservationId: widget.reservationId,
        ),
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatEntry(text: text, isMine: true));
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                children: [
                  for (final message in _messages) ...[
                    _ChatMessage(
                      text: message.text,
                      isMine: message.isMine,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            _MatchingButtons(
              isMatching: _isMatching,
              onMatch: _openBluetoothMatching,
              onCancelMatch: _onCancelMatching,
            ),
            _MessageInput(
              controller: _messageController,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEntry {
  final String text;
  final bool isMine;

  const _ChatEntry({
    required this.text,
    required this.isMine,
  });
}

class _ChatHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ChatHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: MateChatScreen._primaryBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.chevron_left,
            onTap: onBack,
          ),
          const Spacer(),
          const _ProfileCircle(borderColor: Color(0xFFD01818)),
          const SizedBox(width: 10),
          const _ProfileCircle(borderColor: Color(0xFFD01818)),
          const SizedBox(width: 10),
          const _ProfileCircle(borderColor: Colors.black),
          const Spacer(),
          const Icon(Icons.settings, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

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

class _ProfileCircle extends StatelessWidget {
  final Color borderColor;

  const _ProfileCircle({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String text;
  final bool isMine;

  const _ChatMessage({
    required this.text,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                isMine ? MateChatScreen._primaryBlue : const Color(0xFFE9E9E9),
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

class _MatchingButtons extends StatelessWidget {
  final bool isMatching;
  final VoidCallback onMatch;
  final VoidCallback onCancelMatch;

  const _MatchingButtons({
    required this.isMatching,
    required this.onMatch,
    required this.onCancelMatch,
  });

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
              onPressed: isMatching ? onCancelMatch : onMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: isMatching
                    ? const Color(0xFF8A8A8A)
                    : MateChatScreen._primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                isMatching ? '매칭 취소' : '매칭 하기',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
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
            onTap: onSend,
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
