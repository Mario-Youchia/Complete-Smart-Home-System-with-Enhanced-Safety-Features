#include <ESP8266WiFi.h>
#include <ESP8266WebServerSecure.h>
#include <FS.h>
#include <PubSubClient.h>

#define resetButtonPin 13
#define ledPin 12
#define enablePin 5
#define adcEnablePin 14
#define shutdownPin 4

const char* defaultSSID = "Flood Detection Module";
const char* defaultPassword = "";
unsigned long buttonPressedTime = 0;
bool resetTriggered = false;
bool serverStarted = false;
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
static unsigned long shutdownTime = 0;
bool isConnectedToServer = false;
bool isFirstConnection = false;

BearSSL::ESP8266WebServerSecure server(443);

void listSPIFFS() {
  Serial.println("SPIFFS contents:");
  Dir dir = SPIFFS.openDir("/");
  while (dir.next()) {
    Serial.print(dir.fileName());
    Serial.print(" - ");
    Serial.println(dir.fileSize());
  }
}

void loadCertificates() {
  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system");
    return;
  }

  listSPIFFS();  // List contents for debugging

  File cert = SPIFFS.open("/cert.crt", "r");
  File privateKey = SPIFFS.open("/private.key", "r");

  if (!cert) {
    Serial.println("Failed to open certificate file");
  } else {
    Serial.println("Successfully opened certificate file");
  }

  if (!privateKey) {
    Serial.println("Failed to open private key file");
  } else {
    Serial.println("Successfully opened private key file");
  }

  if (!cert || !privateKey) {
    Serial.println("Failed to open certificate or private key file");
    return;
  }

  String certStr = cert.readString();
  String keyStr = privateKey.readString();

  server.getServer().setRSACert(new BearSSL::X509List(certStr.c_str()), new BearSSL::PrivateKey(keyStr.c_str()));

  cert.close();
  privateKey.close();
}

String getWiFiNetworks() {
  int n = WiFi.scanNetworks();
  String networks = "";
  for (int i = 0; i < n; ++i) {
    networks += "<option value='" + WiFi.SSID(i) + "'>" + WiFi.SSID(i) + "</option>";
  }
  return networks;
}
/*
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><title>WiFi Setup</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; padding: 10px; box-sizing: border-box; }";
  html += "form { text-align: center; border: 1px solid #ccc; padding: 20px; border-radius: 10px; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); width: 100%; max-width: 400px; box-sizing: border-box; }";
  html += "label { display: block; margin-top: 20px; font-weight: bold; }";  // Make labels bold
  html += "select, input[type='text'], input[type='password'], input[type='submit'] { width: 100%; padding: 10px; margin-top: 5px; box-sizing: border-box; }";
  html += "input[type='submit'] { background-color: #4CAF50; color: white; margin-top: 20px; cursor: pointer; }";
  html += "</style></head><body>";
  html += "<form action=\"/submit\" method=\"POST\">";
  html += "<h1>WiFi Setup</h1>";
  html += "<label for='ssid'>SSID:</label>";
  html += "<select id='ssid' name='ssid'><option value='' selected='selected'></option>" + getWiFiNetworks() + "</select>";  // Add a blank option
  html += "<label for='password'>Password:</label><input type='password' id='password' name='password'>";
  html += "<input type='submit' value='Enter'>";
  html += "</form>";
  html += "</body></html>";

  server.send(200, "text/html", html);
}
*/
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><title>WiFi and MQTT Setup</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; padding: 10px; box-sizing: border-box; }";
  html += "form { text-align: center; border: 1px solid #ccc; padding: 20px; border-radius: 10px; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); width: 100%; max-width: 400px; box-sizing: border-box; }";
  html += "label { display: block; margin-top: 20px; font-weight: bold; }";
  html += "select, input[type='text'], input[type='password'], input[type='submit'] { width: 100%; padding: 10px; margin-top: 5px; box-sizing: border-box; }";
  html += "input[type='submit'] { background-color: #4CAF50; color: white; margin-top: 20px; cursor: pointer; }";
  html += "</style></head><body>";
  html += "<form action=\"/submit\" method=\"POST\">";
  html += "<h1>WiFi and MQTT Setup</h1>";
  html += "<label for='ssid'>SSID:</label>";
  html += "<select id='ssid' name='ssid'><option value='' selected='selected'></option>" + getWiFiNetworks() + "</select>";
  html += "<label for='password'>Password:</label><input type='password' id='password' name='password'>";
  html += "<label for='mqttServer'>MQTT Server:</label><input type='text' id='mqttServer' name='mqttServer'>";
  html += "<label for='mqttPort'>MQTT Port:</label><input type='text' id='mqttPort' name='mqttPort'>";
  html += "<label for='mqttUser'>MQTT User:</label><input type='text' id='mqttUser' name='mqttUser'>";
  html += "<label for='mqttPassword'>MQTT Password:</label><input type='password' id='mqttPassword' name='mqttPassword'>";
  html += "<input type='submit' value='Enter'>";
  html += "</form>";
  html += "</body></html>";

  server.send(200, "text/html", html);
}



