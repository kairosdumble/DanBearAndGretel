import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('앱이 기본 화면을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const DangretelApp());

    expect(find.text('당그릴텔'), findsOneWidget);
    expect(find.text('택시 공유 탑승'), findsOneWidget);
  });
}
