import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'globals.dart';
import 'dart:async';
import 'my_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DualChannelRelayPage extends StatefulWidget {
  @override
  _DualChannelRelayPageState createState() => _DualChannelRelayPageState();
}

class _DualChannelRelayPageState extends State<DualChannelRelayPage>
    with WidgetsBindingObserver {
  bool relay1On = false;
  bool relay2On = true;
  DateTime lastOnRelay1 = DateTime.parse('2024-05-31 13:00:00');
  DateTime lastOnRelay2 = DateTime.parse('2024-05-31 12:30:00');
  String relay1Countdown = '';
  String relay2Countdown = '';
  int relay1TimerDuration = 10;
  int relay2TimerDuration = 10;
  Timer? relay1Timer;
  Timer? relay2Timer;
  DateTime? relay1EndTime;
  DateTime? relay2EndTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimerState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimerState();
    super.dispose();
  }

  void _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final relay1EndTimeString = prefs.getString('relay1EndTime') ?? '';
      if (relay1EndTimeString.isNotEmpty) {
        relay1EndTime = DateTime.tryParse(relay1EndTimeString);
        if (relay1EndTime == null) {
          throw FormatException("Invalid date format");
        }
      } else {
        relay1EndTime = DateTime.now();
      }
    } catch (e) {
      print('Error parsing relay1EndTime: $e');
      relay1EndTime = DateTime.now(); // Default value
    }

    try {
      final relay2EndTimeString = prefs.getString('relay2EndTime') ?? '';
      if (relay2EndTimeString.isNotEmpty) {
        relay2EndTime = DateTime.tryParse(relay2EndTimeString);
        if (relay2EndTime == null) {
          throw FormatException("Invalid date format");
        }
      } else {
        relay2EndTime = DateTime.now();
      }
    } catch (e) {
      print('Error parsing relay2EndTime: $e');
      relay2EndTime = DateTime.now(); // Default value
    }

    if (relay1EndTime != null && relay1EndTime!.isAfter(DateTime.now())) {
      relay1TimerDuration = relay1EndTime!.difference(DateTime.now()).inSeconds;
      _startRelay1Timer();
    } else {
      relay1TimerDuration = 0;
    }

    if (relay2EndTime != null && relay2EndTime!.isAfter(DateTime.now())) {
      relay2TimerDuration = relay2EndTime!.difference(DateTime.now()).inSeconds;
      _startRelay2Timer();
    } else {
      relay2TimerDuration = 0;
    }

    setState(() {});
  }

  void _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    if (relay1TimerDuration > 0) {
      prefs.setString('relay1EndTime', relay1EndTime!.toIso8601String());
    } else {
      prefs.remove('relay1EndTime');
    }

    if (relay2TimerDuration > 0) {
      prefs.setString('relay2EndTime', relay2EndTime!.toIso8601String());
    } else {
      prefs.remove('relay2EndTime');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRelay1Timer();
      _startRelay2Timer();
    }
  }

  void _toggleRelay1() {
    setState(() {
      relay1On = !relay1On;
      if (relay1On) {
        lastOnRelay1 = DateTime.now();
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
        lastOnRelay2 = DateTime.now();
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

  void _startRelay1Timer() {
    relay1EndTime = DateTime.now().add(Duration(seconds: relay1TimerDuration));
    _saveTimerState();

    if (relay1Timer != null && relay1Timer!.isActive) return;
    relay1Countdown = _formatDuration(Duration(seconds: relay1TimerDuration));
    relay1Timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (relay1TimerDuration > 0) {
        if (mounted) {
          setState(() {
            relay1TimerDuration--;
            relay1Countdown =
                _formatDuration(Duration(seconds: relay1TimerDuration));
          });
        } else {
          relay1Timer!.cancel();
        }
      } else {
        relay1Timer!.cancel();
        if (mounted) {
          setState(() {
            _toggleRelay1();
            relay1Countdown = '';
          });
        }
      }
    });
  }

  void _startRelay2Timer() {
    relay2EndTime = DateTime.now().add(Duration(seconds: relay2TimerDuration));
    _saveTimerState();

    if (relay2Timer != null && relay2Timer!.isActive) return;
    relay2Countdown = _formatDuration(Duration(seconds: relay2TimerDuration));
    relay2Timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (relay2TimerDuration > 0) {
        if (mounted) {
          setState(() {
            relay2TimerDuration--;
            relay2Countdown =
                _formatDuration(Duration(seconds: relay2TimerDuration));
          });
        } else {
          relay2Timer!.cancel();
        }
      } else {
        relay2Timer!.cancel();
        if (mounted) {
          setState(() {
            _toggleRelay2();
            relay2Countdown = '';
          });
        }
      }
    });
  }

  Future<void> _showTimerPicker(int relayNumber) async {
    int initialTimerValue =
        relayNumber == 1 ? relay1TimerDuration : relay2TimerDuration;
    Duration selectedDuration = Duration(seconds: initialTimerValue);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: selectedDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() {
                      if (relayNumber == 1) {
                        relay1TimerDuration = newDuration.inSeconds;
                      } else {
                        relay2TimerDuration = newDuration.inSeconds;
                      }
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: Text('Set Timer'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime time) {
    return "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  }

  String _formatDuration(Duration duration) {
    return "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dual Channel Relay Module'),
      ),
      drawer: MyDrawer(
        currentRoute: '/relaysModule',
        context: context,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.device_hub,
                      color: relay1On ? Colors.red : Colors.green,
                    ),
                    title: Text('Relay 1'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${relay1On ? 'ON' : 'OFF'}'),
                        Text('Last ON: ${_formatDateTime(lastOnRelay1)}'),
                      ],
                    ),
                    onTap: _toggleRelay1,
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text('Timer: $relay1Countdown',
                            textAlign: TextAlign.center),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _showTimerPicker(1),
                          child: Text("Set Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Predefined Timers:'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1TimerDuration = 30;
                            });
                          },
                          child: Text("30s"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1TimerDuration = 300;
                            });
                          },
                          child: Text("5m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1TimerDuration = 900;
                            });
                          },
                          child: Text("15m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1TimerDuration = 1800;
                            });
                          },
                          child: Text("30m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1TimerDuration = 3600;
                            });
                          },
                          child: Text("1h"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _startRelay1Timer,
                          child: Text("Start Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay1Timer?.cancel();
                              relay1Countdown = '';
                            });
                          },
                          child: Text("Cancel Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.device_hub,
                      color: relay2On ? Colors.red : Colors.green,
                    ),
                    title: Text('Relay 2'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${relay2On ? 'ON' : 'OFF'}'),
                        Text('Last ON: ${_formatDateTime(lastOnRelay2)}'),
                      ],
                    ),
                    onTap: _toggleRelay2,
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text('Timer: $relay2Countdown',
                            textAlign: TextAlign.center),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _showTimerPicker(2),
                          child: Text("Set Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Predefined Timers:'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2TimerDuration = 30;
                            });
                          },
                          child: Text("30s"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2TimerDuration = 300;
                            });
                          },
                          child: Text("5m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2TimerDuration = 900;
                            });
                          },
                          child: Text("15m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2TimerDuration = 1800;
                            });
                          },
                          child: Text("30m"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2TimerDuration = 3600;
                            });
                          },
                          child: Text("1h"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _startRelay2Timer,
                          child: Text("Start Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              relay2Timer?.cancel();
                              relay2Countdown = '';
                            });
                          },
                          child: Text("Cancel Timer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}