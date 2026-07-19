import paho.mqtt.client as mqtt
import mysql.connector
import re
import socket, ssl
import datetime
import json
import time

# Database connection parameters
db_config = {
    'user': 'root',
    'password': 'NewP@ssw0rd123!',
    'host': 'localhost',
    'database': 'SmartHomeDevices',
    'raise_on_warnings': True,
    'use_pure': True,  # Ensure the pure Python interface if SSL issues persist
    'ssl_disabled': True  # Disable SSL
}

device_ids = {
    'Flood Detection Module': 1,
    'Power Meter Module': 2,
    'Alarm Module': 3,
    'Dual-Channel Relay Module': 4
}

# MQTT Parameters
MQTT_BROKER = '192.168.1.100'
MQTT_PORT = 1883
MQTT_USERNAME = "admin"
MQTT_PASSWORD = "1234"

flood_detection_module_topics = {
    'get_status': 'mobile/flood/status/get_status',
    'set_status': 'mobile/flood/status/set_status',
    'get_last_trigger': 'mobile/flood/status/get_last_trigger',
    'set_last_trigger': 'mobile/flood/status/set_last_trigger',
    'lower_alert': 'mobile/flood/alert/lower_alert',
    'raise_alert': 'mobile/flood/alert/raise_alert',
    'get_battery': 'mobile/flood/battery/get_battery',
    'set_battery': 'mobile/flood/battery/set_battery',
    'get_history': 'mobile/flood/history/get_history',
    'set_history': 'mobile/flood/history/set_history',

    'trigger': 'devices/flood/flood_trigger',
    'battery': 'devices/flood/battery'
}

alarm_module_topics = {
    'get_status': 'mobile/alarm/status/get_status',
    'set_status': 'mobile/alarm/status/set_status',
    'raise_alert': 'mobile/alarm/alert/raise_alert',
    'lower_alert': 'mobile/alarm/alert/lower_alert',
    'get_last_trigger': 'mobile/alarm/status/get_last_trigger',
    'set_last_trigger': 'mobile/alarm/status/set_last_trigger',
    'get_history': 'mobile/alarm/history/get_history',
    'set_history': 'mobile/alarm/history/set_history',
    'get_battery': 'mobile/alarm/battery/get_battery',
    'set_battery': 'mobile/alarm/battery/set_battery',

    'trigger': 'devices/alarm/alarm_trigger',
    'battery': 'devices/alarm/battery'
}

relays_module_topics = {
    'get_status': 'mobile/relays/status/get_status',
    'set_status': 'mobile/relays/status/set_status'
}

# Connect to the database
db = mysql.connector.connect(**db_config)
cursor = db.cursor()
import datetime

def update_battery_percentage_and_time(device_id, battery_percentage, current_time):
    query = "UPDATE devices SET battery_percentage = %s, last_checked = %s WHERE device_id = %s"
    cursor.execute(query, (battery_percentage, current_time, device_id))
    db.commit()
    print("Battery and last check time updated for device_id:", device_id)

def log_flood_trigger(device_id, current_time):
    query = "INSERT INTO FloodDetectionHistory (device_id, trigger_datetime) VALUES (%s, %s)"
    cursor.execute(query, (device_id, current_time))
    db.commit()
    print("Flood event logged for device_id:", device_id, "at", current_time)

def log_alarm_trigger(device_id, current_time, cause):
    query = "INSERT INTO AlarmHistory (device_id, trigger_datetime, trigger_cause) VALUES (%s, %s, %s)"
    cursor.execute(query, (device_id, current_time, cause))
    db.commit()
    print("Alarm event logged for device_id:", device_id, "at", current_time, "caused by:", cause)

def flood_send_status(device_id):
    query = "SELECT status FROM devices WHERE device_id = %s"
    cursor.execute(query, (device_id,))
    status = cursor.fetchone()
    print(f"Flood detection status is: {status[0]}")
    publish(flood_detection_module_topics['set_status'], status[0])

def flood_send_last_trigger():
    query = "SELECT trigger_datetime FROM FloodDetectionHistory ORDER BY trigger_datetime DESC LIMIT 1;"
    cursor.execute(query)
    status = cursor.fetchone()
    print(f'Flood detection last trigger is: {status[0]}')
    last_trigger_time = status[0].strftime('%Y-%m-%d %H:%M:%S')
    publish(flood_detection_module_topics['set_last_trigger'], last_trigger_time)
    current_time = datetime.datetime.now()
    query = "UPDATE devices SET last_checked = %s WHERE device_id = 1"
    cursor.execute(query, (current_time, ))
    db.commit()
    print("Last check time updated for flood detection device")

def flood_lower_alert():
    query = "UPDATE devices SET status = 'Not Triggered' WHERE device_id = 1"
    cursor.execute(query)
    db.commit()
    print("Flood detection module alert is lowered")

