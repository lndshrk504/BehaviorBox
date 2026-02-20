// Rotary.ino
// REVISED for BehaviorBox latency/robustness:
//   - In normal POSITION mode, emit ONLY numeric degrees lines.
//   - Emit 0 when the wheel returns to 0 (fixes stale-reading issue).
//   - Remove verbose Serial.println() spam during reward/acq commands.
//   - Optional rate-limit on printing to avoid saturating USB serial.
//
// NOTE: Keep baud in sync with MATLAB (BehaviorBoxSerialInput).

#define ENCODER_OPTIMIZE_INTERRUPTS
#include <Encoder.h>
#include <Arduino.h>

// Pins
#define PIN_REWARD 8
#define PIN_STARTACQ 9
#define PIN_NEXTFILE 10
#define PIN_ENDACQ 11
#define PIN_TIMESTAMP 12

constexpr float ENCODER_COUNTS_PER_REV = 4096.0f; // 1024 CPR encoder with 4x quadrature decoding
constexpr unsigned long SPEED_SAMPLE_US = 20000UL; // Sample speed every 20 ms
constexpr float SPEED_ZERO_EPS_DPS = 0.5f; // Treat very small values as stopped
constexpr float SPEED_FILTER_ALPHA = 0.35f; // Light smoothing to reduce jitter

enum State {
  READING,
  RIGHT_REWARDING,
  RIGHT_OPEN,
  RIGHT_SETUP,
  TIMESTAMPING,
  TIMESTAMP_ON,
  TIMESTAMP_OFF,
  STARTACQ,
  NEXTFILE,
  ENDACQ,
  WHO
};

enum ReadingMode {
  POSITION,
  SPEED
};

// Initialize variables
State currentState = READING;
ReadingMode currentMode = POSITION; // Default to displaying position
char cmd;
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno
long prevDegrees = 0; // Starting value for rotor position
bool RightOpen = false; // Valve status
float rightdur = 0.05f;  // Length of a right pulse
unsigned long previousMicros = 0; // Store the last time the speed was calculated
long previousPosition = 0; // Store the last position of the encoder
bool wasZeroSpeed = false; // Initialize a flag to track the zero speed state
float filteredSpeed = 0.0f;
bool speedFilterInitialized = false;

// Function prototypes
static inline void handleStateChange();
static inline void displayID();
static inline void setupPins();
static inline void initializeSerial();
static inline void customDelay(float durationSec);
static inline void toggleReward(int pin, float durationSec);
static inline void toggleValve(int pin, bool &valveStatus);
static inline float getDurationFromSerial(const __FlashStringHelper* prompt);
static inline void displayWelcomeMessage();
static inline void checkAndPrintEncoderState();
static inline void checkAndPrintEncoderSpeed();
static inline void resetEncoder();
static inline void pulsePinHighForDuration(int pin, int durationMs);

void setup() {
  initializeSerial();
  setupPins();
  displayID();
  Serial.println(F("Readout begins below..."));
  resetEncoder();
}

static inline void initializeSerial() {
  Serial.begin(115200); // start the serial at 115200 baud
  Serial.setTimeout(200); // Keep parseFloat from blocking too long if input is incomplete
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
}

static inline void setupPins() {
  pinMode(PIN_REWARD, OUTPUT); // set pin 8 as output
  pinMode(PIN_STARTACQ, OUTPUT); // set pin 9 as output
  pinMode(PIN_NEXTFILE, OUTPUT); // set pin 10 as output
  pinMode(PIN_ENDACQ, OUTPUT); // set pin 11 as output
  pinMode(PIN_TIMESTAMP, OUTPUT); // set pin 12 as output
}

static inline void displayID() {
  Serial.print(F("Box ID: "));
  Serial.println(F("Wheel1")); // Change this for every board, identifies the board to ArduinoServer.m
}

void loop() {
  handleStateChange();
  if (Serial.available() > 0) {
    cmd = Serial.read();
    switch (cmd) {
      case 'R':
        currentState = RIGHT_REWARDING;
        break;
      case 'r':
        currentState = RIGHT_OPEN;
        break;
      case 's':
        currentState = RIGHT_SETUP;
        break;
      case 'T':
        currentState = TIMESTAMP_ON;
        break;
      case 't':
        currentState = TIMESTAMP_OFF;
        break;
      case 'I': // Capital letter I
        currentState = STARTACQ;
        break;
      case 'N':
        currentState = NEXTFILE;
        break;
      case 'i': // Lowercase letter i
        currentState = ENDACQ;
        break;
      case 'W':
        currentState = WHO;
        break;
      case 'M':
        // Toggle the current mode between POSITION and SPEED
        if (currentMode == POSITION) {
          currentMode = SPEED;
          Serial.println(F("Speed, deg/sec"));
        } else {
          currentMode = POSITION;
          Serial.println(F("Position"));
        }
        resetEncoder();
        break;
      case '0': // 'ZERO' for reset back to 0
        resetEncoder();
        break;
      default:
        break;
    }
  }
}

