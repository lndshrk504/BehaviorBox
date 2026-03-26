// Photogate_Revised.ino
// Target board: Arduino Uno.
// REVISED for BehaviorBox latency/robustness:
//   - In normal READING mode, emit ONLY single-character tokens: L/M/R/-
//   - Remove verbose Serial.println() spam during reward/setup commands.

#include <Arduino.h>

#define PIN_L 4
#define PIN_M 5
#define PIN_R 6
#define PIN_VALVE_L 7
#define PIN_VALVE_R 8

constexpr unsigned long SERIAL_PARSE_TIMEOUT_MS = 5000UL;

enum FlagIndex : uint8_t {
  FLAG_L = 0,
  FLAG_M = 1,
  FLAG_R = 2,
  FLAG_NONE = 3
};

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
float leftdur  = 0.04f; // Default duration

bool hasPrintedFlags[4] = {false, false, false, false};
bool RightOpen = false;
bool LeftOpen  = false;

// Function prototypes
static inline void handleStateChange();
static inline void displayID();
static inline void setupPins();
static inline void initializeSerial();
static inline void customDelay(float durationSec);
static inline void toggleReward(int pin, float durationSec);
static inline void toggleValve(int pin, bool &state);
static inline float getDurationFromSerial(const __FlashStringHelper* prompt);
static inline bool tryHandleInlineSetup(bool isRight);
static inline void displayWelcomeMessage();
static inline void checkAndPrintPhotogateState();
static inline void resetFlags();
static inline void printToken(char token);

void setup() {
  initializeSerial();
  setupPins();
  displayID();
  Serial.println(F("Readout begins below..."));
}

void loop() {
  handleStateChange();
  if (Serial.available() > 0) {
    cmd = Serial.read();
    switch (cmd) {
      case 'R':
        currentState = RIGHT_REWARDING;
        break;
      case 'L':
        currentState = LEFT_REWARDING;
        break;
      case 'r':
        currentState = RIGHT_OPEN;
        break;
      case 'l':
        currentState = LEFT_OPEN;
        break;
      case 's':
        if (!tryHandleInlineSetup(true)) {
          currentState = RIGHT_SETUP;
        }
        break;
      case 'S':
        if (!tryHandleInlineSetup(false)) {
          currentState = LEFT_SETUP;
        }
        break;
      case 'W':
        currentState = SETUP;
        break;
      case '?':
        currentState = WHO;
        break;
      default:
        break;
    }
  }
}

static inline void initializeSerial() {
  Serial.begin(115200);
  Serial.setTimeout(SERIAL_PARSE_TIMEOUT_MS); // Allow interactive terminal entry for setup durations
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
}

static inline void setupPins() {
  pinMode(PIN_L, INPUT_PULLUP);
  pinMode(PIN_M, INPUT_PULLUP);
  pinMode(PIN_R, INPUT_PULLUP);
  pinMode(PIN_VALVE_L, OUTPUT);
  pinMode(PIN_VALVE_R, OUTPUT);
  digitalWrite(PIN_VALVE_L, LOW);
  digitalWrite(PIN_VALVE_R, LOW);
}

static inline void displayID() {
  Serial.print(F("Box ID: "));
  Serial.println(F("Nose3"));
  resetFlags();
}

static inline void handleStateChange() {
  switch (currentState) {
    case READING:
      checkAndPrintPhotogateState();
      break;
    case RIGHT_REWARDING:
      toggleReward(PIN_VALVE_R, rightdur);
      Serial.println(F("Right reward dispensed"));
      currentState = READING;
      break;
    case LEFT_REWARDING:
      toggleReward(PIN_VALVE_L, leftdur);
      Serial.println(F("Left reward dispensed"));
      currentState = READING;
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_VALVE_R, RightOpen);
      Serial.print(F("Right Valve: "));
      Serial.println(RightOpen ? F("Open") : F("Closed"));
      currentState = READING;
      break;
    case LEFT_OPEN:
      toggleValve(PIN_VALVE_L, LeftOpen);
      Serial.print(F("Left Valve: "));
      Serial.println(LeftOpen ? F("Open") : F("Closed"));
      currentState = READING;
      break;
    case LEFT_SETUP:
      leftdur = getDurationFromSerial(F("Enter new duration for left reward:"));
      Serial.print(F("Left dur="));
      Serial.println(leftdur);
      currentState = READING;
      resetFlags();
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial(F("Enter new duration for right reward:"));
      Serial.print(F("Right dur="));
      Serial.println(rightdur);
      currentState = READING;
      resetFlags();
      break;
    case WHO:
      displayID();
      currentState = READING;
      break;
    case SETUP:
      displayWelcomeMessage();
      currentState = READING;
      break;
    default:
      break;
  }
}

