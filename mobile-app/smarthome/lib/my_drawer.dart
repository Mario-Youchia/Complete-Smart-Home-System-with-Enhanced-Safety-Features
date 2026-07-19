import 'package:flutter/material.dart';
import 'my_home_page.dart';
import 'mqtt_service.dart';
import 'globals.dart' as globals;

class MyDrawer extends StatelessWidget {
  final String currentRoute;
  final BuildContext context;

  MyDrawer({required this.currentRoute, required this.context});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Row(
              children: [
                Icon(Icons.home, color: Colors.white, size: 36),
                SizedBox(width: 10),
                Text(
                  'Navigation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Dashboard'),
            selected: currentRoute == '/dashboard',
            //selected: ModalRoute.of(context)?.settings.name == '/dashboard',
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.plumbing),
            title: Text('Flood Detection Module'),
            selected: currentRoute == '/floodDetection',
            onTap: () {
              Navigator.pushReplacementNamed(context, '/floodDetection');
            },
          ),
          ListTile(
            leading: Icon(Icons.electrical_services),
            title: Text('Power Meter Module'),
            selected: currentRoute == '/powerMeter',
            onTap: () {
              Navigator.pushReplacementNamed(context, '/powerMeter');
            },
          ),
          ListTile(
            leading: Icon(Icons.warning),
            title: Text('Alarm Module'),
            selected: currentRoute == '/alarmModule',
            onTap: () {
              Navigator.pushReplacementNamed(context, '/alarmModule');
            },
          ),
          ListTile(
            leading: Icon(Icons.device_hub),
            title: Text('Dual-Channel Relay Module'),
            selected: currentRoute == '/relaysModule',
            onTap: () {
              Navigator.pushReplacementNamed(context, '/relaysModule');
            },
          ),
          ListTile(
            leading: Icon(Icons.power_settings_new),
            title: Text('Disconnect'),
            onTap: () {
              Navigator.pop(context);
              _confirmDisconnect(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Disconnect"),
          content: Text("Are you sure you want to disconnect from the server?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Disconnect"),
              onPressed: () {
                MqttService.disconnect(context);
                //Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
