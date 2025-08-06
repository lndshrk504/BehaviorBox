// WBS 8-6-2025

#include <Arduino.h>

#define PIN_4 4
#define PIN_5 5
#define PIN_6 6
#define PIN_7 7
#define PIN_8 8

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
char str;
float rightdur = 0.04; // Default duration
float leftdur = 0.04;  // Default duration
bool hasPrintedFlags[4] = {false, false, false, false};
bool RightOpen = false;
bool LeftOpen = false;

void customDelay(float duration) {
  if (duration < 0.001) {
    delayMicroseconds(duration * 1e6); // Convert seconds to microseconds
  } else {
    delay(duration * 1000); // Convert seconds to milliseconds
  }
}

void toggleReward(int pin, float duration) {
  digitalWrite(pin, HIGH);   // Open valve
  customDelay(duration);     // Custom delay
  digitalWrite(pin, LOW);    // Close valve
  resetFlags();
  currentState = READING; // Return to initial state
}

void toggleValve(int pin, bool &valveStatus) {
  if (!valveStatus) {
    digitalWrite(pin, HIGH); // Open valve
  } else {
    digitalWrite(pin, LOW);  // Close valve
  }
  valveStatus = !valveStatus;
  resetFlags();
  currentState = READING; // Return to initial state
}

float getDurationFromSerial(const char* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print("Setting duration to: "); Serial.println(DURinp, 4);
  return DURinp;
}

void displayWelcomeMessage() {
}

void displayID() {
  Serial.print("Box ID: "); Serial.println("Nose1");
}

void checkAndPrintPhotogateState() {
  if (!hasPrintedFlags[0] && digitalRead(PIN_4) == LOW) {
    Serial.println('L');
    //setFlags(0);
    hasPrintedFlags[0] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[1] && digitalRead(PIN_5) == LOW) {
    Serial.println('M');
    //setFlags(1);
    hasPrintedFlags[1] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[2] && digitalRead(PIN_6) == LOW) {
    Serial.println('R');
    //setFlags(2);
    hasPrintedFlags[2] = true;
    hasPrintedFlags[3] = false;
  } else if (!hasPrintedFlags[3] && digitalRead(PIN_4) == HIGH && digitalRead(PIN_5) == HIGH && digitalRead(PIN_6) == HIGH) {
    Serial.println('-');
    resetFlags(); // Uncomment to only reset flags when None are selected (Multiple mice in one box)
    setFlags(3);
  } else if (hasPrintedFlags[0] && digitalRead(PIN_4) == HIGH) {
    hasPrintedFlags[0] = false;
  } else if (hasPrintedFlags[1] && digitalRead(PIN_5) == HIGH) {
    hasPrintedFlags[1] = false;
  } else if (hasPrintedFlags[2] && digitalRead(PIN_6) == HIGH) {
    hasPrintedFlags[2] = false;
  }
}

void resetFlags() {
  for (int i = 0; i < 4; i++) {
    hasPrintedFlags[i] = false;
  }
}

void setFlags(int index) {
  resetFlags(); // Uncomment to reset flags every time a new port is selected (One mouse per box)
  hasPrintedFlags[index] = true;
}

void handleStateChange() {
  switch (currentState) {
    case READING:
      checkAndPrintPhotogateState();
      break;
    case RIGHT_REWARDING:
      toggleReward(PIN_8, rightdur);
      Serial.println("Right reward dispensed");
      break;
    case LEFT_REWARDING:
      toggleReward(PIN_7, leftdur);
      Serial.println("Left reward dispensed");
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_8, RightOpen);
      Serial.print("Right Valve: ");
      Serial.println(RightOpen ? "Open" : "Closed");
      break;
    case LEFT_OPEN:
      toggleValve(PIN_7, LeftOpen);
      Serial.print("Left Valve: ");
      Serial.println(LeftOpen ? "Open" : "Closed");
      break;
    case LEFT_SETUP:
      leftdur = getDurationFromSerial("Enter new duration for left reward:");
      Serial.print("Left reward duration set to: "); Serial.println(leftdur);
      currentState = READING;
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial("Enter new duration for right reward:");
      Serial.print("Right reward duration set to: "); Serial.println(rightdur);
      currentState = READING;
      break;
    case WHO:
      displayID();
      currentState = READING;
      break;
    case SETUP:
      displayWelcomeMessage();
      currentState = READING;
      break;
    default: break;
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
  pinMode(PIN_4, INPUT_PULLUP);
  pinMode(PIN_5, INPUT_PULLUP);
  pinMode(PIN_6, INPUT_PULLUP);
  pinMode(PIN_7, OUTPUT);
  pinMode(PIN_8, OUTPUT);
  Serial.println();
  Serial.println("Welcome to BehaviorBox - NosePoke");
  Serial.println();
  Serial.println("Readout begins below...");
}

void loop() {
  handleStateChange();
  if (Serial.available() > 0) {
    str = Serial.read();
    switch (str) {
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
