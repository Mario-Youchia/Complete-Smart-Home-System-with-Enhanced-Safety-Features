// my_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mqtt_service.dart';
import 'settings_form.dart';
import 'notification_service.dart';
import 'my_drawer.dart';
import 'globals.dart' as globals;
import 'dart:io';

Future<bool> getFloodStatus() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  bool FloodStat = prefs.getBool('FloodStat') ?? false;
  return FloodStat;
}

Future<bool> getAlarmStatus() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  bool AlarmStatus = prefs.getBool('AlarmStatus') ?? false;
  return AlarmStatus;
}

Future<String> getFloodLastTrigger() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  String FloodLastTrigger = prefs.getString('LastTrigger') ?? "";
  return FloodLastTrigger;
}

Future<String> getAlarmLastTrigger() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  String AlarmLastTrigger = prefs.getString('AlarmLastTrigger') ?? "";
  return AlarmLastTrigger;
}

Future<List<dynamic>> getRelaysStatus() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  bool relay1On = prefs.getBool('relay1On') ?? false;
  bool relay2On = prefs.getBool('relay2On') ?? false;
  String lastOnRelay1 = prefs.getString('lastOnRelay1') ?? "";
  String lastOnRelay2 = prefs.getString('lastOnRelay2') ?? "";
  return [relay1On, relay2On, lastOnRelay1, lastOnRelay2];
}

class MyHomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool alarmTriggered = true; // Assume alarm is triggered for this example
  bool get _powerMeterThresholdExceeded =>
      PowerMeterModule.energyConsumption > PowerMeterModule.threshold;
  bool hasNewNotifications = false;
  bool floodDetected = false;
  String floodDetectionLastTrigger = "";
  String AlarmLastTrigger = "";
  bool relay1On = false;
  bool relay2On = false;
  String lastOnRelay1 = "";
  String lastOnRelay2 = "";

  @override
  void initState() {
    _clearNotifications();
    _checkForNewNotifications();
    //MqttService.requestFloodDetectionStatus();
    super.initState();
    MqttService.processedMessages.clear();
    MqttService.requestFloodDetectionStatus();
    MqttService.requestFloodDetectionLastTrigger();
    MqttService.requestAlarmLastTrigger();
    MqttService.requestAlarmStatus();
    MqttService.requestRelaysStatus();
    _initializeFloodStatus().then((_) {
      if (floodDetected) {
        WidgetsBinding.instance!
            .addPostFrameCallback((_) => _showFloodAlertDialog());
      }
    });
    _initializeAlarmStatus().then((_) {
      if (alarmTriggered) {
        WidgetsBinding.instance!
            .addPostFrameCallback((_) => _showAlarmAlertDialog());
      }
      // Check for Power Meter threshold exceeded
      if (_powerMeterThresholdExceeded) {
        WidgetsBinding.instance!
            .addPostFrameCallback((_) => _showPowerMeterAlertDialog());
      }
    });
    _initializeRelaysStatus().then((_) {});
  }

  Future<void> _initializeFloodStatus() async {
    await Future.delayed(Duration(seconds: 1));
    await getFloodStatus().then((status) {
      setState(() {
        floodDetected = status;
      });
    });
    await getFloodLastTrigger().then((status) {
      setState(() {
        floodDetectionLastTrigger = status;
      });
    });
  }

  Future<void> _initializeAlarmStatus() async {
    await Future.delayed(Duration(seconds: 1));
    await getAlarmStatus().then((status) {
      setState(() {
        alarmTriggered = status;
      });
    });
    await getAlarmLastTrigger().then((status) {
      print(status);
      setState(() {
        AlarmLastTrigger = status;
      });
    });
  }

  Future<void> _initializeRelaysStatus() async {
    await Future.delayed(Duration(seconds: 1));
    await getRelaysStatus().then((status) {
      setState(() {
        relay1On = status[0];
        relay2On = status[1];
        lastOnRelay1 = status[2];
        lastOnRelay2 = status[3];
      });
    });
  }

  void _showAlarmAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible:
          true, // Allows dismissing by tapping outside the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Alarm Alert"),
          content: Text(
              "An alarm has been triggered. To turn off the alarm, click on the alarm module widget."),
        );
      },
    );
  }

  void _updateAlarmState(bool state) {
    setState(() {
      MqttService.setAlarmStatus(state);
    });
  }

  void _showFloodAlertDialog() {
    showDialog(
      context: context,
      barrierDismissible:
          true, // Allows dismissing by tapping outside the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Flood Detection Alert"),
          content: Text("A flood has been detected."),
        );
      },
    );
    //}
  }

  void _updateFloodDetectionState(bool state) {
    setState(() {
      MqttService.setFloodStat(state);
      //floodDetected = state;
    });
  }

  void _showPowerMeterAlertDialog() {
    if (globals.isPowerAlertShownBefore == false) {
      globals.isPowerAlertShownBefore = true;
      showDialog(
        context: context,
        barrierDismissible:
            true, // Allows dismissing by tapping outside the dialog
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Power Meter Alert"),
            content: Text(
                "The power meter threshold has been exceeded. Please check the Power Meter module."),
          );
        },
      );
    }
  }

  Future<void> _clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('messages', []);
    await prefs.reload();
    initialNotification();
  }

  Future<void> _checkForNewNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('notifications') ?? [];
    int lastSeenNotificationIndex =
        prefs.getInt('lastSeenNotificationIndex') ?? -1;
    setState(() {
      hasNewNotifications =
          notifications.length > lastSeenNotificationIndex + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Smart Home Dashboard'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/notifications');
                  _checkForNewNotifications();
                },
              ),
              if (hasNewNotifications)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minHeight: 12,
                      minWidth: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: MyDrawer(
        currentRoute: '/dashboard',
        context: context,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          getFloodStatus(),
          getFloodLastTrigger(),
          getAlarmStatus(),
          getRelaysStatus()
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            floodDetected = snapshot.data?[0] ?? false;
            floodDetectionLastTrigger = snapshot.data?[1] ?? "";
            alarmTriggered = snapshot.data?[2] ?? false;
            relay1On = snapshot.data?[3][0] ?? false;
            relay2On = snapshot.data?[3][1] ?? false;
            lastOnRelay1 = snapshot.data?[3][2] ?? "";
            lastOnRelay2 = snapshot.data?[3][3] ?? "";
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ConnectionTimeWidget(),
                  SizedBox(height: 16.0),
                  FloodDetectionModule(
                    floodDetected: floodDetected,
                    onStatusChanged: _updateFloodDetectionState,
                    floodDetectionLastTrigger: floodDetectionLastTrigger,
                  ),
                  SizedBox(height: 16.0),
                  PowerMeterModule(),
                  SizedBox(height: 16.0),
                  AlarmModule(
                    alarmTriggered: alarmTriggered,
                    onStatusChanged: _updateAlarmState,
                    AlarmLastTrigger: AlarmLastTrigger,
                  ),
                  SizedBox(height: 16.0),
                  DualChannelRelayModule(
                      relay1On: relay1On,
                      relay2On: relay2On,
                      lastOnRelay1: lastOnRelay1,
                      lastOnRelay2: lastOnRelay2),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class ConnectionTimeWidget extends StatefulWidget {
  @override
  _ConnectionTimeWidgetState createState() => _ConnectionTimeWidgetState();
}

class _ConnectionTimeWidgetState extends State<ConnectionTimeWidget> {
  void _showConnectionDetailsDialog() {
    final now = DateTime.now();
    final duration = now.difference(globals.connectionTime);
    final formattedDuration = _formatDuration(duration);
    final formattedConnectionTime =
        _formatConnectionTime(globals.connectionTime);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Connection Details"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Connected since: $formattedConnectionTime'),
              Text('Duration: $formattedDuration'),
            ],
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatConnectionTime(DateTime time) {
    return "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedConnectionTime =
        _formatConnectionTime(globals.connectionTime);

    return Card(
      child: ListTile(
        leading: Icon(Icons.access_time),
        title: Text('Connected since:'),
        subtitle: Text(
            formattedConnectionTime), // Format connection time without milliseconds
        onTap: _showConnectionDetailsDialog,
      ),
    );
  }
}

class FloodDetectionModule extends StatefulWidget {
  final bool floodDetected;
  final String floodDetectionLastTrigger;
  final Function(bool) onStatusChanged;

  FloodDetectionModule(
      {required this.floodDetected,
      required this.onStatusChanged,
      required this.floodDetectionLastTrigger});

  @override
  _FloodDetectionModuleState createState() => _FloodDetectionModuleState();
}

class _FloodDetectionModuleState extends State<FloodDetectionModule> {
  late bool floodDetected;
  late String floodDetectionLastTrigger;

  @override
  void initState() {
    super.initState();
    floodDetected = widget.floodDetected;
    floodDetectionLastTrigger = widget.floodDetectionLastTrigger;
  }

  void _handleOkPressed() async {
    MqttService.lowerAlert();
    Future.delayed(Duration(seconds: 1));
    setState(() {
      MqttService.setFloodStat(false);
    });
    widget.onStatusChanged(false);
  }

  void _showFloodDetailDialog() async {
    await getFloodStatus();
    await getFloodLastTrigger();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Flood Detection Module"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(floodDetected
                  ? 'Status: Detection Occurring'
                  : 'Status: No Detection'),
              Text('Last trigger: ${floodDetectionLastTrigger}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([getFloodStatus(), getFloodLastTrigger()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          floodDetected = snapshot.data?[0] ?? false;
          floodDetectionLastTrigger = snapshot.data?[1] ?? "";
          return Card(
            child: ListTile(
              leading: Icon(
                Icons.plumbing,
                color: floodDetected ? Colors.red : Colors.green,
              ),
              title: Text('Flood Detection Module'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(floodDetected
                      ? 'Status: Detection Occurring'
                      : 'Status: No Detection'),
                  Text('Last trigger: ${floodDetectionLastTrigger}'),
                ],
              ),
              trailing: floodDetected
                  ? ElevatedButton(
                      onPressed: _handleOkPressed,
                      child: Text("OK"),
                    )
                  : null,
              onTap: _showFloodDetailDialog, // Show details dialog on tap
            ),
          );
        }
      },
    );
  }
}

