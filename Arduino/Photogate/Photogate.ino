// WBS 8-29-2024
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
  WHO
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

void toggleValve(int pin, float duration) {
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
  Serial.print("Setting duration to: ");
  Serial.println(DURinp);
  return DURinp;
}

void displayWelcomeMessage() {
  Serial.println();
  Serial.println("Welcome to BehaviorBox - NosePoke");
  Serial.println();
  Serial.println("WIRING:");
  Serial.println("PIN_4 (Left) is connected to digital pin 4");
  Serial.println("PIN_5 (Middle) is connected to digital pin 5");
  Serial.println("PIN_6 (Right) is connected to digital pin 6");
  Serial.println("PIN_7 (Left Reward) is connected to digital pin 7");
  Serial.println("PIN_8 (Right Reward) is connected to digital pin 8");
  Serial.println();
  Serial.println("SETTINGS:");
  Serial.print("Right reward: ");
  Serial.print(rightdur, 4);
  Serial.println(" sec");
  Serial.print("Left reward: ");
  Serial.print(leftdur, 4);
  Serial.println(" sec");
  Serial.println();
  Serial.println("USAGE:");
  Serial.println("The default behavior is to read from the Photogates and output L, M, R or -");
  Serial.println("Please enter one of the following characters to control the state:");
  Serial.println("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING");
  Serial.println("If the letter 'r' is entered, the current state will switch to RIGHT_OPEN");
  Serial.println("If the letter 'L' is entered, the current state will switch to LEFT_REWARDING");
  Serial.println("If the letter 'l' is entered, the current state will switch to LEFT_OPEN");
  Serial.println("If the letter 'S' is entered, the current state will switch to LEFT_SETUP");
  Serial.println("If the letter 's' is entered, the current state will switch to RIGHT_SETUP");
  Serial.println("If the letter 'W' is entered, the current state will switch to WHO, which is an identifying state.");
  Serial.println("Note: The system is case sensitive, uppercase and lowercase letters will trigger different states.");
  Serial.println("Readout begins below...");
  Serial.println();
  Serial.println();
}

void checkAndPrintPhotogateState() {
  if (digitalRead(PIN_4) == LOW && !hasPrintedFlags[0]) {
    Serial.println('L');
    setFlags(0);
  } else if (digitalRead(PIN_5) == LOW && !hasPrintedFlags[1]) {
    Serial.println('M');
    setFlags(1);
  } else if (digitalRead(PIN_6) == LOW && !hasPrintedFlags[2]) {
    Serial.println('R');
    setFlags(2);
  } else if (digitalRead(PIN_4) == HIGH && digitalRead(PIN_5) == HIGH && digitalRead(PIN_6) == HIGH && !hasPrintedFlags[3]) {
    Serial.println('-');
    setFlags(3);
  }
}

void resetFlags() {
  for (int i = 0; i < 4; i++) {
    hasPrintedFlags[i] = false;
  }
}

void setFlags(int index) {
  resetFlags();
  hasPrintedFlags[index] = true;
}

void handleStateChange() {
  switch (currentState) {
    case RIGHT_REWARDING:
      toggleValve(PIN_8, rightdur);
      Serial.println("Right Reward Dispensed");
      break;
    case LEFT_REWARDING:
      toggleValve(PIN_7, leftdur);
      Serial.println("Left Reward Dispensed");
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
      displayWelcomeMessage();
      currentState = READING;
      break;
    case READING:
    default:
      checkAndPrintPhotogateState();
      break;
  }
}

void setup() {
  Serial.begin(9600);
  pinMode(PIN_4, INPUT_PULLUP);
  pinMode(PIN_5, INPUT_PULLUP);
  pinMode(PIN_6, INPUT_PULLUP);
  pinMode(PIN_7, OUTPUT);
  pinMode(PIN_8, OUTPUT);
  displayWelcomeMessage();
}

void loop() {
  if (Serial.available() > 0) {
    str = Serial.read();
    switch (str) {
      case 'R': currentState = RIGHT_REWARDING; break;
      case 'L': currentState = LEFT_REWARDING; break;
      case 'r': currentState = RIGHT_OPEN; break;
      case 'l': currentState = LEFT_OPEN; break;
      case 'S': currentState = LEFT_SETUP; break;
      case 's': currentState = RIGHT_SETUP; break;
      case 'W': currentState = WHO; break;
      default: break;
    }
  }
  handleStateChange();
}