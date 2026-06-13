import 'package:flutter/material.dart';

import 'package:frontend/data/colors.dart';

class SettlementChatLink extends StatelessWidget {
  const SettlementChatLink({super.key, required this.onIconTap});

  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onIconTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.chat_bubble_outline,
                size: 22,
                color: AuthColors.grayText,
              ),
              SizedBox(width: 8),
              Text(
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
      ),
    ),
    );
  }
}
