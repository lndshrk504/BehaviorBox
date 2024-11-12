#include <Arduino.h>

#define INPUT_PIN_2 2
#define INPUT_PIN_3 3
#define OVERFLOW_INCREMENT 4294967296UL

volatile unsigned long startTime = 0;
volatile unsigned long lastMicros = 0;
volatile unsigned long overflows = 0;

volatile bool stimulusEvent = false;
volatile bool frameEvent = false;
volatile unsigned long lastTimestamp = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial); // Only needed for native USB port
  pinMode(INPUT_PIN_2, INPUT_PULLUP);
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), StimulusOn, RISING);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), RecordFrame, RISING);

  Serial.println("Monitoring rising edges on input pins with precise timestamps.");
}

void loop() {
  // Handle stimulus event
  if (stimulusEvent) {
    printFormattedTime(startTime, "Stimulus RISING. Frame clock reset to zero.");
    stimulusEvent = false;
  }

  // Handle frame event
  if (frameEvent) {
    Serial.print(lastTimestamp);
    Serial.println(" (micros) - Frame RISING");
    frameEvent = false;
  }
}

void StimulusOn() {
  unsigned long currentMicros = micros();
  if (currentMicros < lastMicros) {
    overflows++;
  }

  startTime = currentMicros + (overflows * OVERFLOW_INCREMENT);
  lastMicros = currentMicros;
  stimulusEvent = true;  // Set flag to handle in loop
}

void RecordFrame() {
  unsigned long currentMicros = micros();
  if (currentMicros < lastMicros) {
    overflows++;
  }

  unsigned long adjustedMicros = currentMicros + (overflows * OVERFLOW_INCREMENT);
  lastTimestamp = adjustedMicros - startTime;
  lastMicros = currentMicros;
  frameEvent = true;  // Set flag to handle in loop
}

void printFormattedTime(unsigned long adjustedMicros, const char* message) {
  unsigned long totalSeconds = adjustedMicros / 1000000;

  unsigned int hours = totalSeconds / 3600;
  unsigned int minutes = (totalSeconds % 3600) / 60;
  unsigned int seconds = totalSeconds % 60;

  Serial.print(hours);
  Serial.print(" hours, ");
  Serial.print(minutes);
  Serial.print(" minutes, ");
  Serial.print(seconds);
  Serial.print(" seconds - ");
  Serial.println(message);
}
