// frontend/lib/features/ride/screens/companion_list_screen.dart

import 'package:flutter/material.dart';
import '../widgets/companion_card.dart';
import '../widgets/companion_empty_view.dart';

class CompanionListScreen extends StatelessWidget {
  const CompanionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    
    final List<Map<String, String>> companions = []; 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "주변 동승자",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      
      body: companions.isEmpty 
          ? const CompanionEmptyView() 
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: companions.length,
              itemBuilder: (context, index) {
                final item = companions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CompanionCard(
                    start: item["start"]!,
                    end: item["end"]!,
                    time: item["time"]!,
                    price: item["price"]!,
                  ),
                );
              },
            ),
    );
  }
}