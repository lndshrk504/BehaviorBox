#define PIN_4 4
#define PIN_5 5
#define PIN_6 6

void setup() {
  pinMode(PIN_4, INPUT_PULLUP); // set pin 4 as input with internal pullup resistor
  pinMode(PIN_5, INPUT_PULLUP); // set pin 5 as input with internal pullup resistor
  pinMode(PIN_6, OUTPUT); // set pin 6 as output
  
  Serial.begin(9600); // start the serial at 9600 baud
}

void loop() {
  if (digitalRead(PIN_4) == LOW) {
    Serial.println("Pin 4 is LOW");
  }

  if (digitalRead(PIN_5) == LOW) {
    Serial.println("Pin 5 is LOW");
  }

  if (Serial.available() > 0) { // check if data is available to read on the serial port
    Serial.read(); // read incoming serial data
    digitalWrite(PIN_6, HIGH); // set pin 6 to HIGH
  } else {
    digitalWrite(PIN_6, LOW); // set pin 6 to LOW when there's no data being sent on the serial port
  }

  delay(500); // delay for readability of the serial output, you can adjust this delay as needed
}
