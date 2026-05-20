import 'package:flutter/material.dart';

class MateChatScreen extends StatefulWidget {
  const MateChatScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2F5DB3);

  @override
  State<MateChatScreen> createState() => _MateChatScreenState();
}

class _MateChatScreenState extends State<MateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatEntry> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
            const _ActionButtons(),
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
