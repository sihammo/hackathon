# SolveX BLE protocol (v1)

The ESP32 is a BLE **peripheral** advertising as `SolveX-XXXX` with one custom GATT service.
All messages are UTF-8 JSON. The MTU is raised to 185 bytes (both sides), so every message fits in one packet.

| Characteristic | UUID | Properties | Direction |
|---|---|---|---|
| Service | `5a0e0001-7b2c-4e3d-9f10-a1e2c3d4e5f6` | — | — |
| ALERT  | `5a0e0002-7b2c-4e3d-9f10-a1e2c3d4e5f6` | read, notify | device → app |
| STATUS | `5a0e0003-7b2c-4e3d-9f10-a1e2c3d4e5f6` | read, notify | device → app |
| CONFIG | `5a0e0004-7b2c-4e3d-9f10-a1e2c3d4e5f6` | write | app → device |

The same UUIDs are defined in `lib/core/constants.dart` and `firmware/solvex_device/solvex_device.ino`.

## Device → app

**ALERT** — sent when an accident is detected. Re-sent every 2 s (max 15 times) until the app acknowledges it.

```json
{"t":"acc","id":48213,"type":"impact","g":5.3,"tilt":12,"fix":1,"lat":36.753768,"lng":3.058756,"veh":"car"}
```

| Field | Meaning |
|---|---|
| `id` | Alert id (random start at boot, then +1). Used for ack and de-duplication. |
| `type` | `impact`, `fall` (motorcycle on its side), `rollover` (car), `test` |
| `g` | Peak acceleration in g |
| `tilt` | Angle from the calibrated upright position, degrees |
| `fix` | `1` if GPS position is valid (then `lat`/`lng` are used), else `0` (the app uses the phone GPS) |

**STATUS** — every 3 s, and right after any config write.

```json
{"t":"st","veh":"moto","fix":1,"lat":36.75,"lng":3.05,"sat":8,"up":1234}
```

## App → device (CONFIG)

| Message | Effect |
|---|---|
| `{"veh":"car"}` | Car thresholds: impact > 4.0 g, rollover tilt > 100° for 2 s |
| `{"veh":"moto"}` | Motorcycle thresholds: impact > 2.5 g, fall tilt > 60° for 2 s |
| `{"cmd":"ack","id":48213}` | Stops re-sending that alert |
| `{"cmd":"test"}` | Fires a `test` alert (full round trip through the hardware) |
| `{"cmd":"cal"}` | Re-captures the upright reference (vehicle parked normally) |

The vehicle type is stored in the ESP32 flash (Preferences), and the app also sends it on every connection.

## Tuning

Thresholds are constants at the top of the sketch (`CAR_IMPACT_G`, `MOTO_IMPACT_G`, `CAR_ROLLOVER_DEG`, `MOTO_FALL_DEG`, `TILT_HOLD_MS`, `COOLDOWN_MS`).
They are starting values for the demo; real values need road testing. Hard braking is ~1 g and potholes produce short spikes, which is why an impact must last at least 30 ms (3 samples at 100 Hz).
