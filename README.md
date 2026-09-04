# Tensorspectre Dynamics: Industrial Temperature Controller

A complete, full-stack engineering portfolio project encompassing custom printed circuit board (PCB) design, embedded C++ firmware, and a Clean Architecture Flutter mobile application. 

The system provides closed-loop temperature monitoring and PWM hardware actuation, synchronized globally with sub-second latency via Firebase Realtime Database (RTDB).

## 🏗️ System Architecture

The project is structured as a monolithic repository (monorepo) integrating three distinct engineering domains:

    tensorspectre_controller/
    ├── hardware/     # KiCad EDA (Schematics, PCB layout, Gerbers)
    ├── firmware/     # PlatformIO C++ (ESP32 logic, RTDB sync, Wokwi simulation)
    ├── software/     # Flutter Mobile App (Clean Architecture, Riverpod, Hive)
    └── docs/         # System architecture, renders, and media assets

### High-Level Topology
![System Block Diagram](./docs/system/block_diagram.png)

*Validation: Real-time synchronization between the ESP32 hardware simulation and the Firebase RTDB backend.*
![Wokwi Firebase Integration](./docs/system/wokwi_firebase_integration.png)

---

## ⚡ Hardware (KiCad)
The physical controller is a custom 2-layer PCB designed to handle both high-current 12V industrial loads and sensitive 3.3V digital logic.

**Core Specifications:**
* **Microcontroller:** ESP32 (Wi-Fi enabled)
* **Power Delivery Network (PDN):** 12V main input, regulated to 5V via an onboard LM2596 Buck Converter. High-current traces routed at 0.8mm width.
* **Logic Level Translation:** BOB-12009 bidirectional shifter (5V ↔ 3.3V) for I2C LCD communication.
* **Sensors & Actuators:** DS18B20 (1-Wire) digital temperature sensor, with MOSFET-driven PWM outputs for external fans and heating lamps.
* **Trace Topology:** 0.4mm logic lines prioritizing X-Y grid routing across Top/Bottom copper planes with continuous ground pours for EMI shielding.

<p align="center">
  <img src="./docs/hardware/render_top.png" width="45%" alt="PCB Top Render">
  <img src="./docs/hardware/render_bottom.png" width="45%" alt="PCB Bottom Render">
</p>

---

## 💻 Firmware (PlatformIO & Wokwi)
Written in C++ for the ESP32, the firmware manages real-time hardware interrupts, sensor polling, and network communication. 

**Key Features:**
* **Hardware Debouncing:** 200ms software debouncing for mechanical inputs.
* **Delta-Driven Telemetry:** Pushes raw JSON string payloads to the `/telemetry` RTDB node to minimize bandwidth (Tracking `processTemp`, `pcbTemp`, `actuationState`, and `pcbCoolingState`).
* **Config Listener:** Subscribes to the `/config` RTDB node to dynamically update operational setpoints (Target, Max, Min limits) pushed from the mobile app.

### Hardware Simulation
*A live capture of the logic execution in Wokwi:*

![Hardware Simulation](./docs/firmware/wokwi_demo.mp4)

---

## 📱 Software (Flutter Mobile App)
A professional-grade mobile frontend built for performance and absolute architectural strictness. 

**Technical Stack & Architecture:**
* **Architecture:** Strict Clean Architecture (Data, Domain, Presentation layers) utilizing Domain Use Cases (Interactors) to enforce boundary separation.
* **State Management:** Fully manual Riverpod (`AsyncNotifier` and `StreamProvider`), ensuring memory-safe stream disposal without code generation overhead.
* **Data Layer:** Direct Firebase RTDB streams (zero FCM/push notifications) for real-time telemetry, and Hive local storage mapping raw strings for history logging.
* **UI/UX:** Custom state-based routing (no `IndexedStack`), dynamic implicit animations driven by hardware states, and a strict Vantablack/charcoal design system.

<p align="center">
  <img src="./docs/software/app_dashboard.jpg" width="30%" alt="Telemetry Dashboard">
  <img src="./docs/software/app_config.jpg" width="30%" alt="Configuration Hub">
  <img src="./docs/software/app_history.jpg" width="30%" alt="History Logs">
</p>

---

## 🚀 Getting Started

**To view the Hardware:**
1. Install KiCad 8.0+.
2. Open `hardware/tensorspectre_controller.kicad_pro`.

**To compile the Firmware:**
1. Open the `firmware/` directory in VS Code with the PlatformIO extension installed.
2. Build the environment to pull the required C++ dependencies.

**To run the Mobile App:**
1. Navigate to the `software/` directory.
2. Run `flutter pub get`.
3. Provide your own `google-services.json` (Android) from your Firebase console.
4. Run `flutter run`.

---
*Designed and engineered by IamJaxon | Tensorspectre*
