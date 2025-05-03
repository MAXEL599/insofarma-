#include <WiFiS3.h>
#include <ArduinoHttpClient.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <TimeLib.h>
#include <DHT.h>
#include <ArduinoJson.h>

// Pines sensores DHT11
const int dhtPins[4] = {3, 4, 5, 6};
DHT dhts[4] = {
  DHT(3, DHT11), DHT(4, DHT11), DHT(5, DHT11), DHT(6, DHT11)
};

// Pines sensores YL-69
const int yl69Pins[4] = {A0, A1, A2, A3};

// Relés
const int releGeneral = 7;
const int relePins[4] = {9, 10, 11, 12};
bool estadoAnteriorGeneral = HIGH;
bool estadoAnterior[4] = {HIGH, HIGH, HIGH, HIGH};

int umbrales[4] = {60, 60, 60, 60}; // Por defecto

WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", -7 * 3600, 60000);
WiFiClient wifi;
HttpClient client = HttpClient(wifi, "invfnl-default-rtdb.firebaseio.com", 443);

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < 4; i++) {
    dhts[i].begin();
    pinMode(relePins[i], OUTPUT);
    digitalWrite(relePins[i], LOW);
  }
  pinMode(releGeneral, OUTPUT);
  digitalWrite(releGeneral, LOW);

  WiFi.begin("SSID", "PASS"); // Temporal
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConectado a WiFi");
  timeClient.begin();
  timeClient.update();

  obtenerConfiguracionDesdeFirebase();
}

void loop() {
  timeClient.update();
  setTime(timeClient.getEpochTime());
  controlarRiego();
  delay(100);
}

void obtenerConfiguracionDesdeFirebase() {
  client.beginRequest();
  client.get("/configuraciones.json");
  client.sendHeader("Host", "invfnl-default-rtdb.firebaseio.com");
  client.endRequest();

  int statusCode = client.responseStatusCode();
  String response = client.responseBody();
  if (statusCode != 200) {
    Serial.println("Error al obtener configuración: " + String(statusCode));
    return;
  }

  DynamicJsonDocument doc(2048);
  deserializeJson(doc, response);

  JsonObject ultima = doc[doc.size() - 1];
  if (!ultima.isNull()) {
    for (int i = 0; i < 4; i++) {
      umbrales[i] = ultima["humedadesMacetas"][String(i)];
    }
    Serial.println("Configuración cargada de Firebase");
  }
}

void controlarRiego() {
  bool algunaSeca = false;

  for (int i = 0; i < 4; i++) {
    int humedadAnalog = analogRead(yl69Pins[i]);
    int humedadPct = map(humedadAnalog, 1023, 0, 0, 100);
    bool estadoActual = digitalRead(relePins[i]);

    if (humedadPct < umbrales[i]) {
      algunaSeca = true;
      if (estadoActual == LOW) digitalWrite(relePins[i], HIGH);
    } else {
      if (estadoActual == HIGH) digitalWrite(relePins[i], LOW);
    }
  }

  bool estadoActualGeneral = digitalRead(releGeneral);
  if (algunaSeca && estadoActualGeneral == LOW) {
    digitalWrite(releGeneral, HIGH);
  } else if (!algunaSeca && estadoActualGeneral == HIGH) {
    digitalWrite(releGeneral, LOW);
  }
}
