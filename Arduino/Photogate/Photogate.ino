#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward
#define PIN_9 9   // Start Acquisition (ScanImage)
#define PIN_10 10 // Next File (ScanImage)
#define PIN_11 11 // End Acquisition (ScanImage)
#define PIN_12 12 // Timestamp (Other Arduino)

enum State {
  WAITING, READING, REWARDING
};

State currentState = WAITING;
String str;

void setup() {
  pinMode(PIN_4, INPUT_PULLUP); // set pin 4 as input with internal pullup resistor
  pinMode(PIN_5, INPUT_PULLUP); // set pin 5 as input with internal pullup resistor
  pinMode(PIN_6, INPUT_PULLUP); // set pin 6 as input with internal pullup resistor
  pinMode(PIN_7, OUTPUT); // set pin 7 as output
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  pinMode(PIN_9, OUTPUT); // set pin 9 as output
  pinMode(PIN_10, OUTPUT); // set pin 10 as output
  pinMode(PIN_11, OUTPUT); // set pin 11 as output
  pinMode(PIN_12, OUTPUT); // set pin 12 as output
  Serial.begin(9600); // start the serial at 9600 baud
}

void loop() {  
  if (currentState == WAITING) {
    if (Serial.available()) { // check if data is available to read
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("Read")) {
        currentState = READING; // switch to READING state
      }
      else if (str.equals("Reward")) {
        currentState = REWARDING; // switch to REWARDING state
      }
    }
  } 
  else if (currentState == READING) {
    if (Serial.available()) { // check if data is available to read
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("Reward")) {
        currentState = REWARDING; // switch to REWARDING state
      }
      else if (str.equals("Wait")) {
        currentState = WAITING; // switch to REWARDING state
      }
    } 
    else {
      if (digitalRead(PIN_4) == LOW) {
        Serial.println('L');
      }
      else if (digitalRead(PIN_5) == LOW) {
        Serial.println('M');
      }
      else if (digitalRead(PIN_6) == LOW) {
        Serial.println('R');
      }
      else {
        Serial.println('-');
      }
      delay(10); // delay for readability of the serial output.
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
        
    // Serial.println("Pulse");   // print "Pulse" message
    // while(!Serial.available()); // Wait until data is available
    // str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    // pulseNumber = str.toInt(); // convert the string to an integer

    // while(digitalRead(PIN_4) == HIGH); // Keep waiting until the photogate for the reward valve reads LOW (mouse is standing there)
    Serial.println("reward drop");
    digitalWrite(Valve, HIGH);   // Turn the LED on
    delay(durationNumber*1000);  // Wait for specified duration
    digitalWrite(Valve, LOW);    // Turn the LED off

    // Go back to initial state or another state as needed. For example:
    currentState = READING;
    // Serial.println("end reward");
  }
  }