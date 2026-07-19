import 'package:flutter/material.dart';
import 'mqtt_service.dart';
import 'my_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloodDetectionModulePage extends StatefulWidget {
  @override
  _FloodDetectionModuleState createState() => _FloodDetectionModuleState();
}

Future<List<dynamic>> getFloodDetectionData() async {
  await Future.delayed(Duration(seconds: 1));

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  int FloodBattery = prefs.getInt('FloodBattery') ?? 0;
  String FloodLastTrigger = prefs.getString('LastTrigger') ?? "";
  bool isTriggered = prefs.getBool('FloodStat') ?? false;
  List<String> history = prefs.getStringList('FloodHistory') ?? [];
  return [
    FloodBattery,
    FloodLastTrigger,
    isTriggered,
    history.reversed.toList()
  ];
}

class _FloodDetectionModuleState extends State<FloodDetectionModulePage> {
  int batteryPercentage = 0;
  String state = "";
  String lastTriggerTime = "";
  List<String> triggerHistory = [];

  @override
  void initState() {
    super.initState();
    MqttService.processedMessages.clear();
    MqttService.requestFloodDetectionBattery();
    MqttService.requestFloodDetectionLastTrigger();
    MqttService.requestFloodDetectionStatus();
    MqttService.requestFloodDetectionHistory();
    _initializeFloodDetectionModule().then((_) {
      print(batteryPercentage);
    });

    /*triggerHistory = [
      '2024-06-02 14:30:05',
      '2024-06-01 10:20:15',
      '2024-05-28 08:15:45',
      '2024-05-27 18:45:30',
      '2024-05-25 12:00:00',
      '2024-06-01 14:30:25',
      '2024-05-30 09:45:10',
      '2024-06-02 16:50:20',
      '2024-05-29 11:25:35',
      '2024-05-31 13:10:40',
      '2024-06-02 08:30:55',
      '2024-06-01 22:15:05',
      '2024-05-30 15:00:00',
      '2024-05-28 20:30:15',
      '2024-06-01 17:45:25',
      '2024-05-27 19:55:45',
      '2024-05-26 14:40:20',
      '2024-06-02 10:20:35',
      '2024-05-29 12:15:50',
      '2024-06-01 11:25:05',
    ];
    //_fetchData();*/
  }

  Future<void> _initializeFloodDetectionModule() async {
    await Future.delayed(Duration(seconds: 1));

    await getFloodDetectionData().then((status) {
      batteryPercentage = status[0];
      lastTriggerTime = status[1];
      if (status[2]) {
        state = "Detection Occurring";
      } else {
        state = "No Detection";
      }
      triggerHistory = status[3];
    });
  }

  void _confirmDisconnect() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flood Detection Module'),
        backgroundColor: Colors.white, // Set a consistent background color
        foregroundColor: Colors.black, // Set text/icon color to ensure contrast
        scrolledUnderElevation: 0,
      ),
      drawer: MyDrawer(
        currentRoute: '/floodDetection',
        context: context,
      ),
      body: FutureBuilder<List<dynamic>>(
          future: Future.wait([getFloodDetectionData()]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              batteryPercentage = snapshot.data?[0][0] ?? 0;
              lastTriggerTime = snapshot.data?[0][1] ?? "";
              state =
                  snapshot.data?[0][2] ? "Detection Occurring" : "No Detection";
              triggerHistory = snapshot.data?[0][3] ?? [];
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusIndicator(),
                    SizedBox(height: 10),
                    _buildInfoRow('Last Trigger', lastTriggerTime,
                        Icons.access_time, Colors.blue),
                    _buildBatteryInfoRow(
                        'Battery', '$batteryPercentage%', Icons.battery_full),
                    SizedBox(height: 20),
                    Text('Trigger History:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: _buildTriggerHistory(),
                    ),
                  ],
                ),
              );
            }
          }),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    if (state == "No Detection") {
      statusColor = Colors.green;
    } else if (state == "Detection Occurring") {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    return Row(
      children: [
        Text('Status: ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(width: 10),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        SizedBox(width: 10),
        Text(state,
            style: TextStyle(
              fontSize: 18,
              color: statusColor,
            )),
      ],
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color iconColor) {
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

  Widget _buildTriggerHistory() {
    if (triggerHistory.isEmpty) {
      return Center(child: Text('No trigger history available.'));
    }

    //triggerHistory.reversed.toList();

    return ListView.builder(
      itemCount: triggerHistory.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: Icon(Icons.history),
            title: Text(triggerHistory[index]),
          ),
        );
      },
    );
  }
}
