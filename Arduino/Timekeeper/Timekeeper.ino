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

volatile int pin3State = LOW;
volatile int pin4State = LOW;

void setup() {
  pinMode(INPUT_PIN_2, INPUT_PULLUP); // Should be pullup because otherwise too sensitive (erroneous timestamps appeared otherwise)
  pinMode(INPUT_PIN_3, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), handlePin2Change, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), handlePin3Change, CHANGE);

  Serial.begin(9600);
}
void loop() {
  // delay(1); // Loop is empty because the interrupts handle everything
}
// Stimulus signal
void handlePin2Change() {
  int currentState = digitalRead(INPUT_PIN_2);
  if (currentState != pin3State){
    pin3State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - Stimulus RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - Stimulus FALLING edge detected");
    }
  }
}
// Frame clock from ScanImage
void handlePin3Change() {
  int currentState = digitalRead(INPUT_PIN_3);
  if (currentState != pin4State){
    pin4State = currentState;
    if (currentState == HIGH) {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - Frame Clock RISING edge detected");
    }
    else {
       Serial.print("Timestamp (micros): ");
       Serial.print(micros());
       Serial.println(" - Frame Clock FALLING edge detected");
    }
  }
}