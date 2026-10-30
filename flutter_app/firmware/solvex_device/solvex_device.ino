/*
 * SolveX Alert — ESP32 device firmware
 * -------------------------------------------------------------
 * Hardware:
 *   - ESP32 DevKit (any ESP32 with BLE)
 *   - MPU6050 (I2C: SDA=21, SCL=22, 3.3V)
 *   - GPS NEO-6M / NEO-M8N (UART2: GPS TX -> ESP32 RX 16, GPS RX -> ESP32 TX 17, 9600 baud)
 *   - Optional: on-board LED (GPIO 2), BOOT button (GPIO 0) = long press 3 s sends a test alert
 *
 * Libraries (Arduino Library Manager):
 *   - TinyGPSPlus (by Mikal Hart)
 *   - BLE library bundled with the "esp32" board package (Espressif), core 2.x or 3.x
 *
 * Detection:
 *   CAR        : impact > 4.0 g for >= 30 ms, or rollover (tilt > 100° for 2 s)
 *   MOTORCYCLE : impact > 2.5 g for >= 30 ms, or fall     (tilt >  60° for 2 s)
 *   Tilt = angle between the current gravity vector and the "upright" reference
 *   captured at boot (or with the {"cmd":"cal"} command, vehicle parked normally).
 *
 * BLE protocol: see docs/BLE_PROTOCOL.md (UUIDs must match lib/core/constants.dart).
 */

#include <Arduino.h>
#include <Wire.h>
#include <Preferences.h>
#include <TinyGPSPlus.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <math.h>

// ------------------------------------------------------------------ pins
#define I2C_SDA 21
#define I2C_SCL 22
#define GPS_RX 16
#define GPS_TX 17
#define GPS_BAUD 9600
#define LED_PIN 2
#define BUTTON_PIN 0

// ------------------------------------------------------------------ BLE UUIDs
#define SERVICE_UUID "5a0e0001-7b2c-4e3d-9f10-a1e2c3d4e5f6"
#define ALERT_UUID   "5a0e0002-7b2c-4e3d-9f10-a1e2c3d4e5f6"
#define STATUS_UUID  "5a0e0003-7b2c-4e3d-9f10-a1e2c3d4e5f6"
#define CONFIG_UUID  "5a0e0004-7b2c-4e3d-9f10-a1e2c3d4e5f6"

// ------------------------------------------------------------------ thresholds
const float CAR_IMPACT_G = 4.0;
const float MOTO_IMPACT_G = 2.5;
const int IMPACT_MIN_SAMPLES = 3;        // 3 samples @100 Hz = 30 ms
const float CAR_ROLLOVER_DEG = 100.0;
const float MOTO_FALL_DEG = 60.0;
const unsigned long TILT_HOLD_MS = 2000;
const float TILT_RESET_DEG = 30.0;       // must come back below this to re-arm tilt
const unsigned long COOLDOWN_MS = 30000; // no new alert for 30 s after one
const unsigned long RESEND_MS = 2000;    // re-send alert until the app acks it
const int MAX_RESENDS = 15;
const unsigned long STATUS_MS = 3000;

// ------------------------------------------------------------------ MPU6050
const uint8_t MPU_ADDR = 0x68;
const float ACC_LSB_PER_G = 2048.0;      // ±16 g range

// ------------------------------------------------------------------ state
enum Vehicle { CAR, MOTO };
Vehicle vehicle = CAR;

Preferences prefs;
TinyGPSPlus gps;
HardwareSerial GPSSerial(2);

BLEServer *server = nullptr;
BLECharacteristic *alertChar = nullptr;
BLECharacteristic *statusChar = nullptr;
BLECharacteristic *configChar = nullptr;
volatile bool bleConnected = false;

float gx = 0, gy = 0, gz = 1;            // low-pass gravity
float refX = 0, refY = 0, refZ = 1;      // upright reference (unit vector)
int impactCount = 0;
float impactPeak = 0;
unsigned long tiltSince = 0;
bool tiltArmed = true;
unsigned long lastAlertAt = 0;
bool hasAlerted = false;

// Pending alert waiting for the app's ack
bool pending = false;
uint32_t pendingId = 0;
int pendingSends = 0;
unsigned long lastSendAt = 0;
char pendingJson[200];
uint32_t nextAlertId = 0;

volatile bool calibrateRequested = false;
volatile bool testRequested = false;

unsigned long lastStatusAt = 0;
unsigned long lastSampleAt = 0;
unsigned long buttonDownAt = 0;

// ================================================================== MPU6050
void mpuWrite(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

bool mpuInit() {
  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000);
  mpuWrite(0x6B, 0x00);  // wake up
  delay(50);
  mpuWrite(0x1A, 0x03);  // DLPF ~44 Hz
  mpuWrite(0x1C, 0x18);  // accel ±16 g
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x75);      // WHO_AM_I
  Wire.endTransmission(false);
  Wire.requestFrom((int)MPU_ADDR, 1);
  return Wire.available() && (Wire.read() & 0x7E) == 0x68;
}

