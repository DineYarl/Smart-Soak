#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <ESP8266WebServer.h>

const char* ssid = "Dinesh";
const char* password = "KhagaVahani!0";

const char* mqtt_server = "bbbe942594e74a1ebe91977e21569d1d.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;

const char* mqtt_username = "Dinesh";
const char* mqtt_password = "Dinesh200^";

const char* mqtt_status_topic = "smartsoak/status";
const char* mqtt_command_topic = "smartsoak/command";

ESP8266WebServer server(80);

const char* root_ca_cert = \
"-----BEGIN CERTIFICATE-----\n" \
"MIIFBjCCAu6gAwIBAgIRAIp9PhPWLzDvI4a9KQdrNPgwDQYJKoZIhvcNAQELBQAw\n" \
"TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh\n" \
"cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMjQwMzEzMDAwMDAw\n" \
"WhcNMjcwMzEyMjM1OTU5WjAzMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNTGV0J3Mg\n" \
"RW5jcnlwdDEMMAoGA1UEAxMDUjExMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB\n" \
"CgKCAQEAuoe8XBsAOcvKCs3UZxD5ATylTqVhyybKUvsVAbe5KPUoHu0nsyQYOWcJ\n" \
"DAjs4DqwO3cOvfPlOVRBDE6uQdaZdN5R2+97/1i9qLcT9t4x1fJyyXJqC4N0lZxG\n" \
"AGQUmfOx2SLZzaiSqhwmej/+71gFewiVgdtxD4774zEJuwm+UE1fj5F2PVqdnoPy\n" \
"6cRms+EGZkNIGIBloDcYmpuEMpexsr3E+BUAnSeI++JjF5ZsmydnS8TbKF5pwnnw\n" \
"SVzgJFDhxLyhBax7QG0AtMJBP6dYuC/FXJuluwme8f7rsIU5/agK70XEeOtlKsLP\n" \
"Xzze41xNG/cLJyuqC0J3U095ah2H2QIDAQABo4H4MIH1MA4GA1UdDwEB/wQEAwIB\n" \
"hjAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwEwEgYDVR0TAQH/BAgwBgEB\n" \
"/wIBADAdBgNVHQ4EFgQUxc9GpOr0w8B6bJXELbBeki8m47kwHwYDVR0jBBgwFoAU\n" \
"ebRZ5nu25eQBc4AIiMgaWPbpm24wMgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAC\n" \
"hhZodHRwOi8veDEuaS5sZW5jci5vcmcvMBMGA1UdIAQMMAowCAYGZ4EMAQIBMCcG\n" \
"A1UdHwQgMB4wHKAaoBiGFmh0dHA6Ly94MS5jLmxlbmNyLm9yZy8wDQYJKoZIhvcN\n" \
"AQELBQADggIBAE7iiV0KAxyQOND1H/lxXPjDj7I3iHpvsCUf7b632IYGjukJhM1y\n" \
"v4Hz/MrPU0jtvfZpQtSlET41yBOykh0FX+ou1Nj4ScOt9ZmWnO8m2OG0JAtIIE38\n" \
"01S0qcYhyOE2G/93ZCkXufBL713qzXnQv5C/viOykNpKqUgxdKlEC+Hi9i2DcaR1\n" \
"e9KUwQUZRhy5j/PEdEglKg3l9dtD4tuTm7kZtB8v32oOjzHTYw+7KdzdZiw/sBtn\n" \
"UfhBPORNuay4pJxmY/WrhSMdzFO2q3Gu3MUBcdo27goYKjL9CTF8j/Zz55yctUoV\n" \
"aneCWs/ajUX+HypkBTA+c8LGDLnWO2NKq0YD/pnARkAnYGPfUDoHR9gVSp/qRx+Z\n" \
"WghiDLZsMwhN1zjtSC0uBWiugF3vTNzYIEFfaPG7Ws3jDrAMMYebQ95JQ+HIBD/R\n" \
"PBuHRTBpqKlyDnkSHDHYPiNX3adPoPAcgdF3H2/W0rmoswMWgTlLn1Wu0mrks7/q\n" \
"pdWfS6PJ1jty80r2VKsM/Dj3YIDfbjXKdaFU5C+8bhfJGqU3taKauuz0wHVGT3eo\n" \
"6FlWkWYtbt4pgdamlwVeZEW+LM7qZEJEsMNPrfC03APKmZsJgpWCDWOKZvkZcvjV\n" \
"uYkQ4omYCTX5ohy+knMjdOmdH9c7SpqEWBDC86fiNex+O0XOMEZSa8DA\n" \
"-----END CERTIFICATE-----\n";