def flood_raise_alert(trigger_time):
    log_flood_trigger(1, trigger_time)
    str_trigger_time = trigger_time.strftime('%Y-%m-%d %H:%M:%S')
    publish(flood_detection_module_topics['raise_alert'], str_trigger_time)
    query = "UPDATE devices SET status = 'Triggered' WHERE device_id = 1"
    cursor.execute(query)
    db.commit()
    print(f"Flood detection triggered at: {str_trigger_time}")
    alarm_raise_alert(trigger_time, "Flood Detected")

def flood_send_battery():
    query = "SELECT battery_percentage FROM devices WHERE device_id = 1"
    cursor.execute(query)
    status = cursor.fetchone()
    print(f"Flood detection battery percentage is: {status[0]}")
    publish(flood_detection_module_topics['set_battery'], status[0])

def flood_update_battery(batteryPercentage):
    query = "UPDATE devices SET battery_percentage = %s WHERE device_id = 1"
    cursor.execute(query, (int(batteryPercentage),))
    db.commit()
    print(f"Flood detection battery percentage is: {int(batteryPercentage)}")

def flood_send_history():
    query = "SELECT trigger_datetime FROM FloodDetectionHistory"
    cursor.execute(query)
    status = cursor.fetchall()
    status = [str(item[0]) for item in status]
    status_json = json.dumps(status)
    print(f"Flood detection triggers history is: {status_json}")
    publish(flood_detection_module_topics['set_history'], status_json)

def alarm_send_status():
    query = "SELECT status FROM devices WHERE device_id = 3"
    cursor.execute(query)
    status = cursor.fetchone()
    print(f"Alarm module status is: '{status[0]}'")
    if (status[0] == "Triggered"):
        query = "SELECT trigger_cause FROM AlarmHistory WHERE device_id = 3 ORDER BY trigger_datetime DESC LIMIT 1"
        cursor.execute(query)
        cause = cursor.fetchone()
        print(f"Alarm module is triggered due to: {cause[0]}")
        publish(alarm_module_topics['set_status'], f"{datetime.datetime.now()} <{status[0]}, cause: {cause[0]}>")
    else:
        publish(alarm_module_topics['set_status'], f"{datetime.datetime.now()} <{status[0]}, cause: None>")

def alarm_raise_alert(trigger_time, cause):
    log_alarm_trigger(3, trigger_time, cause)
    trigger_time = trigger_time.strftime('%Y-%m-%d %H:%M:%S')
    publish(alarm_module_topics['raise_alert'], f"{datetime.datetime.now()} <{trigger_time}, cause: {str(cause)}>")
    query = "UPDATE devices SET status = 'Triggered' WHERE device_id = 3"
    cursor.execute(query)
    db.commit()
    print(f"Alarm module is triggered at: {trigger_time} and caused by: '{str(cause)}'")

def alarm_lower_alert():
    query = "UPDATE devices SET status = 'Not Triggered' WHERE device_id = 3"
    cursor.execute(query)
    db.commit()
    print("Alarm module alert is lowered")

def alarm_send_last_trigger():
    query = "SELECT trigger_datetime FROM AlarmHistory ORDER BY trigger_datetime DESC LIMIT 1;"
    cursor.execute(query)
    status = cursor.fetchone()
    print(f'Alarm module last trigger is: {status[0]}')
    last_trigger_time = status[0].strftime('%Y-%m-%d %H:%M:%S')
    publish(alarm_module_topics['set_last_trigger'], last_trigger_time)
    current_time = datetime.datetime.now()
    query = "UPDATE devices SET last_checked = %s WHERE device_id = 3"
    cursor.execute(query, (current_time, ))
    db.commit()
    print("Last check time updated for alarm module")

def alarm_send_history():
    query = "SELECT trigger_datetime, trigger_cause FROM AlarmHistory"
    cursor.execute(query)
    data = cursor.fetchall()
    data_list = []
    for item in data:
        row = {
            "trigger_datetime": item[0].strftime("%Y-%m-%d %H:%M:%S"),
            "trigger_cause": item[1]
        }
        data_list.append(row)
    data_json = json.dumps(data_list)
    print(f"Alarm module triggers history is: {data_json}")
    publish(alarm_module_topics['set_history'], data_json)

def alarm_send_battery():
    query = "SELECT battery_percentage FROM devices WHERE device_id = 3"
    cursor.execute(query)
    status = cursor.fetchone()
    print(f"Alarm module battery percentage is: {status[0]}")
    publish(alarm_module_topics['set_battery'], status[0])

def alarm_update_battery(batteryPercentage):
    query = "UPDATE devices SET battery_percentage = %s WHERE device_id = 3"
    cursor.execute(query, (int(batteryPercentage),))
    db.commit()
    print(f"Alarm module battery percentage is: {int(batteryPercentage)}")

