import 'package:flutter/material.dart';

class SearchBoxButton extends StatelessWidget{
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  
  const SearchBoxButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.subtitle,
  });
  @override

  Widget build(BuildContext context) {
    final hasSelection = subtitle != null;
    
    return Material( 
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: hasSelection ? 66 : 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFD4D4D4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          hasSelection ? FontWeight.w700 : FontWeight.w500,
                      color: hasSelection
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Color(0xFF3056A0)),
          ],
          ),
        ),
      ),
    );
  }
}