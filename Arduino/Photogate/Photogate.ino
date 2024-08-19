#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward

enum State {
<<<<<<< HEAD
  SETUP, READING, RIGHT_REWARDING, LEFT_REWARDING, WHO
=======
  WHO, SETUP, READING, RIGHT_REWARDING, LEFT_REWARDING
>>>>>>> a7f0fedcdb926da0a9237d1087786e86763e1bb8
};

State currentState = WHO; // Current State of the program
bool hasPrintedL = false; // Flags to prevent printing the same message twice
bool hasPrintedM = false;
bool hasPrintedR = false;
bool hasPrintedNone = false;
float rightdur = 0.05;  // Length of a right Reward Pulse
float leftdur = 0.05;  // Length of a left Reward Pulse
String str;

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
      if (str.equals("Right")) {
        currentState = RIGHT_REWARDING; // switch to REWARDING state
      }
      if (str.equals("Left")) {
        currentState = LEFT_REWARDING; // switch to REWARDING state
      }
      else if (str.equals("Setup")) {
        currentState = SETUP; // switch to Setup
      }
      else if (str.equals("Who")) {
<<<<<<< HEAD
        currentState = WHO; // switch to Identifying state
      }
=======
        currentState = WHO; // switch to Who
>>>>>>> a7f0fedcdb926da0a9237d1087786e86763e1bb8
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
    // Serial.println("right drop");
    // Serial.println(rightdur);
    digitalWrite(Valve, HIGH);   // Turn the LED on
    delay(rightdur*1000);  // Wait for specified duration
    digitalWrite(Valve, LOW);    // Turn the LED off
    currentState = READING; // Go back to initial state
  }
  else if (currentState == LEFT_REWARDING) {
    // Serial.println("left drop");
    // Serial.println(leftdur);
    digitalWrite(Valve, HIGH);   // Turn the LED on
    delay(leftdur*1000);  // Wait for specified duration
    digitalWrite(Valve, LOW);    // Turn the LED off
    currentState = READING; // Go back to initial state
  }
  else if (currentState == SETUP) {

    // Serial.println("Right Reward duration (seconds)");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    rightdur = str.toFloat(); // convert this string to an integer

    // Serial.println("Left Reward duration (seconds)");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    rightdur = str.toFloat(); // convert this string to an integer

    Serial.println("Setup complete");

    currentState = READING;
  }
  else if (currentState == WHO) {
<<<<<<< HEAD
    Serial.println("NosePoke");
=======
    // Introduce
    Serial.print("NosePoke");
    Serial.print("Right reward duration (seconds)");
    Serial.println(rightdur);
    Serial.print("Left reward duration (seconds)");
    Serial.println(leftdur);

>>>>>>> a7f0fedcdb926da0a9237d1087786e86763e1bb8
    currentState = READING;
  }
}