/*
void handleSubmit() {
  String ssid = server.arg("ssid");
  String password = server.arg("password");

  WiFi.begin(ssid.c_str(), password.c_str());

  int timeout = 10;  // 10 seconds timeout
  while (WiFi.status() != WL_CONNECTED && timeout > 0) {
    delay(1000);
    timeout--;
  }

  String html = "<!DOCTYPE html><html><head><title>WiFi Connection Status</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; padding: 10px; box-sizing: border-box; }";
  html += "div { text-align: center; border: 1px solid #ccc; padding: 20px; border-radius: 10px; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); width: 100%; max-width: 400px; box-sizing: border-box; }";
  html += ".success { color: #4CAF50; }";
  html += ".fail { color: #FF0000; }";
  html += "p { color: black; }";
  html += "</style></head><body>";

  if (WiFi.status() == WL_CONNECTED) {
    html += "<div class='success'><h1>Connected to WiFi</h1>";
    html += "<p>SSID: " + ssid + "</p>";
    html += "</div>";

    // Save credentials to file if connected successfully
    if (!SPIFFS.begin()) {
      Serial.println("Failed to mount file system for writing");
    } else {
      File f = SPIFFS.open("/wifi_cred.txt", "w");  // Open a file for writing
      if (!f) {
        Serial.println("File open failed");
      } else {
        f.println(ssid);
        f.println(password);
        f.close();
        Serial.println("WiFi credentials saved");
      }
      SPIFFS.remove("/reset_flag.txt");  // Remove reset flag file
    }
    delay(5000);
    ESP.restart();
  } else {
    html += "<div class='fail'><h1>Failed to Connect</h1>";
    html += "<p>Check your credentials and try again.</p>";
    html += "</div>";
  }

  html += "</body></html>";

  server.send(200, "text/html", html);
}
*/