WiFiClientSecure espClient;
X509List cert(root_ca_cert);
PubSubClient client(espClient);

long lastMsg = 0;

#define BORE_MOTOR_PIN    5
#define VALVE_1_PIN       4
#define VALVE_2_PIN       0
#define VALVE_3_PIN       2
#define MAIN_WATER_VALVE_PIN 12
#define WATER_LEVEL_SENSOR_PIN A0
#define BORE_WATER_SENSOR_PIN 14

bool boreMotorState = LOW;
bool mainWaterState = LOW;
bool valve1State = LOW;
bool valve2State = LOW;
bool valve3State = LOW;
bool boreWaterAvailable = false;

void publishStatus();
void setupHTTPServer();
void handleCORS();
void handleGetStatus();
void handlePostControl();
bool executeHTTPCommand(String type, String state, int valveId = -1);

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void publishStatus() {
  StaticJsonDocument<300> doc;
  doc["bore_motor_on"] = boreMotorState;
  doc["main_water_on"] = mainWaterState;
  doc["bore_water_available"] = boreWaterAvailable;
  JsonArray valve_states = doc.createNestedArray("valve_states");
  valve_states.add(valve1State);
  valve_states.add(valve2State);
  valve_states.add(valve3State);
  char jsonBuffer[256];
  serializeJson(doc, jsonBuffer);
  Serial.print("Publishing status: ");
  Serial.println(jsonBuffer);
  client.publish(mqtt_status_topic, jsonBuffer, true);
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  char message[length + 1];
  memcpy(message, payload, length);
  message[length] = '\0';
  Serial.println(message);

  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, message);

  if (error) {
    Serial.print(F("deserializeJson() failed: "));
    Serial.println(error.f_str());
    return;
  }

  const char* type = doc["type"];
  if (!type) {
    Serial.println("Command missing 'type'");
    return;
  }

  if (strcmp(type, "bore") == 0) {
    const char* state = doc["state"];
    if (state) {
      if (strcmp(state, "on") == 0) {
        digitalWrite(BORE_MOTOR_PIN, HIGH);
        boreMotorState = HIGH;
        Serial.println("Bore Motor turned ON");
      } else if (strcmp(state, "off") == 0) {
        digitalWrite(BORE_MOTOR_PIN, LOW);
        boreMotorState = LOW;
        Serial.println("Bore Motor turned OFF");
      }
    }
  } else if (strcmp(type, "main_water") == 0) {
    const char* state = doc["state"];
    if (state) {
      if (strcmp(state, "on") == 0) {
        digitalWrite(MAIN_WATER_VALVE_PIN, HIGH);
        mainWaterState = HIGH;
        Serial.println("Main Water Valve OPENED");
      } else if (strcmp(state, "off") == 0) {
        digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
        mainWaterState = LOW;
        Serial.println("Main Water Valve CLOSED");
      }
    }
  } else if (strcmp(type, "valve") == 0) {
    int id = doc["id"];
    const char* state = doc["state"];
    int pin = -1;
    bool* valveStatePtr = nullptr;
    if (id == 0) { pin = VALVE_1_PIN; valveStatePtr = &valve1State; }
    else if (id == 1) { pin = VALVE_2_PIN; valveStatePtr = &valve2State; }
    else if (id == 2) { pin = VALVE_3_PIN; valveStatePtr = &valve3State; }
    if (pin != -1 && state && valveStatePtr) {
      if (strcmp(state, "open") == 0) {
        digitalWrite(pin, HIGH);
        *valveStatePtr = HIGH;
        Serial.printf("Valve %d OPENED\n", id + 1);
      } else if (strcmp(state, "closed") == 0) {
        digitalWrite(pin, LOW);
        *valveStatePtr = LOW;
        Serial.printf("Valve %d CLOSED\n", id + 1);
      }
    }
  } else if (strcmp(type, "all_valves") == 0) {
    const char* state = doc["state"];
    if (state) {
      bool newState = (strcmp(state, "open") == 0) ? HIGH : LOW;
      digitalWrite(VALVE_1_PIN, newState);
      digitalWrite(VALVE_2_PIN, newState);
      digitalWrite(VALVE_3_PIN, newState);
      valve1State = newState;
      valve2State = newState;
      valve3State = newState;
      Serial.printf("All valves set to %s\n", state);
    }
  } else if (strcmp(type, "emergency_stop") == 0) {
    digitalWrite(BORE_MOTOR_PIN, LOW);
    boreMotorState = LOW;
    digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
    mainWaterState = LOW;
    digitalWrite(VALVE_1_PIN, LOW);
    digitalWrite(VALVE_2_PIN, LOW);
    digitalWrite(VALVE_3_PIN, LOW);
    valve1State = LOW;
    valve2State = LOW;
    valve3State = LOW;
    Serial.println("EMERGENCY STOP ACTIVATED: All systems off.");
  }
  publishStatus();
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    char clientId[30];
    snprintf(clientId, 30, "ESP8266Client-%ld", micros());
    if (client.connect(clientId, mqtt_username, mqtt_password)) {
      Serial.println("connected");
      publishStatus();
      client.subscribe(mqtt_command_topic);
      Serial.print("Subscribed to: ");
      Serial.println(mqtt_command_topic);
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\nESP8266 SmartSoak System Booting...");

  pinMode(BORE_MOTOR_PIN, OUTPUT);
  pinMode(MAIN_WATER_VALVE_PIN, OUTPUT);
  pinMode(VALVE_1_PIN, OUTPUT);
  pinMode(VALVE_2_PIN, OUTPUT);
  pinMode(VALVE_3_PIN, OUTPUT);
  pinMode(BORE_WATER_SENSOR_PIN, INPUT_PULLUP);

  digitalWrite(BORE_MOTOR_PIN, LOW);
  digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
  digitalWrite(VALVE_1_PIN, LOW);
  digitalWrite(VALVE_2_PIN, LOW);
  digitalWrite(VALVE_3_PIN, LOW);

  setup_wifi();

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  Serial.print("Waiting for NTP time sync: ");
  time_t now = time(nullptr);
  while (now < 8 * 3600 * 2) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\nTime synchronized");

  espClient.setTrustAnchors(&cert);

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  
  setupHTTPServer();
  
  Serial.println("System ready!");
  Serial.print("Local IP address: ");
  Serial.println(WiFi.localIP());
  Serial.println("HTTP API available at: http://" + WiFi.localIP().toString());
  Serial.println("MQTT also available for cloud control");
}