static inline void customDelay(float durationSec) {
  if (durationSec < 0.001f) {
    delayMicroseconds((uint32_t)(durationSec * 1e6f));
  } else {
    delay((uint32_t)(durationSec * 1000.0f));
  }
}

static inline void toggleReward(int pin, float durationSec) {
  digitalWrite(pin, HIGH);
  customDelay(durationSec);
  digitalWrite(pin, LOW);
  resetFlags();
}

static inline void toggleValve(int pin, bool &state) {
  digitalWrite(pin, state ? LOW : HIGH);
  state = !state;
  resetFlags();
}

static inline float getDurationFromSerial(const __FlashStringHelper* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print(F("Setting duration to: "));
  Serial.println(DURinp, 4);
  return DURinp;
}

static inline bool tryHandleInlineSetup(bool isRight) {
  // Skip whitespace after command byte so inputs like "s 0.05" are accepted.
  while (Serial.available() > 0) {
    const int peeked = Serial.peek();
    if (peeked == ' ' || peeked == '\t' || peeked == '\r') {
      Serial.read();
    } else {
      break;
    }
  }

  if (Serial.available() == 0) {
    return false;
  }

  const int peeked = Serial.peek();
  const bool looksNumeric = (peeked == '-') || (peeked == '+') || (peeked == '.') || (peeked >= '0' && peeked <= '9');
  if (!looksNumeric) {
    return false;
  }

  float duration = Serial.parseFloat();
  if (isRight) {
    rightdur = duration;
    Serial.print(F("Right dur="));
    Serial.println(rightdur);
  } else {
    leftdur = duration;
    Serial.print(F("Left dur="));
    Serial.println(leftdur);
  }
  currentState = READING;
  resetFlags();
  return true;
}

static inline void displayWelcomeMessage() {
  Serial.println();
  Serial.println(F("Welcome to BehaviorBox - NosePoke"));
  Serial.print(F("Right reward: "));
  Serial.print(rightdur, 4);
  Serial.println(F(" sec"));
  Serial.print(F("Left reward: "));
  Serial.print(leftdur, 4);
  Serial.println(F(" sec"));
  Serial.println(F("USAGE:"));
  Serial.println(F("Please enter one of the following case-sensitive characters to control the state:"));
  Serial.println(F("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING"));
  Serial.println(F("If the letter 'L' is entered, the current state will switch to LEFT_REWARDING"));
  Serial.println(F("If the letter 'r' is entered, the current state will switch to RIGHT_OPEN"));
  Serial.println(F("If the letter 'l' is entered, the current state will switch to LEFT_OPEN"));
  Serial.println(F("If the letter 's' is entered, the current state will switch to RIGHT_SETUP"));
  Serial.println(F("If the letter 'S' is entered, the current state will switch to LEFT_SETUP"));
  Serial.println(F("If the letter 'W' is entered, setup/help information will be printed"));
  Serial.println(F("If the letter '?' is entered, the board will print its ID"));
  Serial.println(F("Readout tokens during READING mode: L, M, R, -"));
  Serial.println(F("Readout begins below..."));
  resetFlags();
  checkAndPrintPhotogateState();
}

static inline void checkAndPrintPhotogateState() {
  const bool lHigh = (digitalRead(PIN_L) == HIGH);
  const bool mHigh = (digitalRead(PIN_M) == HIGH);
  const bool rHigh = (digitalRead(PIN_R) == HIGH);

  if (!hasPrintedFlags[FLAG_L] && !lHigh) {
    printToken('L');
    hasPrintedFlags[FLAG_L] = true;
    hasPrintedFlags[FLAG_NONE] = false;
  } else if (!hasPrintedFlags[FLAG_M] && !mHigh) {
    printToken('M');
    hasPrintedFlags[FLAG_M] = true;
    hasPrintedFlags[FLAG_NONE] = false;
  } else if (!hasPrintedFlags[FLAG_R] && !rHigh) {
    printToken('R');
    hasPrintedFlags[FLAG_R] = true;
    hasPrintedFlags[FLAG_NONE] = false;
  } else if (!hasPrintedFlags[FLAG_NONE] && lHigh && mHigh && rHigh) {
    printToken('-');
    resetFlags();
    hasPrintedFlags[FLAG_NONE] = true;
  }

  if (hasPrintedFlags[FLAG_L] && lHigh) {
    hasPrintedFlags[FLAG_L] = false;
  }
  if (hasPrintedFlags[FLAG_M] && mHigh) {
    hasPrintedFlags[FLAG_M] = false;
  }
  if (hasPrintedFlags[FLAG_R] && rHigh) {
    hasPrintedFlags[FLAG_R] = false;
  }
}

static inline void resetFlags() {
  for (int i = 0; i < 4; i++) {
    hasPrintedFlags[i] = false;
  }
}

static inline void printToken(char token) {
  Serial.println(token);
  //Serial.write('\n');
}
