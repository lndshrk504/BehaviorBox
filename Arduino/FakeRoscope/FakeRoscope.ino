// FakeRoscope.ino
// Target board: Arduino Uno.

#include <Arduino.h>

constexpr uint8_t PIN_FRAME_CLOCK = 4;
constexpr uint8_t PIN_START_ACQ = 5;
constexpr uint8_t PIN_NEXT_FILE = 6;
constexpr uint8_t PIN_END_ACQ = 7;

constexpr unsigned long SERIAL_BAUD = 115200;
constexpr unsigned long SERIAL_WAIT_TIMEOUT_MS = 2000UL;
//constexpr unsigned long FRAME_PERIOD_US = 1000000UL / 17UL; // 17 hz
constexpr unsigned long FRAME_PERIOD_US = 2000000UL; // 0.5 hz
constexpr unsigned long FRAME_HIGH_US = FRAME_PERIOD_US / 2UL;
constexpr unsigned long FRAME_LOW_US = FRAME_PERIOD_US - FRAME_HIGH_US;

bool acquisitionRunning = false;
bool frameClockHigh = false;
unsigned long lastFrameTransitionUs = 0UL;

bool previousStartState = LOW;
bool previousNextFileState = LOW;
bool previousEndState = LOW;

static inline void printFrameRateHz() {
  Serial.print(1000000.0 / static_cast<double>(FRAME_PERIOD_US), 3);
}

static inline void printUsageAndStatus() {
  Serial.println(F("FakeRoscope usage"));
  Serial.println(F("Serial commands:"));
  Serial.println(F("  ? : print this help and current status"));
  Serial.println(F("  S : toggle the frame clock on or off"));
  Serial.println(F("Pins:"));
  Serial.print(F("  Pin 4 output: "));
  printFrameRateHz();
  Serial.println(F(" Hz frame clock to Timekeeper pin 3"));
  Serial.println(F("  Pin 5 input : start acquisition from Rotary"));
  Serial.println(F("  Pin 6 input : next file from Rotary"));
  Serial.println(F("  Pin 7 input : end acquisition from Rotary"));
  Serial.println(F("Behavior:"));
  Serial.println(F("  Starts stopped at boot"));
  Serial.println(F("  Start input begins the frame clock"));
  Serial.println(F("  Next file input logs a message only"));
  Serial.println(F("  End input stops the frame clock and forces pin 4 LOW"));
  Serial.println(F("Electrical notes:"));
  Serial.println(F("  Pins 5, 6, 7 use INPUT_PULLUP"));
  Serial.println(F("  Use a shared ground between boards"));
  Serial.print(F("Status: acquisition "));
  Serial.println(acquisitionRunning ? F("running") : F("stopped"));
  Serial.print(F("Frame output level: "));
  Serial.println(frameClockHigh ? F("HIGH") : F("LOW"));
}

static inline void startFrameClock() {
  acquisitionRunning = true;
  frameClockHigh = false;
  digitalWrite(PIN_FRAME_CLOCK, LOW);
  lastFrameTransitionUs = micros();
}

static inline void stopFrameClock() {
  acquisitionRunning = false;
  frameClockHigh = false;
  digitalWrite(PIN_FRAME_CLOCK, LOW);
}

static inline void updateFrameClock() {
  if (!acquisitionRunning) {
    return;
  }

  const unsigned long nowUs = micros();
  const unsigned long phaseDurationUs = frameClockHigh ? FRAME_HIGH_US : FRAME_LOW_US;
  if ((nowUs - lastFrameTransitionUs) < phaseDurationUs) {
    return;
  }

  lastFrameTransitionUs += phaseDurationUs;
  frameClockHigh = !frameClockHigh;
  digitalWrite(PIN_FRAME_CLOCK, frameClockHigh ? HIGH : LOW);
}

static inline void handleControlInputs() {
  const bool startState = (digitalRead(PIN_START_ACQ) == HIGH);
  if (startState && !previousStartState) {
    startFrameClock();
    Serial.println(F("Start acquisition received"));
  }
  previousStartState = startState;

  const bool nextFileState = (digitalRead(PIN_NEXT_FILE) == HIGH);
  if (nextFileState && !previousNextFileState) {
    Serial.println(F("Next file received"));
  }
  previousNextFileState = nextFileState;

  const bool endState = (digitalRead(PIN_END_ACQ) == HIGH);
  if (endState && !previousEndState) {
    stopFrameClock();
    Serial.println(F("End acquisition received"));
  }
  previousEndState = endState;
}

static inline void handleSerialCommands() {
  while (Serial.available() > 0) {
    const char cmd = static_cast<char>(Serial.read());
    if (cmd == '?') {
      printUsageAndStatus();
    } else if (cmd == 'S') {
      if (acquisitionRunning) {
        stopFrameClock();
        Serial.println(F("Frame clock stopped from serial"));
      } else {
        startFrameClock();
        Serial.println(F("Frame clock started from serial"));
      }
    }
  }
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  const unsigned long serialWaitStartMs = millis();
  while (!Serial && (millis() - serialWaitStartMs) < SERIAL_WAIT_TIMEOUT_MS) { }

  pinMode(PIN_FRAME_CLOCK, OUTPUT);
  digitalWrite(PIN_FRAME_CLOCK, LOW);

  pinMode(PIN_START_ACQ, INPUT_PULLUP);
  pinMode(PIN_NEXT_FILE, INPUT_PULLUP);
  pinMode(PIN_END_ACQ, INPUT_PULLUP);

  previousStartState = (digitalRead(PIN_START_ACQ) == HIGH);
  previousNextFileState = (digitalRead(PIN_NEXT_FILE) == HIGH);
  previousEndState = (digitalRead(PIN_END_ACQ) == HIGH);

  stopFrameClock();

  Serial.println(F("Box ID: FakeRoscope"));
  Serial.println(F("Frame clock output: pin 4"));
  Serial.println(F("Control inputs: pin 5 start, pin 6 next file, pin 7 end"));
  Serial.print(F("Frame clock: "));
  printFrameRateHz();
  Serial.println(F(" Hz, 50% duty cycle"));
  Serial.println(F("Waiting for start signal"));
  Serial.println(F("Send ? for help and status"));
}

void loop() {
  handleSerialCommands();
  handleControlInputs();
  updateFrameClock();
}