void handleSubmit() {
  String ssid = server.arg("ssid");
  String password = server.arg("password");
  String mqttServer = server.arg("mqttServer");
  String mqttPort = server.arg("mqttPort");
  String mqttUser = server.arg("mqttUser");
  String mqttPassword = server.arg("mqttPassword");

  WiFi.begin(ssid.c_str(), password.c_str());

  int timeout = 10;  // 10 seconds timeout
  while (WiFi.status() != WL_CONNECTED && timeout > 0) {
    delay(1000);
    timeout--;
  }

  String html = "<!DOCTYPE html><html><head><title>Connection Status</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; padding: 10px; box-sizing: border-box; }";
  html += "div { text-align: center; border: 1px solid #ccc; padding: 20px; border-radius: 10px; box-shadow: 0px 0px 10px rgba(0,0,0,0.1); width: 100%; max-width: 400px; box-sizing: border-box; }";
  html += ".success { color: #4CAF50; }";
  html += ".fail { color: #FF0000; }";
  html += "p { color: black; }";
  html += "</style></head><body>";

  if (WiFi.status() == WL_CONNECTED) {
    html += "<div class='success'><h1>Connected to WiFi</h1>";
    html += "<p>SSID: " + ssid + "</p>";
    html += "</div>";

    // Save WiFi credentials to file if connected successfully
    if (!SPIFFS.begin()) {
      Serial.println("Failed to mount file system for writing");
    } else {
      File f = SPIFFS.open("/wifi_cred.txt", "w");  // Open a file for writing
      if (!f) {
        Serial.println("File open failed");
      } else {
        f.println(ssid);
        f.println(password);
        f.close();
        Serial.println("WiFi credentials saved");
      }
      SPIFFS.remove("/reset_flag.txt");  // Remove reset flag file
    }

    // Connect to MQTT server
    WiFiClient wifiClient;
    PubSubClient mqttClient(wifiClient);
    mqttClient.setServer(mqttServer.c_str(), mqttPort.toInt());
    Serial.print("Received MQTT Server: ");
    Serial.println(mqttServer.c_str());
    Serial.print("Received MQTT Port: ");
    Serial.println(mqttPort.toInt());
    Serial.print("Received MQTT Username: ");
    Serial.println(mqttUser.c_str());
    Serial.print("Received MQTT Password: ");
    Serial.println(mqttPassword.c_str());
    if (mqttClient.connect("ESP8266Client-1", mqttUser.c_str(), mqttPassword.c_str())) {
      Serial.println("MQTT connected");

      // Save MQTT credentials to file
      if (!SPIFFS.begin()) {
        Serial.println("Failed to mount file system for writing");
      } else {
        File f = SPIFFS.open("/mqtt_cred.txt", "w");  // Open a file for writing
        if (!f) {
          Serial.println("File open failed");
        } else {
          f.println(mqttServer);
          f.println(mqttPort);
          f.println(mqttUser);
          f.println(mqttPassword);
          f.close();
          Serial.println("MQTT credentials saved");
        }
      }
      // Set connection flag
      writeConnectionFlag(false);

      html += "<div class='success'><h1>Connected to MQTT server</h1>";
      html += "<p>Connected to MQTT server: " + mqttServer + "</p>";
      html += "</div>";
      html += "</body></html>";
      server.send(200, "text/html", html);

      //delay(5000);
      ESP.restart();
    } else {
      Serial.println("MQTT connection failed");
      html += "<div class='fail'><h1>MQTT Connection Failed</h1>";
      html += "<p>Check your MQTT credentials and try again.</p>";
      html += "</div>";
    }
  } else {
    html += "<div class='fail'><h1>Failed to Connect to WiFi</h1>";
    html += "<p>Check your WiFi credentials and try again.</p>";
    html += "</div>";
  }

  html += "</body></html>";

  server.send(200, "text/html", html);
}

void readWiFiCredentials(String& ssid, String& password) {
  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system for reading");
    ssid = defaultSSID;
    password = defaultPassword;
    return;
  }

  File f = SPIFFS.open("/wifi_cred.txt", "r");
  if (!f) {
    Serial.println("Failed to open file for reading");
    ssid = defaultSSID;
    password = defaultPassword;
  } else {
    ssid = f.readStringUntil('\n');
    password = f.readStringUntil('\n');
    ssid.trim();
    password.trim();
    f.close();
  }
}

void readMQTTCredentials(String& mqttServer, String& mqttPort, String& mqttUser, String& mqttPassword) {
  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system for reading");
    return;
  }

  File f = SPIFFS.open("/mqtt_cred.txt", "r");
  if (!f) {
    Serial.println("Failed to open file for reading MQTT credentials");
  } else {
    mqttServer = f.readStringUntil('\n');
    mqttPort = f.readStringUntil('\n');
    mqttUser = f.readStringUntil('\n');
    mqttPassword = f.readStringUntil('\n');
    mqttServer.trim();
    mqttPort.trim();
    mqttUser.trim();
    mqttPassword.trim();
    f.close();
  }
}