def relays_send_status():
    query = "SELECT relay1_state, relay2_state FROM RelaySwitchEvents ORDER BY ID DESC LIMIT 1"
    cursor.execute(query)
    status = cursor.fetchone()
    relay1_state = status[0]
    relay2_state = status[1]
    query = "SELECT relay1_event_datetime FROM RelaySwitchEvents WHERE relay1_state = 'ON' ORDER BY relay1_event_datetime DESC LIMIT 1"
    cursor.execute(query)
    lastOnRelay1_status = cursor.fetchone()
    lastOnRelay1 = lastOnRelay1_status[0].strftime("%Y-%m-%d %H:%M:%S")
    query = "SELECT relay2_event_datetime FROM RelaySwitchEvents WHERE relay2_state = 'ON' ORDER BY relay2_event_datetime DESC LIMIT 1"
    cursor.execute(query)
    lastOnRelay2_status = cursor.fetchone()
    lastOnRelay2 = lastOnRelay2_status[0].strftime("%Y-%m-%d %H:%M:%S")
    print(f"Relays status is {datetime.datetime.now()} <{relay1_state}, {relay2_state}, {lastOnRelay1}, {lastOnRelay2}>")
    publish(relays_module_topics['set_status'], f"{datetime.datetime.now()} <{relay1_state}, {relay2_state}, {lastOnRelay1}, {lastOnRelay2}>")


def publish(topic, message):
    result = client.publish(topic, message)
    status = result[0]
    if status == 0:
        print(f"Sent `{message}` to topic `{topic}`")
    else:
        print(f"Failed to send message to topic {topic}")

# Callback when connecting to MQTT broker
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected successfully.")
        # Subscribe to the topic once connected.
        client.subscribe(flood_detection_module_topics['get_status'])
        client.subscribe(flood_detection_module_topics['get_last_trigger'])
        client.subscribe(flood_detection_module_topics['lower_alert'])
        client.subscribe(flood_detection_module_topics['trigger'])
        client.subscribe(flood_detection_module_topics['get_battery'])
        client.subscribe(flood_detection_module_topics['battery'])
        client.subscribe(flood_detection_module_topics['get_history'])
        client.subscribe(alarm_module_topics['get_status'])
        client.subscribe(alarm_module_topics['trigger'])
        client.subscribe(alarm_module_topics['lower_alert'])
        client.subscribe(alarm_module_topics['get_last_trigger'])
        client.subscribe(alarm_module_topics['get_history'])
        client.subscribe(alarm_module_topics['get_battery'])
        client.subscribe(alarm_module_topics['battery'])
        client.subscribe(relays_module_topics['get_status'])
    else:
        print("Connection failed with code", rc)

# Callback when receiving a message from MQTT broker
def on_message(client, userdata, msg):
    print(f"Message received-> {msg.topic} {str(msg.payload)}")
    #battery_search = re.search(r"Battery Percentage = (\d+\.?\d*)%", str(msg.payload))
    #current_time = datetime.datetime.now()
    #if battery_search:
        #battery_percentage = float(battery_search.group(1))
        #update_battery_percentage_and_time(1, battery_percentage, current_time)  # Assuming device_id is 1 for example
    #log_flood_trigger(1, current_time)  # Log the flood trigger event separately
    if (msg.topic == flood_detection_module_topics['get_status']):
       flood_send_status(device_ids['Flood Detection Module'])
    elif (msg.topic == flood_detection_module_topics['get_last_trigger']):
        flood_send_last_trigger()
    elif (msg.topic == flood_detection_module_topics['lower_alert']):
        flood_lower_alert()
    elif (msg.topic == flood_detection_module_topics['trigger']):
        flood_raise_alert(datetime.datetime.now())
    elif (msg.topic == flood_detection_module_topics['get_battery']):
        flood_send_battery()
    elif (msg.topic == flood_detection_module_topics['battery']):
        flood_update_battery(msg.payload)
    elif (msg.topic == flood_detection_module_topics['get_history']):
        flood_send_history()
    elif (msg.topic == alarm_module_topics['get_status']):
        alarm_send_status()
    elif (msg.topic == alarm_module_topics['trigger']):
        alarm_raise_alert(datetime.datetime.now(), msg.payload)
    elif (msg.topic == alarm_module_topics['lower_alert']):
        alarm_lower_alert()
    elif (msg.topic == alarm_module_topics['get_last_trigger']):
        alarm_send_last_trigger()
    elif (msg.topic == alarm_module_topics['get_history']):
        alarm_send_history()
    elif (msg.topic == alarm_module_topics['get_battery']):
        alarm_send_battery()
    elif (msg.topic == alarm_module_topics['battery']):
        alarm_update_battery(msg.payload)
    elif (msg.topic == relays_module_topics['get_status']):
        relays_send_status()

print(datetime.datetime.now())

# Setup MQTT client and hooks
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

# Set authentication details
client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)

# Connect to MQTT Broker
try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
except Exception as e:
    print("Failed to connect to MQTT broker:", e)

# Blocking loop to the MQTT broker
client.loop_forever()

