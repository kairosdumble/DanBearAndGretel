import 'package:flutter/material.dart';
import 'package:frontend/features/auth/widgets/colors.dart';

class AuthEmailScreen extends StatelessWidget {
  const AuthEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                      const Text(
                        '이메일을 확인하세요',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AuthColors.blackText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AuthColors.blackText,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: '1234@dankook.ac.kr',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '로 이메일을 보냈습니다.\n'),
                            TextSpan(text: '인증 메일을 확인하고, 인증 숫자를 입력하세요.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _CodeInputs(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: AuthColors.blueSecondary,
                            disabledForegroundColor: AuthColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '인증 확인',
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
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AuthColors.bluePrimary,
                          ),
                          child: const Text(
                            '인증코드 다시 보내기',
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
    );
  }
}

class _CodeInputs extends StatelessWidget {
  const _CodeInputs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(6, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 5 ? 0 : 10),
            height: 64,
            decoration: BoxDecoration(
              color: AuthColors.gray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AuthColors.gray,
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}