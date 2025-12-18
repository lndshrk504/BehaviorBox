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
#define INPUT_PIN_4 4 // New signal pin (using PCINT)
#define OVERFLOW_INCREMENT 4294967296UL

volatile unsigned long startTime = 0; // Reference time for resetting
volatile unsigned long lastMicros = 0; // To track previous micros for overflow detection
volatile unsigned long overflows = 0;  // Count overflow occurrences
volatile unsigned long frameCount = 0; // Frame counter
volatile uint8_t lastPin4State = HIGH;  // Track previous state of pin 4

void setup() {
  Serial.begin(115200);
  while (!Serial) { }; // wait for serial port to connect. Needed for native USB port only
  pinMode(INPUT_PIN_2, INPUT_PULLUP); // Should be pullup because otherwise too sensitive (erroneous timestamps appear)
  pinMode(INPUT_PIN_3, INPUT_PULLUP);
  //attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), StimulusOn, RISING);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), RecordStimulus, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), RecordFrame, RISING);

  // Setup Pin Change Interrupt for pin 4
  // Pin 4 is PCINT20 which belongs to PCIE2 group (Port D)
  //cli(); // Disable interrupts during setup
  //PCICR |= (1 << PCIE2);     // Enable PCIE2 (Pin Change Interrupt Enable 2)
  //PCMSK2 |= (1 << PCINT20);  // Enable PCINT20 (pin 4) specifically
  //sei(); // Re-enable interrupts

  // Initialize pin 4 state
  //lastPin4State = digitalRead(INPUT_PIN_4);

  Serial.println("Box ID: Time1");
  Serial.println("Timestamp on rise:");
  Serial.println("Pin 2 Stimulus");
  Serial.println("Pin 3 Frame");
  Serial.println("Pin 4 Next File");
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

  startTime = currentMicros + (overflows * OVERFLOW_INCREMENT);

  // Convert microseconds to total seconds
  unsigned long totalSeconds = startTime / 1000000;

  // Calculate hours, minutes, and seconds
  unsigned int seconds = totalSeconds % 60;
  unsigned int totalMinutes = totalSeconds / 60;
  unsigned int minutes = totalMinutes % 60;
  unsigned int hours = totalMinutes / 60;

  // Print formatted time
  //Serial.print(hours);
  //Serial.print(" hours ");
  //Serial.print(minutes);
  //Serial.print(" minutes ");
  //Serial.print(seconds);
  //Serial.print(" seconds of Total Run Time,");
  Serial.println("Stimulus On - Frame clock reset to zero");
  
  lastMicros = currentMicros;
}

void RecordStimulus() {
  unsigned long currentMicros = micros();
  if (currentMicros < lastMicros) {
    overflows++;
  }
  unsigned long adjustedMicros = currentMicros + (overflows * OVERFLOW_INCREMENT);

  if (digitalRead(INPUT_PIN_2) == HIGH) {
    // RISING
    startTime = adjustedMicros;
    // Reset the frame counter when stimulus goes on
    frameCount = 0;  

    // Convert microseconds to total seconds
    unsigned long totalSeconds = startTime / 1000000;
    unsigned int seconds = totalSeconds % 60;
    unsigned int totalMinutes = totalSeconds / 60;
    unsigned int minutes = totalMinutes % 60;
    unsigned int hours = totalMinutes / 60;

    // Print formatted time
    //Serial.print(hours);
    //Serial.print(" hours ");
    //Serial.print(minutes);
    //Serial.print(" minutes ");
    //Serial.print(seconds);
    //Serial.print(" seconds of Total Run Time,");
    Serial.print("S On-Frame reset ");
    Serial.println(adjustedMicros);

  } else {
    // FALLING
    Serial.print("S Off ");
    Serial.println(adjustedMicros);
  }

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
  
  // 3) Increment and print frame counter
  frameCount++;
  Serial.print(timestamp);
  Serial.print(", F ");
  Serial.println(frameCount);  // 3) Print the frame count

  lastMicros = currentMicros;
}

// Pin Change Interrupt Service Routine for Port D (handles pin 4)
//ISR(PCINT2_vect) {
  // Check if pin 4 actually changed (since PCINT2 covers multiple pins)
//  uint8_t currentPin4State = digitalRead(INPUT_PIN_4);
//  if (currentPin4State != lastPin4State) {
    // Pin 4 changed, record the event
//    unsigned long currentMicros = micros();
//    if (currentMicros < lastMicros) {
//      overflows++;
//    }
//    unsigned long adjustedMicros = currentMicros + (overflows * OVERFLOW_INCREMENT);
//    
//   if (currentPin4State == HIGH) {
//      Serial.print("Next File ");
//    }
//    Serial.println(adjustedMicros);
//    
//    lastMicros = currentMicros;
//    lastPin4State = currentPin4State;
//  }
//}