class PowerMeterModule extends StatefulWidget {
  static double energyConsumption = 15.5; // Assume current energy consumption
  static double threshold = 10.0; // Assume initial threshold
  @override
  _PowerMeterModuleState createState() => _PowerMeterModuleState();
}

class _PowerMeterModuleState extends State<PowerMeterModule> {
  bool thresholdExceeded = false; // New state variable

  @override
  void initState() {
    super.initState();
    thresholdExceeded = PowerMeterModule.energyConsumption >
        PowerMeterModule.threshold; // Check if threshold is exceeded
  }

  void _showPowerMeterDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _PowerMeterDetailsDialog(
          currentThreshold: PowerMeterModule.threshold,
          onThresholdChanged: (newThreshold) {
            setState(() {
              PowerMeterModule.threshold = newThreshold;
              thresholdExceeded = PowerMeterModule.energyConsumption >
                  PowerMeterModule.threshold; // Update state
            });
          },
        );
      },
    );
  }

  void _handleOkPressed() {
    setState(() {
      thresholdExceeded = false;
      globals.isPowerTrailingBtnShownBefore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.electrical_services,
            color:
                PowerMeterModule.energyConsumption > PowerMeterModule.threshold
                    ? Colors.red
                    : Colors.green),
        title: Text('Power Meter'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Energy consumption: ${PowerMeterModule.energyConsumption} kWh'),
            Text('Threshold: ${PowerMeterModule.threshold.toInt()} kWh'),
          ],
        ),
        trailing: thresholdExceeded && !globals.isPowerTrailingBtnShownBefore
            ? ElevatedButton(
                onPressed: _handleOkPressed,
                //onPressed: () {},
                child: Text("OK"),
              )
            : null,
        onTap: () => _showPowerMeterDetails(context),
      ),
    );
  }
}

class _PowerMeterDetailsDialog extends StatefulWidget {
  final double currentThreshold;
  final Function(double) onThresholdChanged;

  _PowerMeterDetailsDialog({
    required this.currentThreshold,
    required this.onThresholdChanged,
  });

  @override
  __PowerMeterDetailsDialogState createState() =>
      __PowerMeterDetailsDialogState();
}

class __PowerMeterDetailsDialogState extends State<_PowerMeterDetailsDialog> {
  late double threshold;