bool readConnectionFlag() {
  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system for reading connection flag");
    return false;
  }

  File f = SPIFFS.open("/connection_flag.txt", "r");
  if (!f) {
    Serial.println("Failed to open file for reading connection flag");
    return false;
  } else {
    String flag = f.readStringUntil('\n');
    flag.trim();
    f.close();
    return (flag == "1");
  }
}

void writeConnectionFlag(bool connected) {
  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system for writing connection flag");
    return;
  }

  File f = SPIFFS.open("/connection_flag.txt", "w");
  if (!f) {
    Serial.println("Failed to open file for writing connection flag");
  } else {
    f.println(connected ? "1" : "0");
    f.close();
  }
}


void setup() {
  ESP.eraseConfig();

  Serial.begin(115200);
  pinMode(resetButtonPin, INPUT);
  pinMode(ledPin, OUTPUT);
  pinMode(enablePin, OUTPUT);
  pinMode(adcEnablePin, OUTPUT);
  pinMode(shutdownPin, OUTPUT);

  if (!SPIFFS.begin()) {
    Serial.println("Failed to mount file system");
    return;
  }

  listSPIFFS();  // List SPIFFS contents for debugging
  loadCertificates();

  String ssid;
  String password;
  String mqttServer;
  String mqttPort;
  String mqttUser;
  String mqttPassword;
  bool connectionFlag = readConnectionFlag();
  File resetFlagFile = SPIFFS.open("/reset_flag.txt", "r");
  File credFile = SPIFFS.open("/wifi_cred.txt", "r");
  //String flag = resetFlagFile.readString();
  String flag = resetFlagFile.readStringUntil('\n');
  flag.trim();
  if (!resetFlagFile || flag != "1") {  // No reset flag or flag not set
    if (credFile) {                     // Credentials file exists
      readMQTTCredentials(mqttServer, mqttPort, mqttUser, mqttPassword);
      readWiFiCredentials(ssid, password);
      credFile.close();
      WiFi.mode(WIFI_STA);
      WiFi.begin(ssid.c_str(), password.c_str());
      Serial.print("Trying to connect to: ");
      Serial.println(ssid);

      int timeout = 10 * 2;
      while (WiFi.status() != WL_CONNECTED && timeout > 0) {
        delay(500);
        Serial.print(".");
        timeout--;  // 10 seconds
      }
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("");
        Serial.print("Connected to ");
        Serial.println(ssid);
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
        // Connect to MQTT server
        mqttClient.setServer(mqttServer.c_str(), mqttPort.toInt());
        isConnectedToServer = mqttClient.connect("ESP8266Client-1", mqttUser.c_str(), mqttPassword.c_str());
        if (isConnectedToServer) {
          Serial.println("MQTT connected");
          if (!connectionFlag) {
            // This is the first successful connection after setting credentials
            writeConnectionFlag(true);  // Set the flag to indicate successful connection
            isFirstConnection = true;
          } else {
            // Publish message to MQTT server.
            mqttClient.publish("test/topic", "hello from device 1");
          }
        } else {
          Serial.println("MQTT connection failed");
        }
      } else {
        Serial.println("Connection failed, starting AP mode...");
        WiFi.softAP(defaultSSID, defaultPassword);
        IPAddress IP = WiFi.softAPIP();
        Serial.print("AP IP address: ");
        Serial.println(IP);
        serverStarted = true;
      }
    } else {  // No credentials file, start AP mode
      Serial.println("No WiFi credentials, starting AP mode...");
      WiFi.softAP(defaultSSID, defaultPassword);
      IPAddress IP = WiFi.softAPIP();
      Serial.print("AP IP address: ");
      Serial.println(IP);
      serverStarted = true;
    }
  } else {  // Reset flag is set
    resetFlagFile.close();
    WiFi.softAP(defaultSSID, defaultPassword);
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);
    serverStarted = true;
  }
  if (serverStarted) {
    server.on("/", handleRoot);
    server.on("/submit", HTTP_POST, handleSubmit);

    server.begin();
    Serial.println("HTTPS server started");
  }

  digitalWrite(ledPin, LOW);

  shutdownTime = millis();
  digitalWrite(enablePin, HIGH);  // to maintain power
}

