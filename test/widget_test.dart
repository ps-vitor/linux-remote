import 'package:flutter_test/flutter_test.dart';
import 'package:linux_remote/main.dart';

void main() {
  testWidgets('App renders connect screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LinuxRemoteApp());
    expect(find.text('Linux Remote'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
  });
}
