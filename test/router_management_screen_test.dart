// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: test/router_management_screen_test.dart
// Tests: RouterDetailScreen, AddRouterScreen (Edit Mode) & HotSpot Inspection
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mikrotik_cards_app/models/router_model.dart';
import 'package:mikrotik_cards_app/screens/add_router_screen.dart';
import 'package:mikrotik_cards_app/screens/router_detail_screen.dart';
import 'package:mikrotik_cards_app/services/api_client.dart';

http.Response utf8Response(Map<String, dynamic> data, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    try {
      final fontLoaderCairo = FontLoader('Cairo');
      final arabicFontBytes =
          File('/system/fonts/NotoNaskhArabicUI-Regular.ttf').readAsBytesSync();
      fontLoaderCairo
          .addFont(Future.value(ByteData.sublistView(arabicFontBytes)));

      final robotoBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto/Roboto-Regular.ttf')
          .readAsBytesSync();
      fontLoaderCairo.addFont(Future.value(ByteData.sublistView(robotoBytes)));
      await fontLoaderCairo.load();

      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = File(
              '/data/data/com.termux/files/home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    } catch (_) {}
  });

  tearDown(() {
    ApiClient.resetClient();
  });

  final sampleRouter = RouterModel(
    id: 'router-uuid-001',
    name: 'راوتر الفرع الرئيسي',
    host: '192.168.88.1',
    apiPort: 8728,
    connectionMethod: 'ROUTEROS_API_PLAIN',
    status: 'ONLINE',
    cpuLoadPercentage: 14,
    uptimeSeconds: 7200,
    lastSeenAt: DateTime.now(),
  );

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  testWidgets('RouterDetailScreen displays router header and tabs', (tester) async {
    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('/hotspot-users')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'username': 'hotspot_user_1',
              'profile': 'default',
              'isEnabled': true,
              'uptimeSeconds': 1800,
              'bytesIn': 1024000,
              'bytesOut': 5120000,
              'verifiedOnRouter': true,
              'dbStatus': 'ACTIVE',
            }
          ],
        }, 200);
      }
      if (request.url.path.contains('/hotspot-sessions')) {
        return utf8Response({
          'success': true,
          'data': [
            {
              'username': 'hotspot_user_1',
              'ipAddress': '192.168.88.50',
              'macAddress': 'AA:BB:CC:DD:EE:FF',
              'uptimeSeconds': 600,
              'bytesIn': 512000,
              'bytesOut': 2048000,
            }
          ],
        }, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Router details header
    expect(find.text('راوتر الفرع الرئيسي'), findsOneWidget);
    expect(find.text('192.168.88.1:8728'), findsOneWidget);
    expect(find.text('ROUTEROS_API_PLAIN'), findsOneWidget);

    // Verify tabs
    expect(find.textContaining('مستخدمو الهوتسبوت'), findsOneWidget);
    expect(find.textContaining('الجلسات النشطة'), findsOneWidget);

    // Verify user list loaded
    expect(find.text('hotspot_user_1'), findsOneWidget);
    expect(find.text('مؤكد على الراوتر'), findsOneWidget);

    // Switch to Sessions Tab
    await tester.tap(find.textContaining('الجلسات النشطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify session details loaded
    expect(find.textContaining('192.168.88.50'), findsOneWidget);
    expect(find.textContaining('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.byTooltip('فصل الجلسة'), findsOneWidget);
  });

  testWidgets('RouterDetailScreen live probe button executes test connection', (tester) async {
    bool testConnCalled = false;

    ApiClient.client = MockClient((request) async {
      if (request.url.path.contains('/test-connection')) {
        testConnCalled = true;
        return utf8Response({
          'success': true,
          'message': 'تم الاتصال بالراوتر بنجاح',
          'data': {
            'identity': 'MikroTik-HQ',
            'version': 'RouterOS v7.15',
            'boardName': 'CCR2004-1G-12S+2XS',
            'cpuLoad': 8,
            'uptimeSeconds': 86400,
          },
        }, 200);
      }
      return utf8Response({'success': true, 'data': []}, 200);
    });

    await tester.pumpWidget(createTestWidget(RouterDetailScreen(router: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final probeButton = find.text('فحص الاتصال');
    expect(probeButton, findsOneWidget);

    await tester.tap(probeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(testConnCalled, isTrue);
    expect(find.textContaining('CCR2004-1G-12S+2XS'), findsWidgets);
  });

  testWidgets('AddRouterScreen in edit mode pre-fills router details and submits update', (tester) async {
    bool updateCalled = false;
    String? sentName;
    int? sentPort;

    ApiClient.client = MockClient((request) async {
      if (request.method == 'PATCH' && request.url.path == '/api/v1/routers/router-uuid-001') {
        updateCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentName = body['name'] as String?;
        sentPort = body['port'] as int?;
        return utf8Response({
          'success': true,
          'data': {
            'id': 'router-uuid-001',
            'name': sentName,
            'host': '192.168.88.1',
            'apiPort': sentPort,
            'connectionMethod': 'ROUTEROS_API_PLAIN',
            'status': 'ONLINE',
          },
        }, 200);
      }
      return utf8Response({'success': true, 'data': {}}, 200);
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(AddRouterScreen(routerToEdit: sampleRouter)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify title indicates Edit
    expect(find.text('تعديل الراوتر'), findsWidgets);

    // Verify pre-filled name
    expect(find.text('راوتر الفرع الرئيسي'), findsOneWidget);

    // Change the name
    await tester.enterText(find.byType(TextFormField).first, 'راوتر الفرع المحدث');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Submit form
    final saveButton = find.text('حفظ التعديلات');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(updateCalled, isTrue);
    expect(sentName, equals('راوتر الفرع المحدث'));
    expect(sentPort, equals(8728));
  });
}
