#define ENCODER_OPTIMIZE_INTERRUPTS // makes it super fast: https://www.pjrc.com/teensy/td_libs_Encoder.html
#include <Encoder.h>
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (SI)
#define PIN_10 10 // Next File (SI)
#define PIN_11 11 // End Acquisition (SI)
#define PIN_12 12 // Timestamp (Time)

// This code is a state machine that: reads from the encoder, gives rewards, or toggles the timestamp pin
enum State {
  SETUP, READING, RIGHTREWARDING, TIMESTAMPING
};

// The pin numbers must be defined here, since the Encoder library uses these to specify which pins to use
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno

State currentState = READING; // Default state is Reading
String str;
int prevDegrees = -1; // Starting value for rotor
float rightdur = 0.1;  // Length of a Reward Pulse
bool TimeFlag = false;

void setup() {
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  pinMode(PIN_9, OUTPUT); // set pin 9 as output
  pinMode(PIN_10, OUTPUT); // set pin 10 as output
  pinMode(PIN_11, OUTPUT); // set pin 11 as output
  pinMode(PIN_12, OUTPUT); // set pin 12 as output
  Serial.begin(9600); // start the serial at 9600 baud
}

void loop() {  
  if (currentState == READING) {
    if (Serial.available()) { // Switch between states
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("Reward")) {
        currentState = RIGHTREWARDING; // switch to RIGHTREWARDING state
      }
      else if (str.equals("Time")) {
        currentState = TIMESTAMPING; // switch to RIGHTREWARDING state
      }
      else if (str.equals("Setup")) {
        currentState = SETUP; // switch to RIGHTREWARDING state
      }
      else if (str.equals("Reset")) {
        myEnc.write(0); // reset the encoder position
        prevDegrees = 0;
        Serial.println(0);
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
    delay(1); // Delay for signal de-bouncing (not as necessary for rotary encoder)
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
  else if (currentState == RIGHTREWARDING) {
    String str;
    String side;
    Serial.println(rightdur);
    digitalWrite(PIN_8, HIGH);   // Turn the LED on
    delay(rightdur*1000);  // Wait for rightduration
    digitalWrite(PIN_8, LOW);    // Turn the LED off
    Serial.println("Done");
    myEnc.write(0); // reset the encoder position
    prevDegrees = 0;
    Serial.println(0);
    currentState = READING; // Go back to initial state or another state as needed. For example:
  }
  else if (currentState == SETUP) {
    Serial.println("Reward (seconds): ");
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    rightdur = str.toFloat(); // convert this string to an integer
    Serial.println("Setup complete");
    currentState = READING;
  }
}