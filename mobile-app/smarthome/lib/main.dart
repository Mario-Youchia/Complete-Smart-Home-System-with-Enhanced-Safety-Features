// main.dart
import 'package:flutter/material.dart';
import 'loading_page.dart';
import 'my_home_page.dart';
import 'settings_form.dart';
import 'mqtt_service.dart';
import 'flood_detection_module.dart';
import 'globals.dart' as globals;
import 'background_service.dart';
import 'power_meter_module.dart';
import 'alarm_module.dart';
import 'dual_channel_relay.dart';
import 'notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MqttService.loadSettings();
  await initializeService();
  globals.isPowerAlertShownBefore = false;
  globals.isPowerTrailingBtnShownBefore = false;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: MqttService.autoConnect ? '/loading' : '/settings',
      routes: {
        '/loading': (context) => LoadingPage(),
        '/settings': (context) => SettingsForm(),
        '/floodDetection': (context) => FloodDetectionModulePage(),
        '/dashboard': (context) => MyHomePage(),
        '/powerMeter': (context) => PowerMeterModulePage(),
        '/alarmModule': (context) => AlarmModulePage(),
        '/relaysModule': (context) => DualChannelRelayPage(),
        '/notifications': (context) => NotificationsPage(),
      },
    );
  }
}