bool mpuReadAccel(float &ax, float &ay, float &az) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)MPU_ADDR, 6) != 6) return false;
  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();
  ax = x / ACC_LSB_PER_G;
  ay = y / ACC_LSB_PER_G;
  az = z / ACC_LSB_PER_G;
  return true;
}

void calibrate() {
  float sx = 0, sy = 0, sz = 0;
  int n = 0;
  for (int i = 0; i < 100; i++) {
    float ax, ay, az;
    if (mpuReadAccel(ax, ay, az)) {
      sx += ax; sy += ay; sz += az; n++;
    }
    delay(10);
  }
  if (n == 0) return;
  float norm = sqrtf(sx * sx + sy * sy + sz * sz);
  if (norm < 0.01) return;
  refX = sx / norm; refY = sy / norm; refZ = sz / norm;
  gx = refX; gy = refY; gz = refZ;
  tiltSince = 0;
  tiltArmed = true;
  Serial.printf("[cal] reference = (%.2f, %.2f, %.2f)\n", refX, refY, refZ);
}

float tiltDegrees() {
  float norm = sqrtf(gx * gx + gy * gy + gz * gz);
  if (norm < 0.01) return 0;
  float dot = (gx * refX + gy * refY + gz * refZ) / norm;
  if (dot > 1) dot = 1;
  if (dot < -1) dot = -1;
  return acosf(dot) * 180.0 / PI;
}

// ================================================================== alerts
void notifyJson(BLECharacteristic *c, const char *json) {
  if (!c) return;
  c->setValue((uint8_t *)json, strlen(json));
  if (bleConnected) c->notify();
}

void raiseAlert(const char *type, float g, float tilt) {
  unsigned long now = millis();
  if (hasAlerted && now - lastAlertAt < COOLDOWN_MS) return;
  hasAlerted = true;
  lastAlertAt = now;

  pendingId = nextAlertId++;
  bool fix = gps.location.isValid() && gps.location.age() < 10000;
  snprintf(pendingJson, sizeof(pendingJson),
           "{\"t\":\"acc\",\"id\":%lu,\"type\":\"%s\",\"g\":%.1f,\"tilt\":%.0f,\"fix\":%d,\"lat\":%.6f,\"lng\":%.6f,\"veh\":\"%s\"}",
           (unsigned long)pendingId, type, g, tilt, fix ? 1 : 0,
           fix ? gps.location.lat() : 0.0, fix ? gps.location.lng() : 0.0,
           vehicle == CAR ? "car" : "moto");
  pending = true;
  pendingSends = 0;
  lastSendAt = 0;  // send immediately
  Serial.printf("[ALERT] %s\n", pendingJson);
}

void serviceAlerts() {
  if (!pending) return;
  unsigned long now = millis();
  if (lastSendAt != 0 && now - lastSendAt < RESEND_MS) return;
  if (!bleConnected) return;  // keep it pending until the phone reconnects
  notifyJson(alertChar, pendingJson);
  lastSendAt = now;
  pendingSends++;
  if (pendingSends >= MAX_RESENDS) {
    Serial.println("[ALERT] no ack, giving up");
    pending = false;
  }
}

void sendStatus() {
  char buf[160];
  bool fix = gps.location.isValid() && gps.location.age() < 10000;
  snprintf(buf, sizeof(buf),
           "{\"t\":\"st\",\"veh\":\"%s\",\"fix\":%d,\"lat\":%.6f,\"lng\":%.6f,\"sat\":%d,\"up\":%lu}",
           vehicle == CAR ? "car" : "moto", fix ? 1 : 0,
           fix ? gps.location.lat() : 0.0, fix ? gps.location.lng() : 0.0,
           gps.satellites.isValid() ? (int)gps.satellites.value() : 0,
           (unsigned long)(millis() / 1000));
  notifyJson(statusChar, buf);
}

// ================================================================== BLE
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *s) override {
    bleConnected = true;
    Serial.println("[BLE] connected");
  }
  void onDisconnect(BLEServer *s) override {
    bleConnected = false;
    Serial.println("[BLE] disconnected, advertising again");
    BLEDevice::startAdvertising();
  }
};

// Very small JSON helpers (messages are tiny and fixed-format).
bool jsonHas(const String &s, const char *key, const char *value) {
  String k = String("\"") + key + "\":\"" + value + "\"";
  String k2 = String("\"") + key + "\": \"" + value + "\"";
  return s.indexOf(k) >= 0 || s.indexOf(k2) >= 0;
}

