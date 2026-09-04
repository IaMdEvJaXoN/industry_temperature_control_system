// LIBRARIES & DEPENDENCIES
#include <Arduino.h>             // The core Arduino framework functions(digitalWrite, millis, etc.)
#include <WiFi.h>                // Allows the ESP32 to connect to WIFI(local WiFi or Wokwi guest for simulation)
#include <Wire.h>                // I2C communication library (used to talk to the LCD screen)-enables the hardware communication
#include <OneWire.h>             // The low-level protocol required to talk to Dallas temperature sensors
#include <DallasTemperature.h>   // Translates the raw OneWire data into human-readable degree celsius values
#include <PID_v1.h>              // The PID engine is provided by this library.The calculus library that calculates smooth heating curves
#include <LiquidCrystal_I2C.h>   // Controls the 20x4 character display over I2C
#include <Firebase_ESP_Client.h> // The main Firebase library for cloud communication

// These are helper files included with the Firebase library to handle authentication tokens and JSON data payloads.
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// PIN DEFINITIONS
// We use #define here because it tells the compiler to replace the word
// before compiling. This uses ZERO bytes of runtime RAM.
#define PROCESS_TEMP_PIN 4 // Process temperature pin
#define PCB_FAN_TEMP 13    // Pin connected to the PCB temperature sensor
#define LCD_SDA 21         // I2C Data line
#define LCD_SCL 22         // I2C Clock line

#define LAMP_PWM_PIN 27        // Sends the pulsing 3.3V signal to the Lamp's MOSFET
#define PROCESS_FAN_PWM_PIN 26 // Sends the pulsing 3.3V signal to the Process Fan's MOSFET
#define PCB_FAN_PWM_PIN 25     // Sends the pulsing 3.3V signal to the PCB Fan's MOSFET

#define LAMP_LED 18   // Indicator LED showing if the lamp is on
#define FAN_LED 19    // Indicator LED showing if the fan is on
#define BUZZER_PIN 23 // The alarm buzzer

#define LAMP_BTN 32 // Manual override button for the lamp (Hardware Interrupt)
#define FAN_BTN 33  // Manual override button for the fan (Hardware Interrupt)

// WIFI / FIREBASE CONFIGURATION
#define WIFI_SSID "Wokwi-GUEST" // Network name
#define WIFI_PASSWORD ""        // Network password

#define API_KEY ""                                   // secret cloud password to the FIrebase RTDB
#define DATABASE_URL "" // The web address of your database in Firebase

// FIREBASE OBJECTS
// These background objects manage the complex internet connection.
FirebaseData fbdo;     // Holds the actual data being sent/received
FirebaseAuth auth;     // Manages your login credentials
FirebaseConfig config; // Holds the setup parameters (API key, URL)
bool signupOK = false; // A flag to confirm if we successfully connected to the cloud

// FreeRTOS MUTEX (The Memory Lock)
// Because Core 0 and Core 1 run at the exact same time, they might try to read/write
// the same temperature variable at the exact same microsecond, causing a race condition which
// might lead to unpredictable behaviours or even a crash.
// A Mutex is like a "key" to a room. A core must take the key, update the variable,
// and give the key back.
SemaphoreHandle_t dataMutex;

// SENSOR DATA (Shared Variables)
double currentTempProcess = 0.0;                       // The actual temperature of the measurand e.g machine operating temp
double currentTempPCB = 0.0;                           // The temperature inside your electronics box
char currentActuationState[21] = "STARTUP";            // The current state of the process
char currentPCBEnclosureActuationSate[21] = "STARTUP"; // To track if PCB temp sensor and fan are still working

// LOCAL CONTROL LIMITS
// 'constexpr' --> "Constant Expression".Like #define,it takes up zero RAM,
// but it is safer because it forces the compiler to check the math data type (double)
// These values can be changed from the flutter app via Firebase or via the Firebase console
constexpr double DEFAULT_TARGET_TEMP = 45.0; // What we want the temperature to be
constexpr double DEFAULT_MIN_TEMP = 35.0;    // The lowest safe temperature
constexpr double DEFAULT_MAX_TEMP = 55.0;    // The highest safe temperature

