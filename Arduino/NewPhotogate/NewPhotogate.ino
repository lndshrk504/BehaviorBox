// ChatGPT-4o suggested this refactored and remodelled version which looks pretty
// but it has errors.
// I'll save it but not use it until I reformat it and fix the errors

#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward

enum State { // Current State of the program
  READING,
  RIGHT_REWARDING,
  RIGHT_OPEN,
  LEFT_REWARDING,
  LEFT_OPEN,
  LEFT_SETUP,
  RIGHT_SETUP,
  WHO
};
State currentState = READING;
char str; // String to hold incoming serial data
bool hasPrintedFlags[4] = { false, false, false, false }; // Order: L, M, R, None
bool RightOpen = false; // Valve status variables
bool LeftOpen = false;
// Reward Variables: 
float rightdur = 0.05;  // Length of a right Pulse
float leftdur = 0.05;  // Length of a left Pulse
int Pulse = 4; // How many pulses to give
float BetweenPulse = 0.2; // Time between pulses

void setup() {
  Serial.begin(9600); // start the serial at 9600 baud
  while (!Serial) { // wait for serial port to connect. Needed for native USB port only
    ;
  }
  // Set the serial timeout to 5000 milliseconds (5 seconds)
  Serial.setTimeout(5000);
  pinMode(PIN_4, INPUT_PULLUP); // set pin 4 as input with internal pullup resistor
  pinMode(PIN_5, INPUT_PULLUP); // set pin 5 as input with internal pullup resistor
  pinMode(PIN_6, INPUT_PULLUP); // set pin 6 as input with internal pullup resistor
  pinMode(PIN_7, OUTPUT); // set pin 7 as output
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  currentState = WHO;
}

void loop() {  
  if (currentState == READING) {
    if (Serial.available()) { // Switch between SETUP and REWARDING states
      str = (char)Serial.read(); // try this, don't wait for newline      
      switch (str) {
        case 'R': currentState = RIGHT_REWARDING; break;
        case 'r': currentState = RIGHT_OPEN; break;
        case 'L': currentState = LEFT_REWARDING; break;
        case 'l': currentState = LEFT_OPEN; break;
        case 'S': currentState = LEFT_SETUP; break;
        case 's': currentState = RIGHT_SETUP; break;
        case 'W': currentState = WHO; break;
        default: break; // Handle unknown characters or add logging for unexpected values
      }
    } else {
      checkAndPrintPhotogateState();
      delay(10); // delay reduces "signal bouncing"
    }
  } else {
    handleStateChange();
  }
}

void handleStateChange() {
  switch (currentState) {
    case RIGHT_REWARDING:
      toggleValve(PIN_8, rightdur);
      break;
    case LEFT_REWARDING:
      toggleValve(PIN_7, leftdur);
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_8, -1, RightOpen);
      RightOpen = !RightOpen;
      break;
    case LEFT_OPEN:
      toggleValve(PIN_7, -1, LeftOpen);
      LeftOpen = !LeftOpen;
      break;
    case LEFT_SETUP:
      leftdur = getDurationFromSerial("Please input leftdur");
      currentState = READING;
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial("Please input rightdur");
      currentState = READING;
      break;
    case WHO:
      displayWelcomeMessage();
      currentState = READING;
      break;
    default:
      break;
  }
  resetFlags();
}

void customDelay(float duration) {
  if (duration < 0.001) {
    delayMicroseconds(duration * 1e6); // Convert seconds to microseconds
  } else {
    delay(duration * 1000); // Convert seconds to milliseconds
  }
}

void toggleValve(int pin, float duration, bool &valveStatus = false) {
  if (duration >= 0) {
    digitalWrite(pin, HIGH);   // Open valve
    customDelay(duration);     // Custom delay
    digitalWrite(pin, LOW);    // Close valve
  } else {
    if (!valveStatus) {
      digitalWrite(pin, HIGH); // Open valve
    } else {
      digitalWrite(pin, LOW);  // Close valve
    }
  }
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
  // Introduction and Explanation of program
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
  }
  else if (digitalRead(PIN_5) == LOW && !hasPrintedFlags[1]) {
    Serial.println('M');
    setFlags(1);
  }
  else if (digitalRead(PIN_6) == LOW && !hasPrintedFlags[2]) {
    Serial.println('R');
    setFlags(2);
  }
  else if (digitalRead(PIN_4) == HIGH && digitalRead(PIN_5) == HIGH && digitalRead(PIN_6) == HIGH && !hasPrintedFlags[3]) {
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