// mqtt_service.dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import for shared preferences
import 'package:flutter/material.dart';
import 'settings_form.dart'; // Import the settings form
import 'loading_page.dart';
import 'globals.dart' as globals;
import 'background_service.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';

class MqttService {
  static MqttServerClient? _client;
  static bool _autoConnect = true;
  static String getFloodDetectionStatus_topic =
      "mobile/flood/status/get_status";
  static String setFloodDetectionStatus_topic =
      "mobile/flood/status/set_status";
  static String getFloodDetectionLastTrigger_topic =
      "mobile/flood/status/get_last_trigger";
  static String setFloodDetectionLastTrigger_topic =
      "mobile/flood/status/set_last_trigger";
  static String lowerFloodDetectionAlert_topic =
      "mobile/flood/alert/lower_alert";
  static String setFloodDetectionTriggerStatus_topic =
      "mobile/flood/alert/raise_alert";
  static String getFloodDetectionBattery_topic =
      "mobile/flood/battery/get_battery";
  static String setFloodDetectionBattery_topic =
      "mobile/flood/battery/set_battery";
  static String getFloodDetectionHistory_topic =
      "mobile/flood/history/get_history";
  static String setFloodDetectionHistory_topic =
      "mobile/flood/history/set_history";
  static String lowerAlarmAlert_topic = "mobile/alarm/alert/lower_alert";
  static String getAlarmStatus_topic = "mobile/alarm/status/get_status";
  static String setAlarmStatus_topic = "mobile/alarm/status/set_status";
  static String setAlarmTriggerStatus_topic = "mobile/alarm/alert/raise_alert";
  static String getAlarmLastTrigger_topic =
      "mobile/alarm/status/get_last_trigger";
  static String setAlarmLastTrigger_topic =
      "mobile/alarm/status/set_last_trigger";
  static String getAlarmHistory_topic = "mobile/alarm/history/get_history";
  static String setAlarmHistory_topic = "mobile/alarm/history/set_history";
  static String getAlarmBattery_topic = "mobile/alarm/battery/get_battery";
  static String setAlarmBattery_topic = "mobile/alarm/battery/set_battery";
  static String getRelaysStatus_topic = 'mobile/relays/status/get_status';
  static String setRelaysStatus_topic = 'mobile/relays/status/set_status';

