#define ENCODER_OPTIMIZE_INTERRUPTS // makes it faster: https://www.pjrc.com/teensy/td_libs_Encoder.html
#include <Encoder.h>
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (SI)
#define PIN_10 10 // Next File (SI)
#define PIN_11 11 // End Acquisition (SI)
#define PIN_12 12 // Timestamp (Time)

enum State { // Current State of the program
  WHO, SETUP, READING, RIGHT_REWARDING, RIGHT_OPEN, TIMESTAMPING
};
State currentState = WHO;
String str; // String to hold incoming serial data
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno
int prevDegrees = -1; // Starting value for rotor
bool RightOpen = false; // Valve status
float rightdur = 0.05;  // Length of a right Pulse
int Pulse = 1; // How many pulses to give
float BetweenPulse = 0.2; // Time between pulses
bool StartAcqFlag = false; // ScanImage Variables
bool NextFileFlag = false;
bool EndAcqFlag = false;
bool TimeFlag = false;

void setup() {
  Serial.begin(9600); // start the serial at 9600 baud
  while (!Serial) { // wait for serial port to connect. Needed for native USB port only
    ;
  }
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  pinMode(PIN_9, OUTPUT); // set pin 9 as output
  pinMode(PIN_10, OUTPUT); // set pin 10 as output
  pinMode(PIN_11, OUTPUT); // set pin 11 as output
  pinMode(PIN_12, OUTPUT); // set pin 12 as output
}

void loop() {  
  if (currentState == READING) {
    if (Serial.available()) { // Switch between states
      // str = Serial.readStringUntil('\n'); // read the incoming string
      str = Serial.read(); // try this, don't wait for newline
      if (str.equals("R")) {
        currentState = RIGHT_REWARDING; // switch to RIGHT_REWARDING state
      }
      if (str.equals("RO")) {
        currentState = RIGHT_OPEN;
      }
      else if (str.equals("T")) {
        currentState = TIMESTAMPING; // switch to RIGHT_REWARDING state
      }
      else if (str.equals("S")) {
        currentState = SETUP; // switch to RIGHT_REWARDING state
      }
      else if (str.equals("W")) {
        currentState = WHO; // switch to Who
    }
      else if (str.equals("Reset")) {
        myEnc.write(0); // reset the encoder position
        prevDegrees = 0;
        Serial.println(0);
      }
      else if (str.equals("Who")) {
        currentState = WHO; // switch to Identifying state
      }
    } 
    else {
      int newPosition = myEnc.read();
      if (newPosition != 0) {
      // Divide by 4 because of "4X reporting" phenomenon (quadrature) of encoder
      int degrees = newPosition / (4); // int and not double bc 1024 ppr is enough resolution without decimals
      if (degrees!= prevDegrees) {
        Serial.println(degrees);
        prevDegrees = degrees;
      }
    }
    // delay(1); // Delay for signal de-bouncing (not as necessary for rotary encoder)
    }
  }
  else if (currentState == TIMESTAMPING) {
    if (TimeFlag) {
      digitalWrite(PIN_12, HIGH); // If current state is HIGH, set it to LOW
        Serial.println("Pin is high");
        TimeFlag = false;
    } else {
      digitalWrite(PIN_12, LOW); // If current state is LOW, set it to HIGH
        Serial.println("Pin is low");
        TimeFlag = true;
    }
    currentState = READING; // switch back to READING state
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
    myEnc.write(0); // reset the encoder position
    prevDegrees = 0;
    Serial.println(0);
    currentState = READING; // Go back to initial state or another state as needed. For example:
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
  else if (currentState == SETUP) {
    Serial.println("Reward (seconds): ");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    rightdur = str.toFloat(); // convert this string to an integer
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
    Serial.println("Wheel");
    Serial.println("The encoder 'myEnc' is connected to the interrupt pins 2 and 3");
    Serial.println("PIN_8 (Reward) is connected to digital pin 8");
    Serial.println("PIN_9 (Start Acquisition (SI)) is connected to digital pin 9");
    Serial.println("PIN_10 (Next File (SI)) is connected to digital pin 10");
    Serial.println("PIN_11 (End Acquisition (SI)) is connected to digital pin 11");
    Serial.println("PIN_12 (Timestamp (Time)) is connected to digital pin 12");
    Serial.print("Right reward: ");
    Serial.print(rightdur);
    Serial.println(" sec");
    Serial.print(Pulse);
    Serial.println(" pulses");

    currentState = READING;
  }
}
// Fcn to read serial input from MATLAB
String readCRLF() {
  String returnString;
  while (Serial.available()) {
    char inChar = Serial.read();
    if (inChar == '\n') {
      if (returnString.endsWith("\r")) {
        // It ended with "\r\n", remove the "\r"
        returnString = returnString.substring(0, returnString.length() - 1);
      }
      break; // done reading
    } else {
      returnString += inChar; // append other bytes
    }
  }
  return returnString;
}
