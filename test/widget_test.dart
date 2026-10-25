import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_file_sorter/main.dart';
import 'package:ft_file_sorter/src/presentation/widgets/segment_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('ConfigurationScreen renders all sections correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Boolean Toggle
    expect(
      find.text('Automated Sorting & Archive Processing'),
      findsOneWidget,
    );

    // 2. Folder and Excel pickers
    expect(find.text('Browse Folder'), findsOneWidget);
    expect(find.text('Select Excel'), findsOneWidget);

    // 3. Schema builder segments (find each inside SegmentCard)
    expect(find.widgetWithText(SegmentCard, 'Main Code'), findsOneWidget);
    expect(find.widgetWithText(SegmentCard, 'Index 1'), findsOneWidget);
    expect(find.widgetWithText(SegmentCard, 'Index 2'), findsOneWidget);
    expect(find.widgetWithText(SegmentCard, 'Revision'), findsOneWidget);

    // 4. Live Schema Preview
    expect(find.text('Live Filename Schema Preview'), findsOneWidget);
    expect(find.textContaining('Total Base Length: 31 chars'), findsOneWidget);

    // 5. Test Filename Parser Section
    expect(find.text('Test Filename Parser'), findsOneWidget);
  });
}