void loop() {
  server.handleClient();
  
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  long now = millis();
  if (now - lastMsg > 10000) {
    lastMsg = now;
    boreWaterAvailable = (digitalRead(BORE_WATER_SENSOR_PIN) == LOW);
    publishStatus();
  }
}

void setupHTTPServer() {
  server.onNotFound([]() {
    if (server.method() == HTTP_OPTIONS) {
      handleCORS();
    } else {
      server.send(404, "text/plain", "Not found");
    }
  });
  
  server.on("/status", HTTP_GET, handleGetStatus);
  server.on("/status", HTTP_OPTIONS, handleCORS);
  
  server.on("/control", HTTP_POST, handlePostControl);
  server.on("/control", HTTP_OPTIONS, handleCORS);
  
  server.begin();
  Serial.println("HTTP server started");
}

void handleCORS() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  server.send(200, "text/plain", "");
}

void handleGetStatus() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  
  StaticJsonDocument<400> doc;
  
  doc["solenoid"] = valve1State;
  doc["pump"] = boreMotorState;
  doc["moisture"] = 50.0;
  
  doc["bore_motor_on"] = boreMotorState;
  doc["main_water_on"] = mainWaterState;
  doc["bore_water_available"] = boreWaterAvailable;
  
  JsonArray valve_states = doc.createNestedArray("valve_states");
  valve_states.add(valve1State);
  valve_states.add(valve2State);
  valve_states.add(valve3State);
  
  String response;
  serializeJson(doc, response);
  
  server.send(200, "application/json", response);
  
  Serial.println("HTTP Status requested: " + response);
}

void handlePostControl() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\": \"No JSON body found\"}");
    return;
  }
  
  String body = server.arg("plain");
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, body);
  
  if (error) {
    server.send(400, "application/json", "{\"error\": \"Invalid JSON\"}");
    Serial.println("Invalid JSON received: " + body);
    return;
  }
  
  bool success = false;
  
  if (doc.containsKey("command")) {
    String command = doc["command"];
    command.toLowerCase();
    success = executeHTTPCommand("simple", command, -1);
  }
  else if (doc.containsKey("type")) {
    String type = doc["type"];
    String state = doc["state"];
    int valveId = doc["id"] | -1;
    success = executeHTTPCommand(type, state, valveId);
  }
  
  if (success) {
    server.send(200, "application/json", "{\"status\": \"success\"}");
    publishStatus();
    Serial.println("HTTP Command executed: " + body);
  } else {
    server.send(400, "application/json", "{\"error\": \"Unknown command\"}");
    Serial.println("Unknown HTTP command: " + body);
  }
}

