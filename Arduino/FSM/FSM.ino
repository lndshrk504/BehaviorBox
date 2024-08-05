#include <Encoder.h>

// Assuming Encoder has pins 2 and 3
Encoder myEnc(2, 3); 

enum State {
  READ_ENCODER,
  PULSE_LED
};

// W, R characters in ASCII
const int triggerToReadEncoder = 87; 
const int triggerToPulseLED = 82;

// Starting state
State state = READ_ENCODER;

void setup() {
  Serial.begin(9600);
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    char signal = Serial.read();

    if (signal == triggerToReadEncoder) {
      state = READ_ENCODER;
    } else if (signal == triggerToPulseLED) {
      state = PULSE_LED;
    }
  }

  switch (state) {
    case READ_ENCODER: {
      long position = myEnc.read();
      Serial.println(position);
      break;
    }
    case PULSE_LED: {
      digitalWrite(LED_BUILTIN, HIGH);
      delay(1000);
      digitalWrite(LED_BUILTIN, LOW);
      delay(1000);
      break;
    }
  }
}
