import 'package:flutter/material.dart';
import 'mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_drawer.dart';
import 'dart:convert';

Future<List<dynamic>> getAlarmData() async {
  await Future.delayed(Duration(seconds: 1));

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  bool isTriggered = prefs.getBool('AlarmStatus') ?? false;
  String FloodLastTrigger = prefs.getString('AlarmLastTrigger') ?? "";
  String alarmHistoryJson = prefs.getString('AlarmHistory') ?? "";
  List<_AlarmHistory> alarmHistory = [];
  List<dynamic> jsonList = jsonDecode(alarmHistoryJson);
  alarmHistory = jsonList.map((json) => _AlarmHistory.fromJson(json)).toList();
  alarmHistory = alarmHistory.reversed.toList();
  int batteryPercentage = prefs.getInt('AlarmBattery') ?? 0;
  return [isTriggered, FloodLastTrigger, alarmHistory, batteryPercentage];
}

class AlarmModulePage extends StatefulWidget {
  @override
  _AlarmModulePageState createState() => _AlarmModulePageState();
}

class _AlarmModulePageState extends State<AlarmModulePage> {
  bool alarmTriggered = false;
  String lastTriggerTime = "";
  List<String> triggerHistory = [];
  List<_AlarmHistory> alarmHistory = [];
  int batteryPercentage = 0;

  @override
  void initState() {
    super.initState();
    MqttService.processedMessages.clear();
    MqttService.requestAlarmStatus();
    MqttService.requestAlarmLastTrigger();
    MqttService.requestAlarmHistory();
    MqttService.requestAlarmBattery();
    _initializeAlarmModule().then((_) {});
  }

  Future<void> _initializeAlarmModule() async {
    await Future.delayed(Duration(seconds: 1));
    await getAlarmData().then((status) {
      alarmTriggered = status[0];
      lastTriggerTime = status[1];
      alarmHistory = status[2];
      batteryPercentage = status[3];
    });
  }

  void _handleAlarmClick() async {
    print("Alarm module clicked");
    await MqttService.lowerAlarmAlert();
    await Future.delayed(Duration(seconds: 1));
    if (alarmTriggered) {
      print("Lowering Alert...");
      setState(() {
        alarmTriggered = false;
      });
      MqttService.setAlarmStatus(false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("The alarm is not triggered."),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildBatteryInfoRow(String label, String value, IconData icon) {
    Color iconColor;
    if (batteryPercentage <= 25) {
      iconColor = Colors.red;
    } else {
      iconColor = Colors.green;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          SizedBox(width: 10),
          Text('$label:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(width: 10),
          Text(value, style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // Set a consistent background color
        foregroundColor: Colors.black, // Set text/icon color to ensure contrast
        scrolledUnderElevation: 0,
        title: Text('Alarm Module'),
      ),
      drawer: MyDrawer(
        currentRoute: '/alarmModule',
        context: context,
      ),
      body: FutureBuilder<List<dynamic>>(
          future: Future.wait([getAlarmData()]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              alarmTriggered = snapshot.data?[0][0] ?? false;
              lastTriggerTime = snapshot.data?[0][1] ?? "";
              alarmHistory = snapshot.data?[0][2] ?? [];
              batteryPercentage = snapshot.data?[0][3] ?? 0;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          alarmTriggered ? 'Triggered' : 'Not Triggered',
                          style: TextStyle(
                            fontSize: 18,
                            color: alarmTriggered ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Last Trigger: ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          lastTriggerTime,
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        _buildBatteryInfoRow('Battery', '$batteryPercentage%',
                            Icons.battery_full),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _handleAlarmClick,
                      child: Text("Stop Alarm"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            alarmTriggered ? Colors.red : Colors.grey,
                        foregroundColor:
                            alarmTriggered ? Colors.white : Colors.blue,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Alarm Trigger History:',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                        child: ListView.builder(
                            itemCount: alarmHistory.length,
                            itemBuilder: (context, index) {
                              final history = alarmHistory[index];
                              return ListTile(
                                leading: Icon(Icons.history),
                                title: Text(history.trigger_datetime),
                                subtitle: Text(history.trigger_cause),
                              );
                            }))
                  ],
                ),
              );
            }
          }),
    );
  }
}

class _AlarmHistory {
  final String trigger_datetime;
  final String trigger_cause;

  _AlarmHistory({required this.trigger_datetime, required this.trigger_cause});

  factory _AlarmHistory.fromJson(Map<String, dynamic> json) {
    return _AlarmHistory(
      trigger_datetime: json['trigger_datetime'],
      trigger_cause: json['trigger_cause'],
    );
  }
}
