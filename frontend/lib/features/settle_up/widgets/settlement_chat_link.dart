import 'package:flutter/material.dart';

import 'package:frontend/data/colors.dart';

class SettlementChatLink extends StatelessWidget {
  const SettlementChatLink({super.key, required this.onIconTap});

  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onIconTap,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: AuthColors.grayText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '해당 채팅방으로 이동하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AuthColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
