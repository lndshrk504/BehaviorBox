#include <Encoder.h>
// Declare your Encoder
Encoder myEnc(5, 6);
long oldPosition  = -999;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  Serial.println("Encoder Test:");
}

void loop() {
  // put your main code here, to run repeatedly:
  long newPosition = myEnc.read();
  if (newPosition != oldPosition) {
    oldPosition = newPosition;
    Serial.println(newPosition);
  }
}
