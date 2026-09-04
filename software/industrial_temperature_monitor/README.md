# Industrial Temperature Monitor

This flutter application is built for observing and configuring an industrial temperature control system. It presents live process and PCB temperatures, reports the controller's actuation state, and lets an authorised operator update temperature setpoints(the defined target,min and max operating point for a particular process e.g drying cereals or operating points for a machine like an industrial motor)  through Firebase Realtime Database.

## Features

- Live dashboard for process temperature, PCB temperature, controller actuation state, and PCB cooling status.
- Visual heating and cooling indicator with state-specific animation.
- Password-gated configuration form for target, minimum, and maximum temperatures.
- Input validation that requires `minimum < target < maximum` before writing configuration to the controller.
- Separate process and PCB history views backed by local Hive storage.
- Dark, operator-focused Material interface with Riverpod-managed state and stream lifecycles.

## How it works

The app subscribes to Firebase Realtime Database and maps the following nodes into the UI:

| Node | Fields | Purpose |
| --- | --- | --- |
| `/telemetry` | `processTemp`, `pcbTemp`, `actuationState`, `pcbCoolingState` | Live readings and controller state published by the ESP32. |
| `/config` | `target`, `min`, `max` | Operator setpoints written by the app after validation. |

The Firebase repository exposes these nodes as Dart streams. Riverpod providers consume the streams and rebuild only the affected screens. Hive is initialised at startup and supplies two local boxes for process and PCB history entries.

## Architecture

The app is built using flutter clean architecture principles.


## Technology

- Flutter and Dart (Dart SDK constraint: `^3.12.2`)
- `flutter_riverpod` for state management
- Firebase Core and Firebase Realtime Database for remote telemetry/configuration
- Hive/Hive Flutter for local history persistence
- Material Design

## Getting started

### Prerequisites

- A Flutter SDK compatible with the Dart constraint in [`pubspec.yaml`](pubspec.yaml)
- A Firebase Realtime Database configured with the schema above
- A controller or simulator that publishes telemetry to the configured database

### Run locally

```bash
flutter pub get
flutter run
```

The included FlutterFire configuration defines Firebase options for Android, iOS, macOS, web, and Windows. 

## Controller integration

An ESP32 or other controller must publish telemetry values that are numeric or numeric strings. Example:

```json
{
  "telemetry": {
    "processTemp": 72.4,
    "pcbTemp": 41.8,
    "actuationState": "COOLING",
    "pcbCoolingState": "FAN ON"
  },
  "config": {
    "target": 70.0,
    "min": 65.0,
    "max": 75.0
  }
}
```

## Security and operational notes

- The configuration gate is a demo convenience only. Its access code is embedded in the client and is **not** real access control.
- Do not rely on the app to protect process setpoints.THis is a demo app ,much better security configurations can be implemented.
- Firebase configuration files identify the project but do not implement database authorisation; verify database rules and authorised application identities separately.
- This application is a monitoring/configuration client, not a safety controller. Hardware failsafes, sensor validation, actuator limits, alarms, and emergency shutdown behaviour are implemented on the ESP32 side i.e in an actual industrial room.


Run the application against a controlled database/device before using it with real equipment. A successful UI connection or simulation does not establish electrical or thermal safety.

## License
The app is simply for development purposes,any contributions can be made.
