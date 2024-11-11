// WBS 11 - 5 - 2024
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
  Serial.println("Program for monitoring rising edges on two input pins.");
  Serial.println("Connect stimulus signal to INPUT_PIN_2 (Pin 2).");
  Serial.println("Connect frame clock signal to INPUT_PIN_3 (Pin 3).");
  Serial.println("System uses interrupt handlers to detect rising edges.");
  Serial.println("On rising edge, current timestamp is sent over serial.");
  Serial.println("Timestamps use micros() for high precision.");
  Serial.println("Overflows accounted for, resetting every 70 minutes.");
  pinMode(INPUT_PIN_2, INPUT_PULLUP); // Should be pullup because otherwise too sensitive (erroneous timestamps appear)
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), StimulusOn, RISING);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), RecordFrame, RISING);
}

void loop() {
  // Loop is empty because the interrupts handle everything
}

// Stimulus signal, BehaviorBoxSerial.m sets this Pin HIGH 0.5 sec before stimulus appears
// Record this timestamp and reset  reference time so frame timestamps are relative to Stimulus
void StimulusOn() {
    unsigned long currentMicros = micros();
  
  if (currentMicros < lastMicros) {
    overflows++;
  }

  unsigned long adjustedMicros = currentMicros + (overflows * 4294967296UL);
  
  startTime = adjustedMicros;

  // Convert microseconds to total seconds
  unsigned long totalSeconds = adjustedMicros / 1000000;

  // Calculate hours, minutes, and seconds
  unsigned int seconds = totalSeconds % 60;
  unsigned int totalMinutes = totalSeconds / 60;
  unsigned int minutes = totalMinutes % 60;
  unsigned int hours = totalMinutes / 60;

  // Print formatted time
  Serial.print(hours);
  Serial.print(" hours, ");
  Serial.print(minutes);
  Serial.print(" minutes, ");
  Serial.print(seconds);
  Serial.println(" seconds of Total Run Time");
  Serial.println("Stimulus RISING");
  
  Serial.println("Frame clock reset to zero");

  lastMicros = currentMicros;
}

// Frame clock from ScanImage, goes HIGH when the Y-Galvo flys back to start a new frame
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