// Absolute failsafes: If Firebase glitches and tells the ESP32 to heat to 5000 degrees,
// these limits force the ESP32 to ignore the cloud and stay safe.
constexpr double ABSOLUTE_MIN_TEMP = 0.0;
constexpr double ABSOLUTE_MAX_TEMP = 100.0;

// The active limits being used by the PID loop. These can be changed by Firebase.
double targetTemp = DEFAULT_TARGET_TEMP;
double maxTemp = DEFAULT_MAX_TEMP;
double minTemp = DEFAULT_MIN_TEMP;

// SYSTEM STATE MACHINE
// An 'enum class' creates a custom list of strict physical states.
// Instead of messy "if/else" true/false flags, the system can only ever be in ONE of these states.
enum class ControlState
{
    STARTUP,
    SENSOR_FAULT,
    OVERHEAT_ALARM,
    UNDERHEAT_ALARM,
    MANUAL_LAMP,
    MANUAL_FAN,
    HEATING,
    DEAD_BAND,
    COOLING,
    NORMAL
};

// Start the system in the STARTUP state
ControlState controlState = ControlState::STARTUP;

// Flags to track if the physical sensors are actually connected and working
bool processSensorOK = false;
bool pcbSensorOK = false;

// FIREBASE TELEMETRY TRACKERS
double lastSentTemp = 0.0;        // The last process temperature we uploaded
bool hasSentTemp = false;         // Tracks if we have uploaded process temp at least once
double lastSentPCBTemp = 0.0;     // Lats uploaded PCB temerature
bool hasSentPCBTemp = false;      // Tracks if PCB temp has been uploaded to Firebase RTDB at least once
char prevActuationState[21] = ""; // Tracks actuation status
bool hasSentActuationState = false;
char prevPCBTempMonitorState[21] = "";

// MANUAL OVERRIDE FLAGS (Hardware Interrupts)
// 'volatile' is critical here. It tells the compiler that a variable is changed by an
// action outside the normal loop. It should not be cached but rather it should be fetched from RAM every time.
volatile bool manualLampOverride = false;
volatile bool manualFanOverride = false;

// Timestamps to prevent "Button Bounce"(metal contacts vibrating)
volatile unsigned long lastLampBtnTime = 0;
volatile unsigned long lastFanBtnTime = 0;

// HARDWARE OBJECTS
OneWire oneWire(PROCESS_TEMP_PIN);         // Sets up the physical wire on GPIO 4
DallasTemperature sensorProcess(&oneWire); // Connects the Dallas library to that physical wire
OneWire oneWirePCB(PCB_FAN_TEMP);          // sets the physical wire on GPIO 13
DallasTemperature sensorPCB(&oneWirePCB);  // Connetcs the dallas library to #define PCB_TEMP_PIN 13that physical wire

LiquidCrystal_I2C lcd(0x27, 20, 4); // Sets up a 20-column, 4-row LCD at I2C address 0x27

// PID CONTROLLER SETUP
double pidInput = 0.0;                    // What the temperature is right now
double pidOutput = 0.0;                   // What the heater power should be (0-255)
double pidSetPoint = DEFAULT_TARGET_TEMP; // What we want the temperature to be

// PID Tuning values
// Kp (Proportional gain) - How hard to push based on current error.
// Ki (Integral gain) - Looks at past errors to fix steady-state drift.
// Kd (Derivative gain) - Looks at future trends to slow down and prevent overshoot.
double Kp = 25.0, Ki = 5.0, Kd = 1.0;

// Create the PID object and link it to the memory addresses (&) of our variables
PID lampPID(&pidInput, &pidOutput, &pidSetPoint, Kp, Ki, Kd, DIRECT);

// CONFIGURATION
constexpr uint32_t PWM_FREQ = 5000;   // Flashes the MOSFET 5,000 times per second
constexpr uint8_t PWM_RESOLUTION = 8; // 8-bit math = 2^8 = 256 steps (0 to 255)
constexpr uint32_t PWM_MAX = 255;     // Maximum power

