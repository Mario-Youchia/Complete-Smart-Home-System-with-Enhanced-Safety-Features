// settings_form.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'loading_page.dart';
import 'mqtt_service.dart';
import 'my_home_page.dart';

class SettingsForm extends StatefulWidget {
  @override
  _SettingsFormState createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController serverIpController;
  late TextEditingController usernameController;
  late TextEditingController passwordController;
  late TextEditingController portController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    serverIpController = TextEditingController();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
    portController = TextEditingController();
    _loadSavedData();
  }

  void _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      serverIpController.text = prefs.getString('lastServerIp') ?? '';
      usernameController.text = prefs.getString('lastUsername') ?? '';
      passwordController.text = prefs.getString('lastPassword') ?? '';
      portController.text = prefs.getString('lastPort') ?? '1883';
      print(
          'Loaded settings: serverIp=${serverIpController.text}, username=${usernameController.text}, port=${portController.text}');
    });
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      // Save settings to MQTT service
      // Assuming the connect method will save the settings internally
      bool connected = await MqttService.connect(
          serverIpController.text,
          int.tryParse(portController.text)!,
          usernameController.text,
          passwordController.text);
      if (connected) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('serverIp', serverIpController.text);
        await prefs.setString('username', usernameController.text);
        await prefs.setString('password', passwordController.text);
        await prefs.setString('port', portController.text);
        MqttService.setAutoConnect(
            true); // Enable auto-connect on successful save
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => MyHomePage()), // Navigate to the home page
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog();

      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Connection Failed"),
          content: Text("Please check your settings and try again."),
          actions: <Widget>[
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
  void dispose() {
    serverIpController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: null,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: serverIpController,
                decoration: InputDecoration(labelText: 'Server IP'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the server IP';
                  }
                  return null;
                },
                onSaved: (value) {
                  serverIpController.text = value!;
                },
              ),
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
                onSaved: (value) {
                  usernameController.text = value!;
                },
              ),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
                onSaved: (value) {
                  passwordController.text = value!;
                },
              ),
              TextFormField(
                controller: portController,
                decoration: InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the port';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) {
                  portController.text = value!;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text('Save'),
              ),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