  @override
  void initState() {
    super.initState();
    threshold = widget.currentThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Power Meter Module"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Energy consumption: 15.5 kWh'),
          Text('Current: 10 A'),
          Text('Voltage: 220 V'),
          Text('Power consumption: 3.3 kW'),
          Text('Power Factor: 0.9'),
          Text('Threshold: ${threshold.toInt()} kWh'),
          Slider(
            value: threshold,
            min: 0,
            max: 100,
            divisions: 100,
            //label: threshold.toStringAsFixed(1),
            label: threshold.round().toString(),
            onChanged: (value) {
              setState(() {
                threshold = value.roundToDouble(); // Ensure only integer values
                widget.onThresholdChanged(threshold);
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class AlarmModule extends StatefulWidget {
  final bool alarmTriggered;
  final Function(bool) onStatusChanged;
  final String AlarmLastTrigger;

  AlarmModule(
      {required this.alarmTriggered,
      required this.onStatusChanged,
      required this.AlarmLastTrigger});

  @override
  _AlarmModuleState createState() => _AlarmModuleState();
}

class _AlarmModuleState extends State<AlarmModule> {
  late bool alarmTriggered;
  late String AlarmLastTrigger;

  @override
  void initState() {
    super.initState();
    alarmTriggered = widget.alarmTriggered;
    AlarmLastTrigger = widget.AlarmLastTrigger;
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
      widget.onStatusChanged(false);
    } else {
      print("Alarm is not triggered, showing snackbar");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("The alarm is not triggered."),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([getAlarmStatus(), getAlarmLastTrigger()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          alarmTriggered = snapshot.data?[0] ?? false;
          AlarmLastTrigger = snapshot.data?[1] ?? "";
          print("alarmTriggered = ${alarmTriggered}");
          return Card(
            child: ListTile(
                leading: Icon(
                  Icons.warning,
                  color: alarmTriggered ? Colors.red : Colors.green,
                ),
                title: Text('Alarm Module'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alarmTriggered
                        ? 'Status: Alarm triggered'
                        : 'Status: No alarm'),
                    Text('Last trigger: ${AlarmLastTrigger}'),
                  ],
                ),
                onTap: _handleAlarmClick),
          );
        }
      },
    );
  }
}

class DualChannelRelayModule extends StatefulWidget {
  final bool relay1On;
  final bool relay2On;
  //final Function(bool) onStatusChanged;
  final String lastOnRelay1;
  final String lastOnRelay2;

  DualChannelRelayModule(
      {required this.relay1On,
      required this.relay2On,
      required this.lastOnRelay1,
      required this.lastOnRelay2});

  @override
  _DualChannelRelayModuleState createState() => _DualChannelRelayModuleState();
}

class _DualChannelRelayModuleState extends State<DualChannelRelayModule> {
  late bool relay1On;
  late bool relay2On;
  late String lastOnRelay1;
  late String lastOnRelay2;

  @override
  void initState() {
    super.initState();
    relay1On = widget.relay1On;
    relay2On = widget.relay2On;
    lastOnRelay1 = widget.lastOnRelay1;
    lastOnRelay2 = widget.lastOnRelay2;
  }

  void _toggleRelay1() {
    setState(() {
      relay1On = !relay1On;
      if (relay1On) {
        // Update last ON time
        lastOnRelay1 = _formatDateTime(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay 1 is turned ON'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay 1 is turned OFF'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _toggleRelay2() {
    setState(() {
      relay2On = !relay2On;
      if (relay2On) {
        // Update last ON time
        lastOnRelay2 = _formatDateTime(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay 2 is turned ON'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay 2 is turned OFF'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  String _formatDateTime(DateTime time) {
    return "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }

  /*lastOnRelay1 =
      DateTime.parse('2024-05-31 13:00:00'); // Initial last ON time for relay 1
  lastOnRelay2 =
      '2024-05-31 12:30:00'; // Initial last ON time for relay 2*/

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.device_hub,
                color: relay1On ? Colors.red : Colors.green),
            title: Text('Relay 1'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${relay1On ? 'ON' : 'OFF'}'),
                Text('Last ON: ${lastOnRelay1}'),
              ],
            ),
            onTap: _toggleRelay1,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.device_hub,
                color: relay2On ? Colors.red : Colors.green),
            title: Text('Relay 2'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${relay2On ? 'ON' : 'OFF'}'),
                Text('Last ON: ${lastOnRelay2}'), // Format date-time
              ],
            ),
            onTap: _toggleRelay2,
          ),
        ],
      ),
    );
  }
}