  static String clientID = generateRandomString(20);
  static Set<String> subscribedTopics = {}; // Track subscribed topics
  static Set<String> processedMessages = {}; // Track processed messages
  // Load the auto-connect setting from shared preferences
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _autoConnect = prefs.getBool('autoConnect') ?? true;
  }

  // Save the auto-connect setting to shared preferences
  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoConnect', _autoConnect);
  }

  static String generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  static Future<bool> connect(
      String serverIp, int port, String username, String password) async {
    _client = MqttServerClient.withPort(serverIp, clientID, port);
    _client!.logging(on: true); // Enable logging
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = onDisconnected;
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientID)
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.exactlyOnce);
    _client!.connectionMessage = connMessage;

    try {
      print('Attempting to connect to the server...');
      await _client!.connect();
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT client connected');
        return true;
      } else {
        // Optionally add a delay and check again
        await Future.delayed(Duration(seconds: 2));
        if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
          print('MQTT client connected after delay');
          return true;
        }
        throw Exception('Connection failed to establish');
      }
    } catch (e) {
      print('Connection failed: $e');
      _client!.disconnect();
      return false;
    }
  }

  static void onConnected() async {
    print('Connected to the MQTT server');
    publishMessage('test/topic', 'hello');
  }

  static void onDisconnected() {
    print('Disconnected from the MQTT server');
    clientID = generateRandomString(20);
    //_client!.unsubscribe(MqttService.setFloodDetectionStatus_topic);
    //_client!.unsubscribe('test/topic2');
  }

  static void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  static Future<void> publishMessage(String topic, String message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
    print('Message published to $topic: $message');
  }

  static void subscribeToTopic(String topic) async {
    if (isConnected() && !subscribedTopics.contains(topic)) {
      print("================================================================");
      subscribedTopics.add(topic);
      _client!.subscribe(topic, MqttQos.exactlyOnce);
      await _client!.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> c) async {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          String message = 'Received message: $pt from topic: ${c[0].topic}>';
          // Check if the message is already processed
          if (processedMessages.contains(pt)) {
            print('Duplicate message detected: $pt');
          } else {
            // Mark message as processed
            processedMessages.add(pt);
            print(message);

            if (c[0].topic == setFloodDetectionStatus_topic) {
              bool floodStatus = getFloodDetectionStatus(pt);
              setFloodStat(floodStatus);
              if (floodStatus == true) {
                await Future.delayed(Duration(seconds: 1));
              }
            } else if (c[0].topic == setFloodDetectionLastTrigger_topic) {
              print(
                  "The last trigger of the flood detection module was in: ${pt}");
              setFloodLastTrigger(pt);
            } else if (c[0].topic == setFloodDetectionTriggerStatus_topic) {
              setFloodStat(true);
              await Future.delayed(Duration(seconds: 1));
              updateNotifications(
                  "🚰 A flood has been detected in your home at ${pt}");
            } else if (c[0].topic == setFloodDetectionBattery_topic) {
              int battery = int.parse(pt);
              setFloodBattery(battery);
              await Future.delayed(Duration(seconds: 1));
              if (battery <= 25) {
                updateNotifications(
                    "🔋 The flood detection device battery is at ${battery}%. Please replace the battery as soon as possible.");
              }
            } else if (c[0].topic == setFloodDetectionHistory_topic) {
              setFloodHistory(List<String>.from(jsonDecode(pt)));
              await Future.delayed(Duration(seconds: 1));
            } else if (c[0].topic == setAlarmStatus_topic) {
              bool alarmStatus = getAlarmStatus(pt);
              String causeOfTrigger = getAlarmTriggerCause(pt);
              setAlarmStatus(alarmStatus);
              setAlarmTriggerCause(causeOfTrigger);
              await Future.delayed(Duration(seconds: 1));
            } else if (c[0].topic == setAlarmTriggerStatus_topic) {
              String causeOfTrigger = getAlertTriggerCause(pt);
              setAlarmTriggerCause(causeOfTrigger);
              updateNotifications(
                  "🚨 The alarm module has been triggered due to: ${causeOfTrigger}");
              await Future.delayed(Duration(seconds: 1));
            } else if (c[0].topic == setAlarmLastTrigger_topic) {
              print("The last trigger of the alarm module was in: ${pt}");
              setAlarmLastTrigger(pt);
              await Future.delayed(Duration(seconds: 1));
            } else if (c[0].topic == setAlarmHistory_topic) {
              setAlarmHistory(pt);
              await Future.delayed(Duration(seconds: 1));
            } else if (c[0].topic == setAlarmBattery_topic) {
              int battery = int.parse(pt);
              setAlarmBattery(battery);
              await Future.delayed(Duration(seconds: 1));
              if (battery <= 25) {
                updateNotifications(
                    "🔋 The alarm module battery is at ${battery}%. Please recharge the battery as soon as possible.");
              }
            } else if (c[0].topic == setRelaysStatus_topic) {
              List<String> relaysStatus = getRelaysStatus(pt);
              setRelaysStatus(relaysStatus);

              await Future.delayed(Duration(seconds: 1));
            }
          }
        },
      );
    } else {
      print('Cannot subscribe, MQTT client is not connected');
    }
  }

  static void setFloodStat(bool Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setBool('FloodStat', Value);
  }

  static void setFloodLastTrigger(String Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString('LastTrigger', Value);
  }

  static void setFloodBattery(int Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setInt('FloodBattery', Value);
  }

  static void setFloodHistory(List<String> Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setStringList('FloodHistory', Value);
  }

  static void setAlarmStatus(bool Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setBool('AlarmStatus', Value);
  }

  static void setAlarmTriggerCause(String Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString('AlarmTriggerCause', Value);
  }

  static void setAlarmLastTrigger(String Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString('AlarmLastTrigger', Value);
  }

  static void setAlarmHistory(String Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString('AlarmHistory', Value);
  }

  static void setAlarmBattery(int Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setInt('AlarmBattery', Value);
  }

  static void setRelaysStatus(List<String> Value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setBool('relay1On', Value[0] == "ON");
    await prefs.setBool('relay2On', Value[1] == "ON");
    await prefs.setString('lastOnRelay1', Value[2]);
    await prefs.setString('lastOnRelay2', Value[3]);
  }

  static void lowerAlert() async {
    publishMessage(lowerFloodDetectionAlert_topic, "Lower Alert");
  }

  static Future<void> lowerAlarmAlert() async {
    publishMessage(lowerAlarmAlert_topic, "Lower Alarm Alert");
  }

  static void tryToConnect() async {
    if (isConnected()) {
      print("Client is already connected to the server");
    } else {
      final prefs = await SharedPreferences.getInstance();
      bool? _autoConnect = prefs.getBool('autoConnect');
      if (_autoConnect == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? serverIp = prefs.getString('serverIp') ?? '';
        String? username = prefs.getString('username') ?? '';
        String? password = prefs.getString('password') ?? '';
        int? port = int.tryParse(prefs.getString('port') ?? '1883') ?? 1883;
        print(
            'Attempting to connect with settings: serverIp=$serverIp, username=$username, port=$port');
        bool isConnected =
            await MqttService.connect(serverIp, port, username, password);
        if (isConnected) {
          print("Client is successfully connected to the server");
        } else {
          print("Cannot connect to the mqtt server!");
        }
      } else {
        print(
            "Auto connection is set to false, and the client is not connected to the server.");
      }
    }
  }

  static void disconnect(BuildContext context) async {
    _client?.disconnect();
    setAutoConnect(false); // Set auto-connect to false when disconnecting
    print('Disconnected from the MQTT server and auto-connect disabled');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SettingsForm()),
      (Route<dynamic> route) => false, // Remove all other routes
    );
    globals.isPowerAlertShownBefore = false;
    globals.isPowerTrailingBtnShownBefore = false;
  }

  static void setAutoConnect(bool value) {
    _autoConnect = value;
    saveSettings(); // Save the auto-connect setting
    print('Auto-connect set to $value');
  }

  static bool get autoConnect => _autoConnect;

  static bool isConnected() {
    try {
      if (_client != null &&
          _client!.connectionStatus != null &&
          _client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MqttClient is connected');
        return true;
      } else {
        print('MqttClient is not connected');
        return false;
      }
    } catch (e) {
      print('Error checking connection status: $e');
      return false;
    }
  }

  static void requestFloodDetectionStatus() async {
    if (isConnected()) {
      publishMessage(getFloodDetectionStatus_topic,
          'what is the status of the flood detection module now?');
    } else {
      tryToConnect();
    }
  }

  static void requestFloodDetectionLastTrigger() async {
    if (isConnected()) {
      publishMessage(getFloodDetectionLastTrigger_topic,
          'when was the flood detection module last triggered?');
    } else {
      tryToConnect();
    }
  }

  static void requestFloodDetectionBattery() async {
    if (isConnected()) {
      publishMessage(getFloodDetectionBattery_topic,
          "what is the battery percentage of the flood detection module?");
    } else {
      tryToConnect();
    }
  }

  static void requestFloodDetectionHistory() async {
    if (isConnected()) {
      publishMessage(getFloodDetectionHistory_topic,
          "send me the history of triggers for the flood detection module.");
    } else {
      tryToConnect();
    }
  }

  static void requestAlarmLastTrigger() async {
    if (isConnected()) {
      publishMessage(getAlarmLastTrigger_topic,
          "when was the alarm module last triggered?");
    } else {
      tryToConnect();
    }
  }

  static void requestAlarmStatus() async {
    if (isConnected()) {
      publishMessage(
          getAlarmStatus_topic, "what is the status of the alarm module now?");
    } else {
      tryToConnect();
    }
  }

  static void requestAlarmHistory() async {
    if (isConnected()) {
      publishMessage(getAlarmHistory_topic,
          "send me the history of triggers for the alarm module.");
    } else {
      tryToConnect();
    }
  }

  static void requestAlarmBattery() async {
    if (isConnected()) {
      publishMessage(getAlarmBattery_topic,
          "what is the battery percentage of the flood detection module?");
    } else {
      tryToConnect();
    }
  }

  static void requestRelaysStatus() async {
    if (isConnected()) {
      publishMessage(
          getRelaysStatus_topic, "what is the status of the relays module?");
    } else {
      tryToConnect();
    }
  }

  static bool getFloodDetectionStatus(String msg) {
    print("Flood Detection Status is: '${msg}'");
    if (msg == "Triggered") {
      return true;
    } else {
      return false;
    }
  }

  static bool getAlarmStatus(String msg) {
    // Split the message by space and then take the second part which contains the status
    List<String> parts = msg.split(' ');
    String statusPart = parts[2];

    // Further split the status part to get only the status word
    String timeAndStatus = statusPart.split(',')[0];
    print(timeAndStatus);
    String status = timeAndStatus.split('<')[1];

    if (status == "Triggered") {
      print("Alarm Status is: Triggered");
      return true;
    } else {
      print("Alarm Status is: Not Triggered");
      return false;
    }
  }

  static String getAlarmTriggerCause(String msg) {
    // Check if the message contains "Triggered"
    if (!msg.contains("Not Triggered")) {
      // Split the message to find the part that contains the cause
      List<String> parts = msg.split('<');
      if (parts.length > 1) {
        String causePart = parts[1];
        List<String> causeParts = causePart.split(': ');
        if (causeParts.length > 1) {
          return causeParts[1].replaceAll('>', '').trim();
        }
      }
    }
    return "No cause"; // or return an empty string or a default value
  }

  static String getAlertTriggerCause(String msg) {
    // Check if the message contains "Triggered"

    List<String> parts = msg.split('<');

    String causePart = parts[1];
    List<String> causeParts = causePart.split(': ');
    List<String> cause = causeParts[1].split("'");
    if (cause.length > 1) {
      return cause[1].trim();
    } else {
      return cause[0].replaceAll('>', '').trim();
    }
  }

  static List<String> getRelaysStatus(String msg) {
    List<String> parts = msg.split('<');
    List<String> status = parts[1].split(', ');
    return [
      status[0],
      status[1],
      status[2],
      status[3].replaceAll('>', '').trim()
    ];
  }
}
