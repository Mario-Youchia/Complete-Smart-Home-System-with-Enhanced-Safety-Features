// loading_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_form.dart';
import 'mqtt_service.dart';
import 'my_home_page.dart';
import 'globals.dart';

class LoadingPage extends StatefulWidget {
  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? serverIp = prefs.getString('serverIp');
      String? username = prefs.getString('username');
      String? password = prefs.getString('password');
      int? port = int.tryParse(prefs.getString('port') ?? '1883');

      print(
          'Attempting to connect with settings: serverIp=$serverIp, username=$username, port=$port');

      if (serverIp == null ||
          username == null ||
          password == null ||
          port == null) {
        _navigateToSettingsForm();
      } else {
        bool isConnected =
            await MqttService.connect(serverIp, port, username, password);
        if (isConnected) {
          //await MqttService.publishMessage('test/topic', 'hello');
          await _saveLastUsedSettings(serverIp, username, password, port);
          connectionTime = DateTime.now();
          MqttService.subscribeToTopic(
              MqttService.setFloodDetectionStatus_topic);
          MqttService.subscribeToTopic('test/topic2');
          MqttService.subscribeToTopic(
              MqttService.setFloodDetectionLastTrigger_topic);
          MqttService.subscribeToTopic(
              MqttService.setFloodDetectionHistory_topic);
          MqttService.subscribeToTopic(MqttService.setAlarmLastTrigger_topic);
          MqttService.subscribeToTopic(MqttService.setAlarmHistory_topic);
          MqttService.subscribeToTopic(MqttService.setRelaysStatus_topic);
          _navigateToHomePage();
        } else {
          _navigateToSettingsForm();
        }
      }
    } catch (e) {
      print('Error checking server connection: $e');
      _navigateToSettingsForm();
    }
  }

  Future<void> _saveLastUsedSettings(
      String serverIp, String username, String password, int port) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(
        'Saving last used settings: serverIp=$serverIp, username=$username, password=$password, port=$port');

    await prefs.setString('lastServerIp', serverIp);
    await prefs.setString('lastUsername', username);
    await prefs.setString('lastPassword', password);
    await prefs.setString('lastPort', port.toString());
  }

  void _navigateToSettingsForm() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SettingsForm()),
    );
  }

  void _navigateToHomePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MyHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Connecting to server...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
