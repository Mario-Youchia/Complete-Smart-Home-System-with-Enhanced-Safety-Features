import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String channelId = 'Notifications';
const String channelName = 'Smart home notifications:';
const String channelDescription = 'Notification channel for updates';
const String groupKey = 'com.marioyouchia.smarthome.groupKey';
const int mainNotificationID = 1122334455;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  channelId,
  channelName,
  description: channelDescription,
  importance: Importance.low,
);

Future<void> initializeNotifications() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void initialNotification() {
  flutterLocalNotificationsPlugin.show(
    mainNotificationID,
    channelName,
    "Smarthome application is running in the background.",
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        icon: 'ic_stat_home',
        color: Colors.green,
        importance: Importance.max,
        priority: Priority.max,
        groupKey: groupKey,
        setAsGroupSummary: true,
      ),
    ),
  );
}

Future<void> updateMainNotification() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> messages = prefs.getStringList('messages') ?? [];

  String notificationContent = messages.join('\n');
  flutterLocalNotificationsPlugin.show(
    mainNotificationID,
    channelName,
    notificationContent,
    NotificationDetails(
      android: AndroidNotificationDetails(channelId, channelName,
          channelDescription: channelDescription,
          icon: 'ic_stat_home',
          color: Colors.green,
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(
            notificationContent,
            contentTitle: "Smart home notifications:",
            summaryText: 'You have ${messages.length} new notifications',
          ),
          groupKey: groupKey,
          setAsGroupSummary: true),
    ),
  );
}
