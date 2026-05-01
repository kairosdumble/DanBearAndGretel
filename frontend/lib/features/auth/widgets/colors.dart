import 'package:flutter/material.dart';
/// Auth 화면 전용 색상 모음.
///
/// 사용 예시:
/// 1) 파일 상단 import 추가
///    import 'package:frontend/features/auth/widgets/colors.dart';
///
/// 2) 위젯에서 닉네임으로 사용
///    Container(color: AuthColors.white)
///    TextStyle(color: AuthColors.blackText)
/// 
/// 참고:
/// - 피그마에 있는 색은 HEX형태로 나옴. 
/// - 그래서 dart 파일에서는 투명도도 추가됨으로, 불투명의 경우 0xFF를 붙이고, 투명의 경우 0x00을 붙임.
/// 
class AuthColors {
  AuthColors._();

  // 파란색 불투명
  static const Color bluePrimary = Color(0xFF2C55A1);
  // 파란색 반투명
  static const Color blueSecondary = Color(0xFFC1D1F1);
  // 흰색
  static const Color white = Color(0xFFFFFFFF);
  // 회색
  static const Color gray = Color(0xFFD9D9D9);
  //빨간색
  static const Color red = Color(0xFFBB1B1B);
  //노랑색
  static const Color yellow = Color(0xFFF6FF00);
  
  // 검정색 (글씨)
  static const Color blackText = Color(0xFF000000);
  // 회색 (글씨)
  static const Color grayText = Color(0xFF989898);
  // 흰색 (글씨)
  static const Color whiteText = Color(0xFFFFFFFF);
}
