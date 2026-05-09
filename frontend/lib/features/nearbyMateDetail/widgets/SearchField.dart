import 'package:flutter/material.dart';
// 검색 필드 위젯
class SearchField extends StatefulWidget {
  
  final String hintText;
  final TextEditingController controller;
  final VoidCallback onTap;

  const SearchField({
    super.key,
    required this.hintText,
    required this.controller,
    required this.onTap,
  });
  @override
  State<SearchField> createState() => _SearchFieldState();
}
class _SearchFieldState extends State<SearchField> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: widget.controller,
        readOnly: true,
        onTap: widget.onTap,
        decoration: InputDecoration(
          hintText: widget.hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: const Icon(
            Icons.search,
            color: Colors.blue,
          ),
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
    );
  }
}