long jsonInt(const String &s, const char *key) {
  String k = String("\"") + key + "\":";
  int i = s.indexOf(k);
  if (i < 0) return -1;
  i += k.length();
  while (i < (int)s.length() && s[i] == ' ') i++;
  return s.substring(i).toInt();
}

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    String v = String(c->getValue().c_str());
    Serial.printf("[CFG] %s\n", v.c_str());
    if (jsonHas(v, "veh", "car")) {
      vehicle = CAR;
      prefs.putUChar("veh", 0);
    } else if (jsonHas(v, "veh", "moto")) {
      vehicle = MOTO;
      prefs.putUChar("veh", 1);
    } else if (jsonHas(v, "cmd", "ack")) {
      long id = jsonInt(v, "id");
      if (pending && id == (long)pendingId) {
        pending = false;
        Serial.println("[ALERT] acked by app");
      }
    } else if (jsonHas(v, "cmd", "test")) {
      testRequested = true;
    } else if (jsonHas(v, "cmd", "cal")) {
      calibrateRequested = true;
    }
    lastStatusAt = 0;  // push a fresh status
  }
};

void bleInit() {
  uint64_t mac = ESP.getEfuseMac();
  char name[20];
  snprintf(name, sizeof(name), "SolveX-%04X", (uint16_t)(mac >> 32));
  BLEDevice::init(name);
  BLEDevice::setMTU(185);  // JSON messages are ~150 bytes; the app also requests MTU 185
  server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *svc = server->createService(SERVICE_UUID);

  alertChar = svc->createCharacteristic(
      ALERT_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  alertChar->addDescriptor(new BLE2902());

  statusChar = svc->createCharacteristic(
      STATUS_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  statusChar->addDescriptor(new BLE2902());

  configChar = svc->createCharacteristic(
      CONFIG_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  configChar->setCallbacks(new ConfigCallbacks());

  svc->start();
  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.printf("[BLE] advertising as %s\n", name);
}

// ================================================================== setup / loop
void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  prefs.begin("solvex", false);
  vehicle = prefs.getUChar("veh", 0) == 1 ? MOTO : CAR;
  nextAlertId = (esp_random() % 100000) + 1;  // random start so ids differ after reboot

  GPSSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);

  if (!mpuInit()) Serial.println("[MPU] not found! check wiring");
  delay(500);
  calibrate();

  bleInit();
  Serial.printf("[SolveX] ready, vehicle=%s\n", vehicle == CAR ? "car" : "moto");
}

void loop() {
  unsigned long now = millis();

  // --- GPS
  while (GPSSerial.available()) gps.encode(GPSSerial.read());

  // --- commands from BLE callbacks
  if (calibrateRequested) {
    calibrateRequested = false;
    calibrate();
  }
  if (testRequested) {
    testRequested = false;
    hasAlerted = false;  // bypass cooldown for tests
    raiseAlert("test", 0, tiltDegrees());
  }

  // --- BOOT button long press (3 s) = test alert
  if (digitalRead(BUTTON_PIN) == LOW) {
    if (buttonDownAt == 0) buttonDownAt = now;
    if (buttonDownAt != 1 && now - buttonDownAt > 3000) {
      hasAlerted = false;
      raiseAlert("test", 0, tiltDegrees());
      buttonDownAt = 1;  // wait for release
    }
  } else {
    buttonDownAt = 0;
  }

  // --- 100 Hz accelerometer sampling
  if (now - lastSampleAt >= 10) {
    lastSampleAt = now;
    float ax, ay, az;
    if (mpuReadAccel(ax, ay, az)) {
      float mag = sqrtf(ax * ax + ay * ay + az * az);

      // Impact
      float th = vehicle == CAR ? CAR_IMPACT_G : MOTO_IMPACT_G;
      if (mag > th) {
        impactCount++;
        if (mag > impactPeak) impactPeak = mag;
        if (impactCount >= IMPACT_MIN_SAMPLES) {
          raiseAlert("impact", impactPeak, tiltDegrees());
          impactCount = 0;
          impactPeak = 0;
        }
      } else {
        impactCount = 0;
        impactPeak = 0;
      }

      // Tilt (low-pass gravity, ignore high-g samples)
      if (mag > 0.5 && mag < 1.5) {
        const float a = 0.05;
        gx += a * (ax - gx);
        gy += a * (ay - gy);
        gz += a * (az - gz);
      }
      float tilt = tiltDegrees();
      float tiltTh = vehicle == CAR ? CAR_ROLLOVER_DEG : MOTO_FALL_DEG;
      if (tilt > tiltTh && tiltArmed) {
        if (tiltSince == 0) tiltSince = now;
        if (now - tiltSince > TILT_HOLD_MS) {
          raiseAlert(vehicle == CAR ? "rollover" : "fall", mag, tilt);
          tiltArmed = false;
          tiltSince = 0;
        }
      } else {
        tiltSince = 0;
        if (tilt < TILT_RESET_DEG) tiltArmed = true;
      }
    }
  }

  // --- BLE outgoing
  serviceAlerts();
  if (now - lastStatusAt >= STATUS_MS) {
    lastStatusAt = now;
    sendStatus();
  }

  // --- LED: solid when connected, blink when advertising, fast blink when alert pending
  unsigned long period = pending ? 150 : (bleConnected ? 0 : 800);
  digitalWrite(LED_PIN, period == 0 ? HIGH : ((now / period) % 2));
}
