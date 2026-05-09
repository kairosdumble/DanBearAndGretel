import 'package:flutter/material.dart';

// 시간 입력 필드 위젯
class TimeField extends StatefulWidget {
  final TextEditingController controller;
  const TimeField({super.key, required this.controller});

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: SizedBox(
          width: 142,
          height: 50,
          child: TextField(
          controller: widget.controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 1.5,
            ),
          ),
        ),
          ),
        )
    );
  }
}
  Widget build(TextEditingController controller) {
    return SafeArea(
        child: SizedBox(
          width: 142,
          height: 50,
          child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 1.5,
            ),
          ),
        ),
      ),
    )
  );
}