#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward
// Current State of the program
enum State {
  WHO, SETUP, READING, RIGHT_REWARDING, LEFT_REWARDING, RIGHT_OPEN, LEFT_OPEN
};
State currentState = WHO;
String str; // String to hold incoming serial data
// Flags to prevent repeat printing
bool hasPrintedL = false;
bool hasPrintedM = false;
bool hasPrintedR = false;
bool hasPrintedNone = false;
// Valve status variables
bool RightOpen = false;
bool LeftOpen = false;
// Reward Variables
float rightdur = 0.05;  // Length of a right Pulse
float leftdur = 0.05;  // Length of a left Pulse
int Pulse = 4; // How many pulses to give
float BetweenPulse = 0.2; // Time between pulses

void setup() {
  pinMode(PIN_4, INPUT_PULLUP); // set pin 4 as input with internal pullup resistor
  pinMode(PIN_5, INPUT_PULLUP); // set pin 5 as input with internal pullup resistor
  pinMode(PIN_6, INPUT_PULLUP); // set pin 6 as input with internal pullup resistor
  pinMode(PIN_7, OUTPUT); // set pin 7 as output
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  Serial.begin(9600); // start the serial at 9600 baud
}

void loop() {  
  if (currentState == READING) {
    if (Serial.available()) { // Switch between SETUP and REWARDING states
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("R")) {
        currentState = RIGHT_REWARDING; // switch to REWARDING state
      }
      if (str.equals("RO")) {
        currentState = RIGHT_OPEN;
      }
      if (str.equals("L")) {
        currentState = LEFT_REWARDING; // switch to REWARDING state
      }
      if (str.equals("LO")) {
        currentState = LEFT_OPEN;
      }
      else if (str.equals("S")) {
        currentState = SETUP; // switch to Setup
      }
      else if (str.equals("W")) {
        currentState = WHO; // switch to Identifying state
      }
    } 
    else {
      if (digitalRead(PIN_4) == LOW && !hasPrintedL) {
        Serial.println('L');
        hasPrintedL = true;
        hasPrintedM = false;
        hasPrintedR = false;
        hasPrintedNone = false;
      }
      else if (digitalRead(PIN_5) == LOW && !hasPrintedM) {
        Serial.println('M');
        hasPrintedM = true;
        hasPrintedL = false;
        hasPrintedR = false;
        hasPrintedNone = false;
      }
      else if (digitalRead(PIN_6) == LOW && !hasPrintedR) {
        Serial.println('R');
        hasPrintedR = true;
        hasPrintedL = false;
        hasPrintedM = false;
        hasPrintedNone = false;
      }
      else {
        if((digitalRead(PIN_4) == HIGH & digitalRead(PIN_5) == HIGH & digitalRead(PIN_6) == HIGH) && !hasPrintedNone) {
          Serial.println('-');
          hasPrintedL = false;
          hasPrintedM = false;
          hasPrintedR = false;
          hasPrintedNone = true;
        }
      }
      delay(10); // delay reduces "signal bouncing," could add debouncing circuit with resistors and capacitors or just keep the delay
    }
  }
  else if (currentState == RIGHT_REWARDING) {
    // Serial.print("right drop: "); Serial.println(rightdur);
    for (int i = 0; i < Pulse; i++) {
      digitalWrite(PIN_8, HIGH);   // Open valve
      delay(rightdur*1000);  // Wait for specified duration
      digitalWrite(PIN_8, LOW);    // Close valve
      if (i < Pulse - 1) {
        delay(BetweenPulse*1000);
      }
    }
    currentState = READING; // Go back to initial state
  }
  else if (currentState == RIGHT_OPEN) {
    if (RightOpen == false) {
      digitalWrite(PIN_8, HIGH);
      RightOpen = true;
    }
    else {
      digitalWrite(PIN_8, LOW);
      RightOpen = false;
    }
    currentState = READING;
  }
  else if (currentState == LEFT_REWARDING) {
    // Serial.print("left drop: "); Serial.println(leftdur);
    for (int i = 0; i < Pulse; i++) {
      digitalWrite(PIN_7, HIGH);   // Open valve
      delay(rightdur*1000);  // Wait for specified duration
      digitalWrite(PIN_7, LOW);    // Close valve
      if (i < Pulse - 1) {
        delay(BetweenPulse*1000);
      }
    }
    currentState = READING; // Go back to initial state
  }
  else if (currentState == LEFT_OPEN) {
    if (LeftOpen == false) {
      digitalWrite(PIN_7, HIGH);
      LeftOpen = true;
    }
    else {
      digitalWrite(PIN_7, LOW);
      LeftOpen = false;
    }
    currentState = READING;
  }
  else if (currentState == SETUP) {
    // Serial.println("Right Reward duration (seconds)");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    rightdur = str.toFloat(); // convert this string to an integer
    // Serial.println("Left Reward duration (seconds)");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    leftdur = str.toFloat(); // convert this string to an integer
    // Serial.println("Number of pulses");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    Pulse = str.toInt(); // convert this string to an integer
    // Serial.println("Time between pulses (seconds)");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    BetweenPulse = str.toFloat(); // convert this string to an integer

    Serial.println("Setup complete");
    currentState = READING;
  }
  else if (currentState == WHO) {
    // Introduce
    Serial.println("NosePoke");
    Serial.println("PIN_4 (Left) is connected to digital pin 4");
    Serial.println("PIN_5 (Middle) is connected to digital pin 5");
    Serial.println("PIN_6 (Right) is connected to digital pin 6");
    Serial.println("PIN_7 (Left Reward) is connected to digital pin 7");
    Serial.println("PIN_8 (Right Reward) is connected to digital pin 8");
    Serial.print("Right reward: ");
    Serial.print(rightdur);
    Serial.println(" sec");
    Serial.print("Left reward: ");
    Serial.print(leftdur);
    Serial.println(" sec");
    Serial.print(Pulse);
    Serial.println(" pulses");

    currentState = READING;
  }
}