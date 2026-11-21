import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/health/client_health_reporter.dart';
import 'core/service_window.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // E2E mode is deliberately debug-only. It keeps analytics and auth traffic
  // on emulators and suppresses client-health telemetry from test devices.
  const requestedE2eMode = bool.fromEnvironment('E2E_TEST_MODE');
  final e2eTestMode = kDebugMode && requestedE2eMode;
  if (e2eTestMode) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  }

  await BackendServiceAvailability.loadRemote(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
  );

  if (!e2eTestMode) {
    final reporter = ClientHealthReporter();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reporter.report(
        type: 'APP_ERROR',
        error: details.exception,
        stack: details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      reporter.report(type: 'APP_CRASH', error: error, stack: stack);
      return true;
    };
  }

  runApp(const ProviderScope(child: AvijitSahyogApp()));
}
