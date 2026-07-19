import 'package:flutter/material.dart';
import 'package:smarthome/my_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_drawer.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<String> notifications = [];
  int displayedNotificationsCount = 20;
  int lastSeenNotificationIndex = 0;
  int totalNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> allNotifications = prefs.getStringList('notifications') ?? [];
    lastSeenNotificationIndex = prefs.getInt('lastSeenNotificationIndex') ?? 0;
    totalNotifications = allNotifications.length;

    setState(() {
      notifications =
          allNotifications.reversed.take(displayedNotificationsCount).toList();
    });
  }

  Future<void> _loadMoreNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> allNotifications = prefs.getStringList('notifications') ?? [];

    setState(() {
      displayedNotificationsCount += 20;
      notifications =
          allNotifications.reversed.take(displayedNotificationsCount).toList();
    });
  }

  @override
  void dispose() {
    _updateLastSeenNotificationIndex();
    super.dispose();
  }

  Future<void> _updateLastSeenNotificationIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeenNotificationIndex', totalNotifications);
    await prefs.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Colors.white, // Set a consistent background color
        foregroundColor: Colors.black, // Set text/icon color to ensure contrast
        scrolledUnderElevation: 0,
      ),
      drawer: MyDrawer(
        currentRoute: '/notifications',
        context: context,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length + 1,
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return ElevatedButton(
                    onPressed: _loadMoreNotifications,
                    child: Text('Load more...'),
                  );
                } else {
                  bool isHighlighted =
                      index < (totalNotifications - lastSeenNotificationIndex);
                  return Container(
                    color: isHighlighted ? Colors.yellow : Colors.transparent,
                    child: ListTile(
                      title: Text(notifications[index]),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