// ESP32 v3.x API uses independent channels for hardware timers(ESP32 has 16 timers-0 to 15)
// We assign a unique hardware channel to every single output.
constexpr int LAMP_CHANNEL = 0;
constexpr int PROCESS_FAN_CHANNEL = 1;
constexpr int PCB_FAN_CHANNEL = 2;
constexpr int LAMP_LED_CHANNEL = 3;
constexpr int FAN_LED_CHANNEL = 4;

// PCB FAN HYSTERESIS
// Hysteresis prevents rapid on/off switching. The fan turns on at 40C,
// but won't turn off until it cools all the way down to 38C.
constexpr double PCB_FAN_ON_TEMP = 40.0;
constexpr double PCB_FAN_OFF_TEMP = 38.0;
bool pcbFanActive = false; // Tracks if the PCB cooling fan is currently spinning

// HELPER FUNCTION-MAP DOUBLE
// The standard Arduino map() function only works with integers (e.g., 45, 46).
// This custom function allows us to map precise decimals (e.g., 45.2 to a smooth fan speed).
long mapDouble(double x, double in_min, double in_max, long out_min, long out_max)
{
    if (in_max <= in_min)
    {
        return out_min;
    } // Prevent divide-by-zero crash
    // Standard linear interpolation math
    double result = (x - in_min) * (double)(out_max - out_min) / (in_max - in_min) + out_min;
    return (long)result;
}

// Helper function to clamp values in the required range.
// Forces a number to stay within a specific range to prevent math overflow errors.
double clampDouble(double value, double minimum, double maximum)
{
    if (value < minimum)
        return minimum;
    if (value > maximum)
        return maximum;
    return value;
}

// FIREBASE CONFIGURATION VALIDATION
// Checks the numbers downloaded from the internet to make sure they are safe
// before applying them to the hardware.
bool validTemperatureConfiguration(double newMin, double newTarget, double newMax)
{
    // Check if the numbers are physically impossible/dangerous
    if (newMin < ABSOLUTE_MIN_TEMP || newMin > ABSOLUTE_MAX_TEMP)
        return false;
    if (newTarget < ABSOLUTE_MIN_TEMP || newTarget > ABSOLUTE_MAX_TEMP)
        return false;
    if (newMax < ABSOLUTE_MIN_TEMP || newMax > ABSOLUTE_MAX_TEMP)
        return false;

    // Logical check: Min must be lowest, Max must be highest.
    if (!(newMin < newTarget && newTarget < newMax))
    {
        return false;
    }
    return true; // The cloud data is safe to use!
}

// BUTTON INTERRUPTS (Hardware level)
// IRAM_ATTR forces this code into the fast Instruction RAM. It pauses whatever the CPU is doing
// the exact microsecond the button is pressed.
// It's an interrupt so it should be executed very fast hence should be stored in IRAM rather than
// in flash memory which would take time.
// To avoid the GURU meditation error
void IRAM_ATTR handleLampBtn()
{
    unsigned long currentTime = millis();
    // Debounce: Only accept a press if 200ms have passed since the last one
    if (currentTime - lastLampBtnTime > 200)
    {
        manualLampOverride = !manualLampOverride; // Toggle the state
        // Safety: If we turn the Lamp on manually, force the Fan off manually.
        if (manualLampOverride)
        {
            manualFanOverride = false;
        }
        lastLampBtnTime = currentTime;
    }
}

void IRAM_ATTR handleFanBtn()
{
    unsigned long currentTime = millis();
    if (currentTime - lastFanBtnTime > 200)
    {
        manualFanOverride = !manualFanOverride;
        // Safety: If we turn the Fan on manually, force the Lamp off manually.
        if (manualFanOverride)
            manualLampOverride = false;
        lastFanBtnTime = currentTime;
    }
}

// OUTPUT CONTROL HELPERS
// These tiny functions make the main code easier to read.
void setLampPWM(uint8_t duty) { ledcWrite(LAMP_CHANNEL, duty); }
void setProcessFanPWM(uint8_t duty) { ledcWrite(PROCESS_FAN_CHANNEL, duty); }
void setPCBfanPWM(uint8_t duty) { ledcWrite(PCB_FAN_CHANNEL, duty); }
void setLampLED(uint8_t duty) { ledcWrite(LAMP_LED_CHANNEL, duty); }
void setFanLED(uint8_t duty) { ledcWrite(FAN_LED_CHANNEL, duty); }

