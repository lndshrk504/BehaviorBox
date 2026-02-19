// Photogate_Revised.ino
// REVISED for BehaviorBox latency/robustness:
//   - In normal READING mode, emit ONLY single-character tokens: L/M/R/-
//   - Remove verbose Serial.println() spam during reward/setup commands.
//   - Prefix any human-readable messages with '#' so MATLAB can ignore.

#include <Arduino.h>

#define PIN_L 4
#define PIN_M 5
#define PIN_R 6
#define PIN_VALVE_L 7
#define PIN_VALVE_R 8

enum State {
  READING,
  RIGHT_REWARDING,
  LEFT_REWARDING,
  RIGHT_OPEN,
  LEFT_OPEN,
  LEFT_SETUP,
  RIGHT_SETUP,
  WHO,
  SETUP
};

State currentState = READING;
char cmd;

float rightdur = 0.04f; // Default duration
float leftdur  = 0.04f;  // Default duration

bool hasPrintedFlags[4] = {false, false, false, false};
bool RightOpen = false;
bool LeftOpen  = false;

void displayID() {
  Serial.print("Box ID: ");Serial.println("Nose3");

  resetFlags();
}

static inline void customDelay(float durationSec) {
  if (durationSec < 0.001f) {
    delayMicroseconds((uint32_t)(durationSec * 1e6f));
  } else {
    delay((uint32_t)(durationSec * 1000.0f));
  }
}

static inline void setNoneFlag() {
  resetFlags();
  hasPrintedFlags[3] = true;
}

static inline void toggleReward(int pin, float durationSec) {
  digitalWrite(pin, HIGH);
  customDelay(durationSec);
  digitalWrite(pin, LOW);
  resetFlags();
  // currentState = READING; // Return to initial state
}

static inline void toggleValve(int pin, bool &state) {
  digitalWrite(pin, state ? LOW : HIGH);
  state = !state;
  resetFlags();
  // currentState = READING; // Return to initial state
}

static float getDurationFromSerial(const char* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print("Setting duration to: "); Serial.println(DURinp, 4);
  return DURinp;
}

static inline void displayWelcomeMessage() {
  Serial.println("NosePoke");
  Serial.print("Right dur="); Serial.println(rightdur, 4);
  Serial.print("Left dur="); Serial.println(leftdur, 4);
}

static inline void checkAndPrintPhotogateState() {
  if (!hasPrintedFlags[0] && digitalRead(PIN_L) == LOW) {
    Serial.println('L');
    hasPrintedFlags[0] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[1] && digitalRead(PIN_M) == LOW) {
    Serial.println('M');
    hasPrintedFlags[1] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[2] && digitalRead(PIN_R) == LOW) {
    Serial.println('R');
    hasPrintedFlags[2] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[3] &&
             digitalRead(PIN_L) == HIGH &&
             digitalRead(PIN_M) == HIGH &&
             digitalRead(PIN_R) == HIGH) {
    Serial.println('-');
    resetFlags(); // Uncomment to only reset flags when None are selected (Multiple mice in one box)
    hasPrintedFlags[3] = true;
  } else if (hasPrintedFlags[0] && digitalRead(PIN_L) == HIGH) {
    hasPrintedFlags[0] = false;
  } else if (hasPrintedFlags[1] && digitalRead(PIN_M) == HIGH) {
    hasPrintedFlags[1] = false;
  } else if (hasPrintedFlags[2] && digitalRead(PIN_R) == HIGH) {
    hasPrintedFlags[2] = false;
  }
}

static inline void resetFlags() {
  for (int i = 0; i < 4; i++) hasPrintedFlags[i] = false;
}
static inline void handleStateChange() {
  switch (currentState) {
    case READING:
      checkAndPrintPhotogateState();
      break;
    case RIGHT_REWARDING:
      toggleReward(PIN_VALVE_R, rightdur);
      //Serial.println("Right reward dispensed");
      currentState = READING;
      break;
    case LEFT_REWARDING:
      toggleReward(PIN_VALVE_L, leftdur);
      //Serial.println("Left reward dispensed");
      currentState = READING;
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_VALVE_R, RightOpen);
      Serial.print("Right Valve: ");
      Serial.println(RightOpen ? "Open" : "Closed");
      currentState = READING;
      break;
    case LEFT_OPEN:
      toggleValve(PIN_VALVE_L, LeftOpen);
      Serial.print("Left Valve: ");
      Serial.println(LeftOpen ? "Open" : "Closed");
      currentState = READING;
      break;
    case LEFT_SETUP:
      leftdur = getDurationFromSerial("Enter new duration for left reward:");
      Serial.print("Left dur="); Serial.println(leftdur);
      currentState = READING;
      resetFlags();
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial("Enter new duration for right reward:");
      Serial.print("Right dur="); Serial.println(rightdur);
      currentState = READING;
      resetFlags();
      break;
    case WHO:
      displayID();
      currentState = READING;
      break;
    case SETUP:
      displayWelcomeMessage();
      currentState = WHO;
      break;
    default: break;
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
  pinMode(PIN_L, INPUT_PULLUP);
  pinMode(PIN_M, INPUT_PULLUP);
  pinMode(PIN_R, INPUT_PULLUP);
  pinMode(PIN_VALVE_L, OUTPUT);
  pinMode(PIN_VALVE_R, OUTPUT);
  displayID();
  Serial.println("Readout begins below...");
}

void loop() {
  handleStateChange();
  if (Serial.available() > 0) {
    cmd = Serial.read();
    switch (cmd) {
      case 'R': currentState = RIGHT_REWARDING; break;
      case 'L': currentState = LEFT_REWARDING; break;
      case 'r': currentState = RIGHT_OPEN; break;
      case 'l': currentState = LEFT_OPEN; break;
      case 's': currentState = RIGHT_SETUP; break;
      case 'S': currentState = LEFT_SETUP; break;
      case 'W': currentState = SETUP; break;
      case '?': currentState = WHO; break;
      default: break;
    }
  }
}