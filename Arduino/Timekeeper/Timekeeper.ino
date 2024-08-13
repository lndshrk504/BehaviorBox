// This code uses two interrupt handlers to monitor the state of the two input pins. 
// When a rising edge is detected at either pin, the corresponding interrupt handler 
// function is called to transmit the current timestamp over the serial port. 
// This way, every time either of the input pins changes state from low to high, 
// the exact time of change is immediately reported. 
// Instead of the standard `millis()` function, the `micros()` function is used 
// to obtain the time, providing greater precision.
// micros() will reset every 70 minutes, so consider making a modification for longer sessions
#define INPUT_PIN_2 2 // Stimulus signal (BB Wheel)
#define INPUT_PIN_3 3 // Frame clock signal (SI)
#define INPUT_PIN_4 4 // New File signal (SI)

volatile int pin3State = LOW;
volatile int pin4State = LOW;
volatile int pin5State = LOW; // Added third pin

void setup() {
  pinMode(INPUT_PIN_2, INPUT_PULLUP); // Should be pullup because otherwise too sensitive (erroneous timestamps appeared otherwise)
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  pinMode(INPUT_PIN_4, INPUT_PULLUP); // Setup third pin as input

  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), handlePin2Change, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), handlePin3Change, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_4), handlePin4Change, CHANGE);

  Serial.begin(9600);
}

void loop() {
  delay(1); //You can replace this delay with any other task
}

void handlePin2Change() {
  int currentState = digitalRead(INPUT_PIN_2);
  if (currentState != pin3State){
    pin3State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 2 RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 2 FALLING edge detected");
    }
  }
}

void handlePin3Change() {
  int currentState = digitalRead(INPUT_PIN_3);
  if (currentState != pin4State){
    pin4State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 3 RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 3 FALLING edge detected");
    }
  }
}

void handlePin4Change() {
  int currentState = digitalRead(INPUT_PIN_4);
  if (currentState != pin5State){
    pin5State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 4 RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 4 FALLING edge detected");
    }
  }
}