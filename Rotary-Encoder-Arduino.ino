#define PIN_A 2
#define PIN_B 3

volatile int encoderPosition = 0;
volatile bool A_set = false;
volatile bool B_set = false;

const int encoderPulsePerRevolution = 1024; // Updated as per your encoder's specification.

void setup() {
  pinMode(PIN_A, INPUT_PULLUP); 
  pinMode(PIN_B, INPUT_PULLUP); 

  attachInterrupt(digitalPinToInterrupt(PIN_A), doEncoderA, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_B), doEncoderB, CHANGE);
    
  Serial.begin (9600);
}

void loop(){
  float angle = (float)encoderPosition / encoderPulsePerRevolution * 360;
  //Do stuff here
  Serial.println(angle);
}

void doEncoderA() {
  if ( digitalRead(PIN_A) != A_set ) {
    A_set = !A_set;
    if ( A_set && !B_set ) {
      encoderPosition++;
    }
  }
}

void doEncoderB() {
  if ( digitalRead(PIN_B) != B_set ) {
    B_set = !B_set;
    if( B_set && !A_set ) {
      encoderPosition--;
    }
  }
}
