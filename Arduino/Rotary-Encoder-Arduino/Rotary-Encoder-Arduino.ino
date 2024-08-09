#define ENCODER_OPTIMIZE_INTERRUPTS // makes it super fast: https://www.pjrc.com/teensy/td_libs_Encoder.html
#include <Encoder.h>
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (ScanImage)
#define PIN_10 10 // Next File (ScanImage)
#define PIN_11 11 // End Acquisition (ScanImage)
#define PIN_12 12 // Timestamp (Other Arduino)

// This code is a finite state machine that: reads from the encoder, gives rewards, or toggles the timestamp pin
enum State {
  SETUP, READING, REWARDING, TIMESTAMPING
};

// The pin numbers must be defined here, since the Encoder library uses these to specify which pins to use
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno

State currentState = READING; // Default state is Reading
String str;
int prevDegrees = -1; // Starting value for rotor
unsigned int dur;  // Length of a Reward Pulse

void setup() {
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  pinMode(PIN_9, OUTPUT); // set pin 9 as output
  pinMode(PIN_10, OUTPUT); // set pin 10 as output
  pinMode(PIN_11, OUTPUT); // set pin 11 as output
  pinMode(PIN_12, OUTPUT); // set pin 12 as output
  Serial.begin(9600); // start the serial at 9600 baud
}

void loop() {  
  if (currentState == TIMESTAMPING) {
    if (Serial.available()) { // check if data is available to read
      // Toggle the timestamp pin
      currentState = READING; // switch back to READING state
    }
  } 
  else if (currentState == READING) {
    if (Serial.available()) { // Switch between states
      String str = Serial.readStringUntil('\n'); // read the incoming string
      if (str.equals("Reward")) {
        currentState = REWARDING; // switch to REWARDING state
      }
      else if (str.equals("Time")) {
        currentState = TIMESTAMPING; // switch to REWARDING state
      }
      else if (str.equals("Setup")) {
        currentState = SETUP; // switch to REWARDING state
      }
      else if (str.equals("Reset")) {
        myEnc.write(0); // reset the encoder position
        Serial.println(0);
      }
    } 
    else {
      int newPosition = myEnc.read();
      if (newPosition != 0) {
      // Divide by 4 because of "4X reporting" phenomenon from the quadrature of the encoder
      int degrees = newPosition / (4); // int and not double bc 1024 ppr is enough resolution without decimals
      if (degrees!= prevDegrees) {
        Serial.println(degrees);
        prevDegrees = degrees;
      }
    }
    delay(10); // Delay for signal de-bouncing
    }
  } 
  else if (currentState == REWARDING) {
    String str;
    String side;

    // while(digitalRead(PIN_4) == HIGH); // Keep waiting until the photogate for the reward valve reads LOW (mouse is standing there)
    // Serial.println("reward drop");
    digitalWrite(PIN_8, HIGH);   // Turn the LED on
    delay(dur*1000);  // Wait for specified duration
    digitalWrite(PIN_8, LOW);    // Turn the LED off
    myEnc.write(0); // reset the encoder position
    currentState = READING; // Go back to initial state or another state as needed. For example:
    // Serial.println("end reward");
  }
  else if (currentState == SETUP) {
    Serial.println('Reward duration MICROseconds');
    while(!Serial.available()); // Wait until data is available
    str = Serial.readStringUntil('\n'); // read the incoming string until a newline
    dur = str.toInt(); // convert this string to an integer
    Serial.println('Setup complete');
    currentState = READING;
  }
  }