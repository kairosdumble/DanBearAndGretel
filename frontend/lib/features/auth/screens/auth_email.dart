import 'dart:convert'; // JSON 인코딩/디코딩
import 'package:flutter/material.dart';
import 'package:frontend/features/auth/widgets/colors.dart'; // 색깔 통합
import 'package:http/http.dart' as http; // 메일전송
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 파일 로드용

class AuthEmailScreen extends StatefulWidget {
  final String email;

  const AuthEmailScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends State<AuthEmailScreen> {
  String _enteredCode = '';

  Future<void> _verifyCode() async{
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
  
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/email/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": widget.email,
        "code": _enteredCode,
      }),
    );

    if (response.statusCode == 200) {
      // 1. 성공 시 스낵바 메시지 출력
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증에 성공했습니다!'),
          backgroundColor: Colors.blue,
        ),
      );

      // 2. 잠시 후 이전 화면(회원가입 창)으로 돌아가기
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.of(context).pop(true); // true를 전달하여 성공 상태를 알림
      });
      
    } else {
      // 3. 실패 시 에러 메시지 출력
      final errorData = jsonDecode(response.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorData['message'] ?? '인증 실패. 코드를 확인하세요.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    // 4. 네트워크 오류 등 예외 처리
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('서버 통신 중 오류가 발생했습니다.'),
        backgroundColor: Colors.red,
      ),
    );
  }
  } 
  @override
  void initState() {
    super.initState();
    _sendAuthCode();
  }

  Future<void> _sendAuthCode() async {
    final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
    print('인증코드 전송 시도: ${widget.email}'); // 디버깅용
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/email/send-code"),
        headers: {'Content-Type': 'application/json'},
        body: '{"email": "${widget.email}"}',
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증코드가 이메일로 전송되었습니다.')),
        );
      } else {
        print("서버 응답 에러: ${response.body}"); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증코드 전송에 실패했습니다. 에러코드: ${response.statusCode} 실패 사유: ${response.body}')),
        );
      }
    } catch (e) {
      print("네트워크 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류로 인증코드 전송에 실패했습니다.')), 
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AuthColors.gray,
                          fixedSize: const Size(44, 44),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('이메일을 확인하세요',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AuthColors.blackText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AuthColors.blackText,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: '로 이메일을 보냈습니다.\n'),
                            const TextSpan(text: '인증 메일을 확인하고, 인증 숫자를 입력하세요.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _CodeInputs(
                        onChanged: (code) {
                          setState(() {
                            _enteredCode = code;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _enteredCode.length == 6 ? _verifyCode : null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: AuthColors.blueSecondary,
                            disabledForegroundColor: AuthColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('인증 확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Center(
                        child: TextButton(
                          onPressed: _sendAuthCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AuthColors.bluePrimary,
                          ),
                          child: const Text('인증코드 다시 보내기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              color: AuthColors.bluePrimary,
                              decorationColor: AuthColors.bluePrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

class _CodeInputs extends StatefulWidget {
  final void Function(String code) onChanged;
  const _CodeInputs({Key? key, required this.onChanged}) : super(key: key);

  @override
  State<_CodeInputs> createState() => _CodeInputsState();
}

class _CodeInputsState extends State<_CodeInputs> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int idx, String value) {
    if (value.length == 1 && idx < 5) {
      _focusNodes[idx + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.length == 1)) {
      final code = _controllers.map((c) => c.text).join();
      widget.onChanged(code);
    } else {
      widget.onChanged(_controllers.map((c) => c.text).join());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(6, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 6 ? 0 : 10),
            height: 64,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero, 
                filled: true,
                fillColor: AuthColors.gray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AuthColors.gray, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AuthColors.gray, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AuthColors.bluePrimary, width: 2),
                ),
              ),
              onChanged: (v) => _onChanged(index, v),
              inputFormatters: [],
            ),
          ),
        );
      }),
    );
  }
}