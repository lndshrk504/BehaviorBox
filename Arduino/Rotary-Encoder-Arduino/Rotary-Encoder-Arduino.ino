#include <Encoder.h>
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (ScanImage)
#define PIN_10 10 // Next File (ScanImage)
#define PIN_11 11 // End Acquisition (ScanImage)
#define PIN_12 12 // Timestamp (Other Arduino)

// This code is a finite state machine that either reads from the encoder or gives rewards
enum State {
  WAITING, READING, REWARDING
};

// The pin numbers must be defined here, since the Encoder library uses these to specify which pins to use
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins

State currentState = WAITING;
String str;

void setup() {
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
      long newPosition = myEnc.read();
      if (newPosition != 0) {
      // Multiply by the number of pulses per revolution to get the number of degrees turned
      double degrees = newPosition * (360.0 / 1024.0);
      myEnc.write(0); // reset the encoder position
   
      Serial.print("Degrees: "); 
      Serial.println(degrees);
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
    int Valve = (side == 'L') ? PIN_7 : PIN_8; // Determine which Valve to use

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