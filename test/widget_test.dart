import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gleelight/main.dart';
import 'package:gleelight/services/storage_service.dart';
import 'package:gleelight/services/yeelight_service.dart';

void main() {
  testWidgets('GleeLight app starts', (WidgetTester tester) async {
    // HomeScreen reads stored lamps on the first frame, so the storage service
    // has to be initialized the same way main() does it.
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    await tester.pumpWidget(const YeelightApp());

    // Verify that the app title is shown
    expect(find.text('GleeLight'), findsOneWidget);

    // The home screen kicks off discovery on the first frame, which leaves
    // sockets and timers behind; shut them down so the test can finish.
    YeelightService.instance.dispose();
  });
}