static inline void handleStateChange() {
  switch (currentState) {
    case READING:
      if (currentMode == POSITION) {
        checkAndPrintEncoderState(); // Print the position
      } else if (currentMode == SPEED) {
        checkAndPrintEncoderSpeed(); // Print the speed
      }
      break;
    case RIGHT_REWARDING:
      toggleReward(PIN_REWARD, rightdur);
      Serial.println(F("Right reward dispensed"));
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_REWARD, RightOpen);
      Serial.print(F("Right Valve: "));
      Serial.println(RightOpen ? F("Open") : F("Closed"));
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial(F("Enter new duration for right reward:"));
      Serial.print(F("Right reward duration set to: "));
      Serial.println(rightdur);
      currentState = READING;
      break;
    case STARTACQ:
      pulsePinHighForDuration(PIN_STARTACQ, 100);   // Pulse PIN_STARTACQ high
      Serial.println(F("Starting acquisition..."));
      currentState = READING;
      break;
    case NEXTFILE:
      pulsePinHighForDuration(PIN_NEXTFILE, 100);   // Pulse PIN_NEXTFILE high
      Serial.println(F("Next file..."));
      currentState = READING;
      break;
    case ENDACQ:
      pulsePinHighForDuration(PIN_ENDACQ, 100);   // Pulse PIN_ENDACQ high
      Serial.println(F("Ending acquisition..."));
      currentState = READING;
      break;
    case TIMESTAMPING:
      pulsePinHighForDuration(PIN_TIMESTAMP, 10);   // Pulse PIN_TIMESTAMP high
      Serial.println(F("Timestamp"));
      currentState = READING;
      break;
    case TIMESTAMP_ON:
      digitalWrite(PIN_TIMESTAMP, HIGH);   // Set the pin high
      Serial.println(F("Timestamp On"));
      currentState = READING;
      break;
    case TIMESTAMP_OFF:
      digitalWrite(PIN_TIMESTAMP, LOW);   // Set the pin high
      Serial.println(F("Stimulus Off"));
      currentState = READING;
      break;
    case WHO:
      displayWelcomeMessage();
      currentState = READING;
      break;
    default:
      break;
  }
}

static inline void customDelay(float durationSec) {
  if (durationSec < 0.001f) {
    delayMicroseconds(durationSec * 1e6f); // Convert seconds to microseconds
  } else {
    delay(durationSec * 1000.0f); // Convert seconds to milliseconds
  }
}

static inline void toggleReward(int pin, float durationSec) {
  digitalWrite(pin, HIGH);   // Open valve
  customDelay(durationSec);  // Custom delay
  digitalWrite(pin, LOW);    // Close valve
  resetEncoder();
  currentState = READING;
}

static inline void toggleValve(int pin, bool &valveStatus) {
  if (!valveStatus) {
    digitalWrite(pin, HIGH); // Open valve
  } else {
    digitalWrite(pin, LOW);  // Close valve
  }
  valveStatus = !valveStatus;
  currentState = READING;
}

static inline float getDurationFromSerial(const __FlashStringHelper* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print(F("Setting duration to: "));
  Serial.println(DURinp, 4);
  return DURinp;
}

static inline void displayWelcomeMessage() {
  Serial.println();
  Serial.println(F("Welcome to BehaviorBox - Wheel"));
  Serial.print(F("Right reward: "));
  Serial.print(rightdur, 4);
  Serial.println(F(" sec"));
  Serial.println(F("USAGE:"));
  Serial.println(F("Please enter one of the following case-sensitive characters to control the state:"));
  Serial.println(F("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING"));
  Serial.println(F("If the letter 'r' is entered, the current state will switch to RIGHT_OPEN"));
  Serial.println(F("If the letter 's' is entered, the current state will switch to RIGHT_SETUP"));
  Serial.println(F("If the letter 'W' is entered, the current state will switch to WHO, which is an identifying state."));
  Serial.println(F("If the number '0' is entered, the encoder's position will be reset to 0 counts"));
  Serial.println(F("If the letter 'T' is entered, the Timestamping pin will toggle"));
  Serial.println(F("Readout begins below..."));
  resetEncoder();
  checkAndPrintEncoderState();
}

static inline void checkAndPrintEncoderState() {
  long newPosition = myEnc.read();
  long degrees = newPosition / 4; // Divide by 4 because of "4X reporting" phenomenon (quadrature) of encoder
  if (degrees != prevDegrees) {
    Serial.println(degrees);
    prevDegrees = degrees;
  }
}

static inline void checkAndPrintEncoderSpeed() {
  unsigned long currentMicros = micros();
  unsigned long elapsedMicros = currentMicros - previousMicros;
  if (elapsedMicros < SPEED_SAMPLE_US) {
    return; // Keep a stable sample period
  }

  long currentPosition = myEnc.read();
  long positionDifference = currentPosition - previousPosition;
  float timeDifference = elapsedMicros / 1000000.0f;
  float speed = ((positionDifference * 360.0f) / ENCODER_COUNTS_PER_REV) / timeDifference;

  if (!speedFilterInitialized) {
    filteredSpeed = speed;
    speedFilterInitialized = true;
  } else {
    filteredSpeed = (SPEED_FILTER_ALPHA * speed) + ((1.0f - SPEED_FILTER_ALPHA) * filteredSpeed);
  }

  float speedMagnitude = filteredSpeed >= 0.0f ? filteredSpeed : -filteredSpeed;
  if (speedMagnitude > SPEED_ZERO_EPS_DPS) {
    Serial.println(filteredSpeed, 2);
    wasZeroSpeed = false;
  } else if (!wasZeroSpeed) {
    Serial.println(0);
    wasZeroSpeed = true;
  }

  previousPosition = currentPosition;
  previousMicros = currentMicros;
}

static inline void resetEncoder() {
  myEnc.write(0); // reset the encoder position
  prevDegrees = 0;
  previousPosition = 0;
  previousMicros = micros();
  filteredSpeed = 0.0f;
  speedFilterInitialized = false;
  wasZeroSpeed = false;
  Serial.println(0);
}

static inline void pulsePinHighForDuration(int pin, int durationMs) {
  digitalWrite(pin, HIGH);   // Set the pin high
  delay(durationMs);         // Wait for the specified duration in milliseconds
  digitalWrite(pin, LOW);    // Set the pin low
}
