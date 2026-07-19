import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';
import 'notification_service.dart';
import 'mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';

int attemptsToConnect = 10;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  initializeNotifications();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: channelId,
      initialNotificationTitle: channelName,
      initialNotificationContent: channelDescription,
      foregroundServiceNotificationId: mainNotificationID,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    initialNotification();
    MqttService.requestFloodDetectionBattery();
    periodicFunction(service);
  }
}

void periodicFunction(AndroidServiceInstance service) {
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (await service.isForegroundService()) {
      if (!MqttService.isConnected()) {
        print('Trying to reconnect to the MQTT server!');
        MqttService.tryToConnect();
      } else {
        MqttService.subscribeToTopic(
            MqttService.setFloodDetectionTriggerStatus_topic);
        MqttService.subscribeToTopic(
            MqttService.setFloodDetectionBattery_topic);
        MqttService.subscribeToTopic(MqttService.setAlarmStatus_topic);
        MqttService.subscribeToTopic(MqttService.setAlarmTriggerStatus_topic);
        MqttService.subscribeToTopic(MqttService.setAlarmBattery_topic);
      }
    }
  });
}

void updateNotifications(String message) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  List<String> messages = prefs.getStringList('messages') ?? [];
  List<String> notifications = prefs.getStringList('notifications') ?? [];

  messages.add(message);
  notifications.add(message);

  await prefs.setStringList('messages', messages);
  await prefs.setStringList('notifications', notifications);
  await updateMainNotification();
}
