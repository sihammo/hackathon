# SolveX Alert

Road-accident emergency app for **SolveX 3.0** — Flutter + Firebase + ESP32 (BLE).

The ESP32 box (MPU6050 + GPS) detects an accident and notifies the phone over Bluetooth Low Energy.
The app shows a full-screen alarm with a 15-second countdown. If the user does not press
**"JE VAIS BIEN – ANNULER / أنا بخير – إلغاء"**, it sends an SMS with the Google Maps location to the police
and civil protection of the wilaya where the accident happened and to the user's emergency contacts,
then places a phone call. Every alert is saved in Firestore and shown on the admin dashboard.

> **Test mode is ON by default.** Police / civil-protection numbers are replaced by a test number,
> and the admin can force test mode for every account. No real emergency service is contacted
> during development or demos.

---

## Project layout

```
lib/
  main.dart                 App entry, providers, AuthGate (login → user home / admin panel)
  core/                     constants (BLE UUIDs, statuses), 58 wilayas, strings AR/FR, theme
  models/models.dart        Firestore models
  services/
    auth.dart               Username/password auth (Firebase Auth) + session/role routing
    db.dart                 All Firestore reads/writes
    ble_service.dart        ESP32 BLE: scan, pair, auto-reconnect, alerts, config
    emergency_service.dart  SMS / call / test mode / alert recording
    location_service.dart   Phone GPS + wilaya detection
  screens/
    auth/                   Login, Create account
    user/                   Home, device pairing, alarm, contacts, history, settings
    admin/                  Dashboard, alerts (filters), map, users, wilaya numbers
    common/                 Hotspot map, alert details
android/…/MainActivity.kt   Native SMS (SmsManager) + direct call (ACTION_CALL)
firebase/firestore.rules    Security rules (roles, per-user data)
firmware/solvex_device/     ESP32 Arduino sketch
docs/BLE_PROTOCOL.md        BLE UUIDs and message format
setup.sh                    One-time setup script
```

---

## 1. Install the tools

1. **Flutter** (stable): https://docs.flutter.dev/get-started/install — then run `flutter doctor`.
2. **Android Studio** (Android SDK + an Android phone with USB debugging). SMS and direct calls only work on Android.
3. **Firebase CLI**: `npm install -g firebase-tools` then `firebase login`.
4. **FlutterFire CLI**: `dart pub global activate flutterfire_cli`.

## 2. Set up the project

```bash
cd solvex_alert
bash setup.sh
```

This generates the Android/iOS platform files (your files are kept), sets `minSdk 23`, adds iOS permission texts and downloads the packages.

## 3. Firebase setup

1. Create a project at https://console.firebase.google.com
2. **Authentication → Sign-in method → Email/Password → Enable.**
   (Usernames are mapped to `<username>@users.solvexalert.app`; users never see an email. Passwords are hashed by Firebase, never stored by the app.)
3. **Firestore Database → Create database** (production mode, region `europe-west`).
4. In the project folder:
   ```bash
   flutterfire configure --platforms=android,ios
   ```
   This replaces `lib/firebase_options.dart` and adds `google-services.json`.
5. Deploy the security rules:
   ```bash
   firebase init firestore   # choose your project, rules file: firebase/firestore.rules
   firebase deploy --only firestore:rules
   ```
   (or paste `firebase/firestore.rules` into Console → Firestore → Rules → Publish).

## 4. Create the admin account

1. Run the app and tap **Créer mon compte**, e.g. username `admin`.
2. Firebase Console → Firestore → `users` → open that user's document → change `role` from `user` to `admin`.
3. Log in again with the same screen: you land on the **Admin panel**.
4. In the admin panel:
   - **Numéros** tab → **Créer les numéros par défaut (17 / 14)**, then edit each wilaya with its direct lines.
   - ⚙️ Settings → set the **default test number** (e.g. a team member's phone). Keep **Imposer le mode test** ON for the demo.

## 5. Run

```bash
flutter run
```

Grant Bluetooth, location, SMS and phone permissions when asked (Home → **Autoriser**).

## 6. Flash the ESP32

1. Arduino IDE → Boards Manager → install **esp32 by Espressif**.
2. Library Manager → install **TinyGPSPlus**.
3. Wiring:

| Module | ESP32 |
|---|---|
| MPU6050 VCC / GND | 3V3 / GND |
| MPU6050 SDA / SCL | GPIO 21 / GPIO 22 |
| GPS VCC / GND | 3V3 (or 5V per module) / GND |
| GPS TX → | GPIO 16 (RX2) |
| GPS RX ← | GPIO 17 (TX2) |

4. Open `firmware/solvex_device/solvex_device.ino`, select *ESP32 Dev Module*, upload.
5. Serial Monitor (115200) shows `[BLE] advertising as SolveX-XXXX`.
6. In the app: Home → **Associer le boîtier** → Connecter. The vehicle type is sent automatically.

Long-press the ESP32 **BOOT** button for 3 s to fire a test alert from the hardware.

## 7. Demo checklist

- Test mode ON (default), test number set.
- Add at least one emergency contact (a teammate).
- Home → **Simuler un accident** (no hardware needed) or **Alerte test depuis le boîtier**.
- Let the countdown finish → SMS to test number + contact, call to test number.
- Admin → Alertes → open the alert → move Police / Protection civile through
  *Reçue → Équipe envoyée → Arrivée → Résolue*; the dashboard shows response times per wilaya and service.

---

## Firestore data model

| Collection | Fields |
|---|---|
| `users/{uid}` | fullName, username, phone, wilayaCode, role (`user`/`admin`), disabled, vehicleType, testMode, testPhoneNumber, createdAt |
| `devices/{deviceId}` | userId, name, vehicleType, connected, lastSeen, registeredAt |
| `alerts/{id}` | userId, userName, userPhone, deviceId, createdAt, lat, lng, wilayaCode, wilayaName, vehicleType, status, statusTimestamps, responses.{police,civil}.{status,statusTimestamps}, testMode, trigger, peakG, tilt, notifiedNumbers |
| `emergencyContacts/{id}` | userId, name, phone, relation |
| `wilayaNumbers/{code}` | code, nameFr, nameAr, police, civilProtection, updatedAt |
| `hotspots/{alertId}` | lat, lng, vehicleType, wilayaCode, createdAt — anonymous copy for the public map |
| `config/app` | forceTestMode, defaultTestNumber |

Alert status: `cancelled` (user pressed "I'm OK") or `sent → received → dispatched → arrived → resolved`.
Each service (police, civil protection) has its own status; the alert's overall status is the most advanced one.
Response time = `arrived` − `createdAt`.

## Known limitations (good to mention to the jury)

- **Background:** BLE alerts are received while the app is open or recently in the background. A production version needs an Android foreground service so the phone keeps listening with the screen off.
- **SMS to 17 / 14:** short emergency numbers accept calls, not SMS. Each wilaya needs a direct line that receives SMS (or an SMS gateway / API from the authorities).
- **Google Play:** apps that send SMS/call directly need a Play Store exemption. For the hackathon, install the APK directly (`flutter build apk`).
- **iOS:** iOS does not allow silent SMS or direct calls; the app opens the SMS composer / dialer instead.
- **Account disabling** blocks the app (rules + login check). Fully disabling the Firebase Auth account needs the Admin SDK (Cloud Function).
- **Thresholds** in the firmware are starting values; they need real road testing.