// A panic function to shut everything down safely
void allActuatorsSafe()
{
    setLampPWM(0);
    setProcessFanPWM(0);
    setPCBfanPWM(0);
    setLampLED(0);
    setFanLED(0);
    digitalWrite(BUZZER_PIN, LOW);
}

// CORE 0(The protocol core) - FIREBASE CLOUD TASK (Networking)
// This entire block runs on one CPU core,completely independent of the hardware.
void TaskCloudSync(void *pvParameters)
{
    Serial.println("Cloud task started.");

    // 1. Connect to the local router
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    while (WiFi.status() != WL_CONNECTED) // This loop runs until there's a connection
    {
        Serial.println("Waiting for WiFi...");
        // Yield the CPU to the operating system for 500ms so it doesn't freeze
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    Serial.println("WiFi connected.");

    // 2. Configure Firebase Credentials
    config.api_key = API_KEY;
    config.database_url = DATABASE_URL;

    // Try to log in securely
    // Anonymous signup
    if (Firebase.signUp(&config, &auth, "", ""))
    {
        signupOK = true;
        Serial.println("Firebase auth successful.");
    }
    else
    {
        Serial.println("Firebase auth failed.");
    }

    config.token_status_callback = tokenStatusCallback; // Provided by the addons/TokenHelper included at the top of this file
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true); // Auto-reconnect if router reboots

    // 3. The Infinite Cloud Loop
    for (;;)
    {
        // Only attempt internet comms if we are successfully logged in
        if (Firebase.ready() && signupOK)
        {

            double newTarget, newMin, newMax;
            bool targetOK = false, minOK = false, maxOK = false;

            // DOWNLOADING DATA FROM CLOUD
            // Target Temp
            if (Firebase.RTDB.getDouble(&fbdo, "/config/targetTemp"))
            {
                newTarget = fbdo.to<double>();
                targetOK = true;
            }
            // Min Temp
            if (Firebase.RTDB.getDouble(&fbdo, "/config/minTemp"))
            {
                newMin = fbdo.to<double>();
                minOK = true;
            }
            // Max Temp
            if (Firebase.RTDB.getDouble(&fbdo, "/config/maxTemp"))
            {
                newMax = fbdo.to<double>();
                maxOK = true;
            }

            // If we successfully receive all the three numbers
            if (targetOK && minOK && maxOK)
            {
                // run them through the safety check function.
                if (validTemperatureConfiguration(newMin, newTarget, newMax))
                {
                    // if safe,take the Mutex key, update the core variables, drop the key.
                    xSemaphoreTake(dataMutex, portMAX_DELAY);
                    targetTemp = newTarget;
                    minTemp = newMin;
                    maxTemp = newMax;
                    xSemaphoreGive(dataMutex);
                    Serial.println("Firebase config accepted.");
                }
                else
                {
                    Serial.println("Invalid Firebase config rejected.");
                }
            }

            // UPLOADING DATA TO CLOUD
            double processTempToSend;
            double pcbTempToSend;
            char processStatusToSend[21];
            char pcbTempMonitorStateToSend[21];

            // Take the Mutex key to safely read the current temperature from Core 1
            xSemaphoreTake(dataMutex, portMAX_DELAY);
            processTempToSend = currentTempProcess;
            pcbTempToSend = currentTempPCB;
            strlcpy(processStatusToSend, currentActuationState, sizeof(processStatusToSend));
            strlcpy(pcbTempMonitorStateToSend, currentPCBEnclosureActuationSate, sizeof(pcbTempMonitorStateToSend));
            bool localProcessOK = processSensorOK; // Check if the sensor is actually working
            bool localPcbOK = pcbSensorOK;
            xSemaphoreGive(dataMutex);

            // Delta-Driven Telemetry - Only upload if the sensor works and the temperature
            // has changed by more than 0.5 degrees since the last time we uploaded.
            // This saves database bandwidth.
            // I am on free plan so i dont want to hit the firebase limits by sending data frequently.
            if (localProcessOK)
            {
                if (!hasSentTemp || abs(processTempToSend - lastSentTemp) > 0.5)
                {
                    if (Firebase.RTDB.setDouble(&fbdo, "/telemetry/processTemp", processTempToSend))
                    {
                        lastSentTemp = processTempToSend; // Remember what we just sent
                        hasSentTemp = true;
                    }
                }
                if (!hasSentActuationState || (strcmp(processStatusToSend, prevActuationState) != 0))
                {
                    if (Firebase.RTDB.setString(&fbdo, "/telemetry/actuationState", processStatusToSend))
                    {
                        strlcpy(prevActuationState, processStatusToSend, sizeof(prevActuationState));
                        hasSentActuationState = true;
                    }
                }
            }

            if (localPcbOK)
            {
                if (!hasSentPCBTemp || abs(pcbTempToSend - lastSentPCBTemp) > 0.5)
                {
                    if (Firebase.RTDB.setDouble(&fbdo, "/telemetry/pcbTemp", pcbTempToSend))
                    {
                        lastSentPCBTemp = pcbTempToSend;
                        hasSentPCBTemp = true;
                    }

                    if (strcmp(pcbTempMonitorStateToSend, prevPCBTempMonitorState))
                    {
                        if (Firebase.RTDB.setString(&fbdo, "/telemetry/pcbCoolingState", pcbTempMonitorStateToSend))
                        {
                            strlcpy(prevPCBTempMonitorState, pcbTempMonitorStateToSend, sizeof(prevPCBTempMonitorState));
                        }
                    }
                }
            }
            else
            {
                char pcbEnclosureTempSensorError[21] = "PCB TEMP SENSOR ERR ";
                if (Firebase.RTDB.setString(&fbdo, "/telemetry/pcbCoolingState", pcbEnclosureTempSensorError))
                {
                    strlcpy(prevPCBTempMonitorState, pcbEnclosureTempSensorError, sizeof(prevPCBTempMonitorState));
                }
            }
        }
        // Pause the Cloud task for 2 seconds. FreeRTOS puts it to sleep.
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

// CORE 1(Application core) - HARDWARE CONTROL TASK (PID & Sensors)
// This runs on the second CPU core. It never waits for the internet.
void TaskHardwareControl(void *pvParameters)
{
    Serial.println("Hardware task started.");

    for (;;)
    { // Infinite hardware loop

        // 1 - Ask the Dallas library to read the temperature
        sensorProcess.requestTemperatures();
        sensorPCB.requestTemperatures();

        // The Dallaslibrary takes 750 milliseconds to do the math. We pause this task so the
        // CPU can do other background FreeRTOS things while we wait.
        vTaskDelay(pdMS_TO_TICKS(750));

        // 2 - Fetch the calculated numbers from the chips
        double tProcess = sensorProcess.getTempCByIndex(0);
        double tPCB = sensorPCB.getTempCByIndex(0);

        // 3 - Sensor Fault Detection
        // DEVICE_DISCONNECTED_C is a library macro (usually -127). If a wire breaks, we catch it here.
        bool processOK = (tProcess != DEVICE_DISCONNECTED_C);
        bool pcbOK = (tPCB != DEVICE_DISCONNECTED_C);

        // Additional safety: If it reads 125C, the sensor is short-circuiting.
        if (tProcess < -55.0 || tProcess > 125.0)
            processOK = false;
        if (tPCB < -55.0 || tPCB > 125.0)
            pcbOK = false;

        // 4 Update the global variables so Core 0 can see them
        xSemaphoreTake(dataMutex, portMAX_DELAY);
        if (processOK)
        {
            currentTempProcess = tProcess;
        }
        if (pcbOK)
        {
            currentTempPCB = tPCB;
        }
        processSensorOK = processOK;
        pcbSensorOK = pcbOK;

        // Make local copies of our limits and buttons so they don't change mid-calculation
        double localTarget = targetTemp;
        double localMin = minTemp;
        double localMax = maxTemp;
        bool localLampOverride = manualLampOverride;
        bool localFanOverride = manualFanOverride;
        xSemaphoreGive(dataMutex);

        char systemStatus[21];
        snprintf(systemStatus, sizeof(systemStatus), "SYSTEM NORMAL       "); // Default LCD text
        xSemaphoreTake(dataMutex, portMAX_DELAY);
        if (processOK)
        {
            strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
        }
        xSemaphoreGive(dataMutex);

        // THE STATE MACHINE LOGIC
        // FAULT STATE - Broken wire Do not run PID
        if (!processOK)
        {
            controlState = ControlState::SENSOR_FAULT;
            setLampPWM(0);         // Kill heater
            setProcessFanPWM(255); // Max cooling just in case
            setLampLED(0);
            setFanLED(255);
            // digitalWrite(BUZZER_PIN, HIGH); // Sound alarm
            tone(BUZZER_PIN, 1000); // sound alarm
            snprintf(systemStatus, sizeof(systemStatus), "PROCESS SENSOR FAULT");
            xSemaphoreTake(dataMutex, portMAX_DELAY);
            if (processOK)
            {
                strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
            }
            xSemaphoreGive(dataMutex);
        }
        // ALARM STATE - Too Hot
        else if (tProcess >= localMax)
        {
            controlState = ControlState::OVERHEAT_ALARM;
            setLampPWM(0);
            setProcessFanPWM(255);
            setLampLED(0);

            // Flash the Fan LED on and off every 250ms based on the system clock
            // Pulse the buzzer
            bool ledState = (millis() % 500) < 250;
            setFanLED(ledState ? 255 : 0);
            if (ledState)
            {
                tone(BUZZER_PIN, 1200); // Higher pitch for overheat
            }
            else
            {
                noTone(BUZZER_PIN); // Silence
            }
            digitalWrite(BUZZER_PIN, HIGH);
            snprintf(systemStatus, sizeof(systemStatus), "OVERHEAT ALARM      ");
            xSemaphoreTake(dataMutex, portMAX_DELAY);
            if (processOK)
            {
                strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
            }
            xSemaphoreGive(dataMutex);
        }
        // ALARM STATE - Too Cold!
        else if (tProcess <= localMin)
        {
            controlState = ControlState::UNDERHEAT_ALARM;
            setLampPWM(255);     // Force Max Heat
            setProcessFanPWM(0); // Kill Fan
            setLampLED(255);
            setFanLED(0);
            // digitalWrite(BUZZER_PIN, HIGH);
            tone(BUZZER_PIN, 1000);
            snprintf(systemStatus, sizeof(systemStatus), "UNDERHEAT ALARM     ");
            xSemaphoreTake(dataMutex, portMAX_DELAY);
            if (processOK)
            {
                strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
            }
            xSemaphoreGive(dataMutex);
        }
        // NORMAL OPERATION - Run the controllers(We are safe)
        else
        {
            // digitalWrite(BUZZER_PIN, LOW); // Silence the buzzer alarm
            noTone(BUZZER_PIN); // silence the  alarm

            // MANUAL LAMP OVERRIDE - Did the user press the Lamp button?
            if (localLampOverride)
            {
                controlState = ControlState::MANUAL_LAMP;
                setLampPWM(255);
                setProcessFanPWM(0);
                setLampLED(255);
                setFanLED(0);
                snprintf(systemStatus, sizeof(systemStatus), "MANUAL LAMP OVERRIDE");
                xSemaphoreTake(dataMutex, portMAX_DELAY);
                if (processOK)
                {
                    strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
                }
                xSemaphoreGive(dataMutex);
            }
            // MANUAL FAN OVERRIDE - Did the user press the Fan button?
            else if (localFanOverride)
            {
                controlState = ControlState::MANUAL_FAN;
                setLampPWM(0);
                setProcessFanPWM(255);
                setLampLED(0);
                setFanLED(255);
                snprintf(systemStatus, sizeof(systemStatus), "MANUAL FAN OVERRIDE ");
                xSemaphoreTake(dataMutex, portMAX_DELAY);
                if (processOK)
                {
                    strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
                }
                xSemaphoreGive(dataMutex);
            }
            // AUTOMATIC PID CONTROL
            else
            {
                // ZONE A - Below target --> Turn on the PID Heater
                if (tProcess <= localTarget)
                {
                    controlState = ControlState::HEATING;

                    pidInput = tProcess;       // Feed current temp to PID
                    pidSetPoint = localTarget; // Tell PID the goal
                    lampPID.Compute();         // Does the calculus and gives back pidOutput

                    pidOutput = clampDouble(pidOutput, 0.0, 255.0); // Safety limit

                    setLampPWM((uint8_t)pidOutput); // Send PWM signal to the MOSFET
                    setProcessFanPWM(0);            // Keep fan off while heating
                    setLampLED((uint8_t)pidOutput); // Dim the indicator LED to match the heater
                    setFanLED(0);
                    snprintf(systemStatus, sizeof(systemStatus), "HEATING             ");
                    xSemaphoreTake(dataMutex, portMAX_DELAY);
                    if (processOK)
                    {
                        strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
                    }
                    xSemaphoreGive(dataMutex);
                }
                // ZONE B & C - Above target --> Coasting(Deadband) or Cooling
                else
                {
                    double deadbandTop = localTarget + 2.0; // The 2-degree "Do Nothing" zone

                    // ZONE B: Deadband (Coasting)
                    if (tProcess <= deadbandTop)
                    {
                        controlState = ControlState::DEAD_BAND;
                        setLampPWM(0);       // Heater off
                        setProcessFanPWM(0); // Fan off
                        setLampLED(0);
                        setFanLED(0);
                        snprintf(systemStatus, sizeof(systemStatus), "SYSTEM NORMAL       ");
                        xSemaphoreTake(dataMutex, portMAX_DELAY);
                        if (processOK)
                        {
                            strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
                        }
                        xSemaphoreGive(dataMutex);
                    }
                    // ZONE C: Proportional Cooling
                    else
                    {
                        controlState = ControlState::COOLING;
                        setLampPWM(0);
                        setLampLED(0);

                        // Smoothly ramp up the fan speed as we get hotter.
                        // We start at 75 (not 0) so the DC motor doesn't stall.
                        long fanPWM = mapDouble(tProcess, deadbandTop, localMax, 75, 255);
                        fanPWM = constrain(fanPWM, 75, 255); // Safety limit

                        setProcessFanPWM((uint8_t)fanPWM); // Send to Fan MOSFET
                        setFanLED((uint8_t)fanPWM);        // Match LED

                        // Turn the 0-255 PWM value into a percentage
                        int fanPercent = map(fanPWM, 0, 255, 0, 100);

                        // Format the status directly into the fixed-size buffer.
                        snprintf(systemStatus, sizeof(systemStatus), "COOLING: %d%%       ", fanPercent);
                        xSemaphoreTake(dataMutex, portMAX_DELAY);
                        if (processOK)
                        {
                            strlcpy(currentActuationState, systemStatus, sizeof(currentActuationState));
                        }
                        xSemaphoreGive(dataMutex);
                    }
                }
            }
        }

        char pcbTempMonitorState[21];
        // PCB ENCLOSURE FAN (Hysteresis Logic)
        if (pcbOK)
        {
            // Turn ON if we hit 40C
            if (!pcbFanActive && tPCB >= PCB_FAN_ON_TEMP)
            {
                pcbFanActive = true;
                snprintf(pcbTempMonitorState, sizeof(pcbTempMonitorState), "PCB FAN IS ACTIVE   ");
                xSemaphoreTake(dataMutex, portMAX_DELAY);
                strlcpy(currentPCBEnclosureActuationSate, pcbTempMonitorState, sizeof(currentPCBEnclosureActuationSate));
                xSemaphoreGive(dataMutex);
            }
            // Turn OFF only when we cool down to 38C
            if (pcbFanActive && tPCB <= PCB_FAN_OFF_TEMP)
            {
                pcbFanActive = false;
                snprintf(pcbTempMonitorState, sizeof(pcbTempMonitorState), "PCB FAN IS OFF      ");
                xSemaphoreTake(dataMutex, portMAX_DELAY);
                strlcpy(currentPCBEnclosureActuationSate, pcbTempMonitorState, sizeof(currentPCBEnclosureActuationSate));
                xSemaphoreGive(dataMutex);
            }
        }
        else
        {
            // If the PCB sensor breaks,run the fan 100% of the time to be safe.
            pcbFanActive = true;
        }

        if (pcbFanActive)
        {
            setPCBfanPWM(255);
        }
        else
        {
            setPCBfanPWM(0);
        }

        // LCD DISPLAY UPDATES
        lcd.setCursor(0, 0);
        if (processOK)
            lcd.printf("Process: %.1f C   ", tProcess);
        else
            lcd.print("Process: SENSOR ERR ");

        lcd.setCursor(0, 1);
        lcd.printf("Target:  %.1f C   ", localTarget);

        lcd.setCursor(0, 2);
        if (pcbOK)
            lcd.printf("PCB Tmp: %.1f C   ", tPCB);
        else
            lcd.print("PCB Tmp: SENSOR ERR ");

        lcd.setCursor(0, 3);
        lcd.print(systemStatus);

        // Loop runs 10 times a second
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

// SYSTEM BOOT (Runs exactly once when power is applied)
void setup()
{
    Serial.begin(115200); // Start serial monitor for debugging

    // 1 - Create the Mutex Key for the dual-core memory
    dataMutex = xSemaphoreCreateMutex();
    if (dataMutex == NULL)
    {
        Serial.println("ERROR: Mutex creation failed.");
        while (true)
            delay(1000); // Crash system intentionally if memory fails
    }

    // 2 - Set up basic ON/OFF pins
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);

    // 3 - Set up Button pins using internal resistors (INPUT_PULLUP)
    pinMode(LAMP_BTN, INPUT_PULLUP);
    pinMode(FAN_BTN, INPUT_PULLUP);

    // The ESP32 to trigger our functions instantly when the button voltage FALLS (gets pressed)
    attachInterrupt(LAMP_BTN, handleLampBtn, FALLING);
    attachInterrupt(FAN_BTN, handleFanBtn, FALLING);

    // 4 - Start I2C bus and LCD
    Wire.begin(LCD_SDA, LCD_SCL);
    lcd.init();
    lcd.backlight();
    lcd.setCursor(0, 0);
    lcd.print("INIT SYSTEM...");

    // 5 - Start Dallas Temp Sensors
    sensorProcess.begin();
    sensorProcess.setWaitForConversion(false); // CRITICAL - Tells library not to freeze the CPU
    sensorPCB.begin();
    sensorPCB.setWaitForConversion(false);

    // 6 - Set up the ESP32 Hardware PWM Timers(Core v2.x API)
    ledcSetup(LAMP_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(LAMP_PWM_PIN, LAMP_CHANNEL);

    ledcSetup(PROCESS_FAN_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(PROCESS_FAN_PWM_PIN, PROCESS_FAN_CHANNEL);

    ledcSetup(PCB_FAN_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(PCB_FAN_PWM_PIN, PCB_FAN_CHANNEL);

    ledcSetup(LAMP_LED_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(LAMP_LED, LAMP_LED_CHANNEL);

    ledcSetup(FAN_LED_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(FAN_LED, FAN_LED_CHANNEL);

    // 7 - Force all hardware off immediately for safety
    allActuatorsSafe();

    // 8 - Configure PID limits
    lampPID.SetMode(AUTOMATIC);
    lampPID.SetOutputLimits(0, 255); // Output can't exceed 255
    lampPID.SetSampleTime(1000);     // Calculate once per second

    // 9 - SPAWN THE TASKS TO THE CORES
    xTaskCreatePinnedToCore(
        TaskCloudSync, // The function to run
        "TaskCloud",   // A name for debugging
        10000,         // Bytes of RAM dedicated to this task
        NULL,          // No parameters passed
        1,             // Priority (1 is standard)
        NULL,          // No task handle needed
        0              // Pin to Core 0
    );

    xTaskCreatePinnedToCore(
        TaskHardwareControl,
        "TaskHardware",
        10000,
        NULL,
        2, // Priority 2 (Higher priority than Wi-Fi so hardware always runs on time)
        NULL,
        1 // Pin to Core 1
    );

    Serial.println("Boot complete.");
}

// LOOP IS NOT NEEDED
void loop()
{
    // Because we created our own infinite Task loops above, this default Arduino loop
    // is completely useless. We delete it to free up the RAM.
    vTaskDelete(NULL);
}
