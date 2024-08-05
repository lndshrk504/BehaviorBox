#define ENCODER_OPTIMIZE_INTERRUPTS
#include <Encoder.h>
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (ScanImage)
#define PIN_10 10 // Next File (ScanImage)
#define PIN_11 11 // End Acquisition (ScanImage)
#define PIN_12 12 // Timestamp (Other Arduino)

// This code is a finite state machine that either reads from the encoder or gives rewards
enum State {
  TIMESTAMPING, READING, REWARDING
};

// The pin numbers must be defined here, since the Encoder library uses these to specify which pins to use
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins

State currentState = READING;
String str;
int prevDegrees = -1;

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
      else if (str.equals("Time")) {
        currentState = TIMESTAMPING; // switch to REWARDING state
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
    // delay(1); // delay for readability of the serial output. Unsure how necessary this is so far...
    }
  } 
  else if (currentState == REWARDING) {
    int pulseNumber, durationNumber; // Declare the variables outside the if-else
    String str;
    String side;

    // Serial.println("Side");   // print "Side" message
    // while(!Serial.available()); // Wait until data is available
    // side = Serial.readStringUntil('\n'); // read the incoming string until a newline
    // int Valve = PIN_8; // Determine which Valve to use

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
    digitalWrite(PIN_8, HIGH);   // Turn the LED on
    delay(durationNumber*1000);  // Wait for specified duration
    digitalWrite(PIN_8, LOW);    // Turn the LED off

    // Go back to initial state or another state as needed. For example:
    myEnc.write(0); // reset the encoder position
    currentState = READING;
    // Serial.println("end reward");
  }
  }