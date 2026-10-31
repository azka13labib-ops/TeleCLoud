import 'package:flutter_test/flutter_test.dart';
import 'package:terabox_telegram_cloud/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeraBoxTelegramApp());
  });
}