bool executeHTTPCommand(String type, String state, int valveId) {
  if (type == "simple") {
    if (state == "open") {
      digitalWrite(VALVE_1_PIN, HIGH);
      valve1State = HIGH;
      Serial.println("Valve 1 opened via HTTP");
      return true;
    }
    else if (state == "close") {
      digitalWrite(VALVE_1_PIN, LOW);
      valve1State = LOW;
      Serial.println("Valve 1 closed via HTTP");
      return true;
    }
    else if (state == "pump_on") {
      digitalWrite(BORE_MOTOR_PIN, HIGH);
      boreMotorState = HIGH;
      Serial.println("Bore Motor started via HTTP");
      return true;
    }
    else if (state == "pump_off") {
      digitalWrite(BORE_MOTOR_PIN, LOW);
      boreMotorState = LOW;
      Serial.println("Bore Motor stopped via HTTP");
      return true;
    }
    else if (state == "main_water_on") {
      digitalWrite(MAIN_WATER_VALVE_PIN, HIGH);
      mainWaterState = HIGH;
      Serial.println("Main water valve opened via HTTP");
      return true;
    }
    else if (state == "main_water_off") {
      digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
      mainWaterState = LOW;
      Serial.println("Main water valve closed via HTTP");
      return true;
    }
    else if (state == "all_lanes_on" || state == "all_valves_on") {
      digitalWrite(VALVE_1_PIN, HIGH);
      digitalWrite(VALVE_2_PIN, HIGH);
      digitalWrite(VALVE_3_PIN, HIGH);
      valve1State = HIGH;
      valve2State = HIGH;
      valve3State = HIGH;
      Serial.println("All valves opened via HTTP");
      return true;
    }
    else if (state == "all_lanes_off" || state == "all_valves_off") {
      digitalWrite(VALVE_1_PIN, LOW);
      digitalWrite(VALVE_2_PIN, LOW);
      digitalWrite(VALVE_3_PIN, LOW);
      valve1State = LOW;
      valve2State = LOW;
      valve3State = LOW;
      Serial.println("All valves closed via HTTP");
      return true;
    }
    else if (state == "emergency_stop") {
      digitalWrite(BORE_MOTOR_PIN, LOW);
      boreMotorState = LOW;
      digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
      mainWaterState = LOW;
      digitalWrite(VALVE_1_PIN, LOW);
      digitalWrite(VALVE_2_PIN, LOW);
      digitalWrite(VALVE_3_PIN, LOW);
      valve1State = LOW;
      valve2State = LOW;
      valve3State = LOW;
      Serial.println("Emergency stop via HTTP");
      return true;
    }
  }
  else if (type == "bore") {
    if (state == "on") {
      digitalWrite(BORE_MOTOR_PIN, HIGH);
      boreMotorState = HIGH;
      Serial.println("Bore Motor started via HTTP");
      return true;
    } else if (state == "off") {
      digitalWrite(BORE_MOTOR_PIN, LOW);
      boreMotorState = LOW;
      Serial.println("Bore Motor stopped via HTTP");
      return true;
    }
  }
  else if (type == "main_water") {
    if (state == "on") {
      digitalWrite(MAIN_WATER_VALVE_PIN, HIGH);
      mainWaterState = HIGH;
      Serial.println("Main Water Valve opened via HTTP");
      return true;
    } else if (state == "off") {
      digitalWrite(MAIN_WATER_VALVE_PIN, LOW);
      mainWaterState = LOW;
      Serial.println("Main Water Valve closed via HTTP");
      return true;
    }
  }
  else if (type == "valve" && valveId >= 0 && valveId <= 2) {
    int pin = -1;
    bool* valveStatePtr = nullptr;

    if (valveId == 0) { pin = VALVE_1_PIN; valveStatePtr = &valve1State; }
    else if (valveId == 1) { pin = VALVE_2_PIN; valveStatePtr = &valve2State; }
    else if (valveId == 2) { pin = VALVE_3_PIN; valveStatePtr = &valve3State; }

    if (pin != -1 && valveStatePtr) {
      if (state == "open") {
        digitalWrite(pin, HIGH);
        *valveStatePtr = HIGH;
        Serial.printf("Valve %d opened via HTTP\n", valveId + 1);
        return true;
      } else if (state == "closed") {
        digitalWrite(pin, LOW);
        *valveStatePtr = LOW;
        Serial.printf("Valve %d closed via HTTP\n", valveId + 1);
        return true;
      }
    }
  }
  
  return false;
}
