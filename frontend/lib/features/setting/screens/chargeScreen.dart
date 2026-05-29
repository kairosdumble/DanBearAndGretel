import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/auth/auth_token_storage.dart';

class chargeScreen extends StatefulWidget {
  const chargeScreen({Key? key}) : super(key: key);

  @override
  State<chargeScreen> createState() => _ChargeScreenState();
}

class _ChargeScreenState extends State<chargeScreen> {
  final TextEditingController _amountController = TextEditingController();

  void _addAmount(int amount) {
    int current = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _amountController.text = (current + amount).toString();
  }

  Future<void> _processCharge(BuildContext context, int amount) async {
    if (amount <= 0) return;

    try {
      final token = await AuthTokenStorage.getToken();
      final response = await http.post(
        Uri.parse('${dotenv.env['BASE_URL']}/api/user/charge'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        if (!context.mounted) return;
        Navigator.pop(context, true); // 성공 신호 보내기
      }
    } catch (e) {
      print("충전 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("충전하기", style: TextStyle(color:Colors.black)),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("충전할 금액을 입력해 주세요.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            Row(
              children: [3000, 5000, 10000, 30000].map((amt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => _addAmount(amt),
                    child: Text(amt >= 10000
                      ? "${(amt / 10000).toInt()}만원"
                      : "${(amt / 1000).toInt()}천원"
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 30),

            // 금액 표시 및 직접 입력 필드
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "충전 금액 (원)",
              ),
            ),
            const Spacer(),

            // 최종 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  int amount = int.tryParse(_amountController.text) ?? 0;
                  if (amount > 0) {
                    await _processCharge(context, amount);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("확인", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}