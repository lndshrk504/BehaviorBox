// This code uses two interrupt handlers to monitor the state of the two input pins. 
// When a rising edge is detected at either pin, the corresponding interrupt handler 
// function is called to transmit the current timestamp over the serial port. 
// This way, every time either of the input pins changes state from low to high, 
// the exact time of change is immediately reported. 
// Instead of the standard `millis()` function, the `micros()` function is used 
// to obtain the time, providing greater precision.
// micros() will reset every 70 minutes, so consider making a modification for longer sessions

#include <Arduino.h>

#define INPUT_PIN_2 2 // Stimulus signal (BB Wheel)
#define INPUT_PIN_3 3 // Frame clock signal (SI)


volatile int pin3State = LOW;
volatile int pin4State = LOW;
volatile unsigned long startTime = 0; // Reference time for resetting
volatile unsigned long lastMicros = 0; // To track previous micros for overflow detection
volatile unsigned long overflows = 0;  // Count overflow occurrences

void setup() {
  Serial.begin(115200);
  pinMode(INPUT_PIN_2, INPUT_PULLUP); // Should be pullup because otherwise too sensitive (erroneous timestamps appeared otherwise)
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), StimulusOn, RISING);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), RecordFrame, RISING);
}

void loop() {
  // delay(1); // Loop is empty because the interrupts handle everything
}

// Stimulus signal, BehaviorBoxSerial.m sets this Pin HIGH before stimulus appears
// Record this timestamp and reset the reference time for the frame clocks
void StimulusOn() {
    unsigned long currentMicros = micros();
  
  if (currentMicros < lastMicros) {
    overflows++;
  }

  unsigned long adjustedMicros = currentMicros + (overflows * 4294967296UL);

  Serial.print(adjustedMicros);
  Serial.println(" (micros) - Stimulus RISING");
  
  startTime = adjustedMicros;
  Serial.println("Clock reset to zero.");

  lastMicros = currentMicros;
}

// Frame clock from ScanImage
void RecordFrame() {
  unsigned long currentMicros = micros();
  
  if (currentMicros < lastMicros) {
    overflows++;
  }

  unsigned long adjustedMicros = currentMicros + (overflows * 4294967296UL);
  unsigned long timestamp = adjustedMicros - startTime;
  
  Serial.print(timestamp);
  Serial.println(" (micros) - Frame RISING");

  lastMicros = currentMicros;
}