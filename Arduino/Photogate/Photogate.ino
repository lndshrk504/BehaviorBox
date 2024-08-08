#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward

enum State {
  SETUP, READING, REWARDING
};

State currentState = READING;
bool hasPrintedL = false; // Flags to prevent printing the same message twice
bool hasPrintedM = false;
bool hasPrintedR = false;
bool hasPrintedNone = false;
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
    if (Serial.available()) { // check if data is available to read
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("Reward")) {
        currentState = REWARDING; // switch to REWARDING state
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
  else if (currentState == REWARDING) {
    int pulseNumber, durationNumber; // Declare the variables outside the if-else
    String str;
    String side;

    Serial.println("Side");   // print "Side" message
    while(!Serial.available()); // Wait until data is available
    side = Serial.readStringUntil('\n'); // read the incoming string until a newline
    int Valve = (side == 'L') ? PIN_7 : PIN_8;
    int Gate  = (side == 'L') ? PIN_4 : PIN_6; // Determine which LED and Gate to use

    Serial.println("Duration"); // print "Duration" message
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    durationNumber = str.toInt(); // convert this string to an integer

    Serial.println("reward drop");
    digitalWrite(Valve, HIGH);   // Turn the LED on
    delay(durationNumber*1000);  // Wait for specified duration
    digitalWrite(Valve, LOW);    // Turn the LED off

    // Go back to initial state or another state as needed. For example:
    currentState = READING;
    // Serial.println("end reward");
  }
  else if (currentState == SETUP)
  }