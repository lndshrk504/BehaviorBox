// FakeRoscope.ino
// Target board: Arduino Uno.

#include <Arduino.h>

constexpr uint8_t PIN_FRAME_CLOCK = 4;
constexpr uint8_t PIN_START_ACQ = 5;
constexpr uint8_t PIN_NEXT_FILE = 6;
constexpr uint8_t PIN_END_ACQ = 7;

constexpr unsigned long SERIAL_BAUD = 115200;
constexpr unsigned long SERIAL_WAIT_TIMEOUT_MS = 2000UL;
constexpr unsigned long FRAME_PERIOD_US = 1000000UL / 17UL;
constexpr unsigned long FRAME_HIGH_US = FRAME_PERIOD_US / 2UL;
constexpr unsigned long FRAME_LOW_US = FRAME_PERIOD_US - FRAME_HIGH_US;

bool acquisitionRunning = true;
bool frameClockHigh = false;
unsigned long lastFrameTransitionUs = 0UL;

bool previousStartState = LOW;
bool previousNextFileState = LOW;
bool previousEndState = LOW;

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

void setup() {
  Serial.begin(SERIAL_BAUD);
  const unsigned long serialWaitStartMs = millis();
  while (!Serial && (millis() - serialWaitStartMs) < SERIAL_WAIT_TIMEOUT_MS) { }

  pinMode(PIN_FRAME_CLOCK, OUTPUT);
  digitalWrite(PIN_FRAME_CLOCK, LOW);

  pinMode(PIN_START_ACQ, INPUT);
  pinMode(PIN_NEXT_FILE, INPUT);
  pinMode(PIN_END_ACQ, INPUT);

  previousStartState = (digitalRead(PIN_START_ACQ) == HIGH);
  previousNextFileState = (digitalRead(PIN_NEXT_FILE) == HIGH);
  previousEndState = (digitalRead(PIN_END_ACQ) == HIGH);

  startFrameClock();

  Serial.println(F("Box ID: FakeRoscope"));
  Serial.println(F("Frame clock output: pin 4"));
  Serial.println(F("Control inputs: pin 5 start, pin 6 next file, pin 7 end"));
  Serial.println(F("Frame clock: 17 Hz, 50% duty cycle"));
  Serial.println(F("Acquisition running"));
}

void loop() {
  handleControlInputs();
  updateFrameClock();
}
