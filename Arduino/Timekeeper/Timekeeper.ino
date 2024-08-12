#define INPUT_PIN_3 3
#define INPUT_PIN_4 4
#define INPUT_PIN_5 5

volatile int pin3State = LOW;
volatile int pin4State = LOW;
volatile int pin5State = LOW; // Added third pin

void setup() {
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  pinMode(INPUT_PIN_4, INPUT_PULLUP);
  pinMode(INPUT_PIN_5, INPUT_PULLUP); // Setup third pin as input

  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), handlePin3Change, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_4), handlePin4Change, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_5), handlePin5Change, CHANGE);

  Serial.begin(9600);
}

void loop() {
  delay(1000); //You can replace this delay with any other task
}

void handlePin3Change() {
  int currentState = digitalRead(INPUT_PIN_3);
  if (currentState != pin3State){
    pin3State = currentState;
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
  if (currentState != pin4State){
    pin4State = currentState;
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

void handlePin5Change() {
  int currentState = digitalRead(INPUT_PIN_5);
  if (currentState != pin5State){
    pin5State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 5 RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - PIN 5 FALLING edge detected");
    }
  }
}

// This code uses two interrupt handlers to monitor the state of the two input pins. 
// When a rising edge is detected at either pin, the corresponding interrupt handler 
// function is called to transmit the current timestamp over the serial port. 
// This way, every time either of the input pins changes state from low to high, 
// the exact time of change is immediately reported. 
// Instead of the standard `millis()` function, the `micros()` function is used 
// to obtain the time, providing greater precision.