void loop() {
  if (millis() - shutdownTime > 120000) {  // wait for two minutes before shutdown the device immediately
    digitalWrite(enablePin, LOW);
    digitalWrite(shutdownPin, HIGH);
  } else if (millis() - shutdownTime > 60000) {  // wait for one minute before diabling the power (in this case the device will shutdown within one minute)
    digitalWrite(enablePin, LOW);
  }

  if (serverStarted) {
    server.handleClient();
    digitalWrite(ledPin, !digitalRead(ledPin));
    delay(1000);
  }

  // Check for a button press to reset the device
  static bool buttonPressed = false;
  static unsigned long buttonPressTime = 0;

  int buttonState = digitalRead(resetButtonPin);

  // Button is pressed
  if (buttonState == HIGH) {
    if (!buttonPressed) {  // Button press is detected for the first time
      buttonPressed = true;
      buttonPressTime = millis();                     // Start timing
    } else if (millis() - buttonPressTime > 10000) {  // Check if button is held down for 10 seconds
      // Perform reset actions
      SPIFFS.remove("/wifi_cred.txt");               // Delete the credentials file
      SPIFFS.remove("/reset_flag.txt");              // Remove reset flag file
      SPIFFS.remove("/mqtt_cred.txt");               // Remove the mqtt credentials file
      File f = SPIFFS.open("/reset_flag.txt", "w");  // Set a reset flag
      if (f) {
        f.println("1");
        f.close();
      } else {
        Serial.println("Failed to open file for writing reset flag.");
      }
      resetTriggered = true;
      ESP.restart();  // Restart the ESP
      return;
    }
  } else {
    // Button is released
    buttonPressed = false;
    if (serverStarted == false) {
      if (isConnectedToServer) {
        if (!isFirstConnection) {
          digitalWrite(adcEnablePin, HIGH);  // to start the adc process
          digitalWrite(shutdownPin, LOW);    // to avoid shutdown before sending the message
          mqttClient.publish("devices/flood/flood_trigger", "Flood Detected");
          delay(3000);  // time for signal acquisition and conversion
          int adcValue = analogRead(A0);
          float adc_value = ((((adcValue * 0.0009765625) * 3.2) - 2.5) * 1.428571428) * 100;
          int adc = round(adc_value);
          if (adc < 0) {
            adc = 0;
          }
          mqttClient.publish("devices/flood/battery", String(adc).c_str());
          digitalWrite(enablePin, LOW);     // no power maintaining
          digitalWrite(adcEnablePin, LOW);  // disabling the ADC
          digitalWrite(shutdownPin, HIGH);  // immediate power off
          delay(2000);                      // wait for shutdown
        } else {
          // if this is the first successfult connection after reset, then there is no need to do anything, just return to the standby state
          digitalWrite(enablePin, LOW);     // no power maintaining
          digitalWrite(adcEnablePin, LOW);  // disabling the ADC
          digitalWrite(shutdownPin, HIGH);  // immediate power off
        }
      } else {
        // If not connected to the server, immediately power off
        digitalWrite(enablePin, LOW);     // no power maintaining
        digitalWrite(adcEnablePin, LOW);  // disabling the ADC
        digitalWrite(shutdownPin, HIGH);  // immediate power off
      }
    }
  }
}
