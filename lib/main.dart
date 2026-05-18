import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.validate();
  // Required by TableCalendar (fr_FR locale) — without this it throws
  // LocaleDataException at first build of the Calendrier tab.
  await initializeDateFormatting('fr_FR', null);
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: App()));
}
