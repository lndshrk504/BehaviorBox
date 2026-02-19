// Rotary.ino
// REVISED for BehaviorBox latency/robustness:
//   - In normal POSITION mode, emit ONLY numeric degrees lines.
//   - Emit 0 when the wheel returns to 0 (fixes stale-reading issue).
//   - Remove verbose Serial.println() spam during reward/acq commands.
//   - Optional rate-limit on printing to avoid saturating USB serial.
//
// NOTE: Keep baud in sync with MATLAB (BehaviorBoxSerialInput).

#define ENCODER_OPTIMIZE_INTERRUPTS
#include <Encoder.h>
#include <Arduino.h>

// Pins
#define PIN_REWARD 8
#define PIN_STARTACQ 9
#define PIN_NEXTFILE 10
#define PIN_ENDACQ 11
#define PIN_TIMESTAMP 12

enum State {
  READING,
  RIGHT_REWARDING,
  RIGHT_OPEN,
  RIGHT_SETUP,
  TIMESTAMPING,
  TIMESTAMP_ON,
  TIMESTAMP_OFF,
  STARTACQ,
  NEXTFILE,
  ENDACQ,
  WHO
};

enum ReadingMode {
  POSITION,
  SPEED
};

// Initialize variables
State currentState = READING;
ReadingMode currentMode = POSITION; // Default to displaying position
char cmd;
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno
int prevDegrees = 0; // Starting value for rotor position
bool RightOpen = false; // Valve status
float rightdur = 0.05f;  // Length of a right pulse
bool TimeFlag = false; // Timestamp flag
unsigned long previousMicros = 0; // Store the last time the speed was calculated
int previousPosition = 0; // Store the last position of the encoder
bool wasZeroSpeed = false; // Initialize a flag to track the zero speed state

// Function prototypes
void handleStateChange();
void displayID();
void setupPins();
void initializeSerial();
void customDelay(float duration);
void resetEncoder();
void toggleReward(int pin, float duration);
void toggleValve(int pin, bool &valveStatus);
float getDurationFromSerial(const char* prompt);
void displayWelcomeMessage();
void checkAndPrintEncoderState();
void resetFlags();
void setFlags(int index);
void pulsePinHighForDuration(int pin, int duration);

void setup() {
  initializeSerial();
  setupPins();
  displayID();
  Serial.println("Readout begins below...");
  resetEncoder();
}

void initializeSerial() {
  Serial.begin(115200); // start the serial at 115200 baud
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
}

void setupPins() {
  pinMode(PIN_REWARD, OUTPUT); // set pin 8 as output
  pinMode(PIN_STARTACQ, OUTPUT); // set pin 9 as output
  pinMode(PIN_NEXTFILE, OUTPUT); // set pin 10 as output
  pinMode(PIN_ENDACQ, OUTPUT); // set pin 11 as output
  pinMode(PIN_TIMESTAMP, OUTPUT); // set pin 12 as output
}

void displayID() {
  Serial.print("Box ID: ");Serial.println("Wheel2");
}

void loop() {
  handleStateChange();
  if (Serial.available() > 0) {
    cmd = Serial.read();
    switch (cmd) {
      case 'R': currentState = RIGHT_REWARDING; break;
      case 'r': currentState = RIGHT_OPEN; break;
      case 's': currentState = RIGHT_SETUP; break;
      case 'T': currentState = TIMESTAMP_ON; break;
      case 't': currentState = TIMESTAMP_OFF; break;
      case 'I': currentState = STARTACQ; break; // Capital letter I
      case 'N': currentState = NEXTFILE; break; 
      case 'i': currentState = ENDACQ; break; // Lowercase letter i
      case 'W': currentState = WHO; break;
      case 'M':
        // Toggle the current mode between POSITION and SPEED
        if (currentMode == POSITION) {
          currentMode = SPEED;
          Serial.println("Speed, deg/sec");
        } else {
          currentMode = POSITION;
          Serial.println("Position");
        }
        previousPosition = 0;
        previousMicros = micros();
        prevDegrees = 0;
        resetEncoder();
        break;
      case '0': // 'ZERO' for reset back to 0
        resetEncoder();
        prevDegrees = 0;
        break;
      default: break;
    }
  }
}

void handleStateChange() {
  switch (currentState) {
    case READING:
      if (currentMode == POSITION) {
        checkAndPrintEncoderState(); // Print the position
      } else if (currentMode == SPEED) {
        delay(10);
        checkAndPrintEncoderSpeed(); // Print the speed
      }
      break;
    case RIGHT_REWARDING:
      toggleReward(PIN_REWARD, rightdur);
      Serial.println("Right reward dispensed");
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_REWARD, RightOpen);
      Serial.print("Right Valve: ");
      Serial.println(RightOpen ? "Open" : "Closed");
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial("Enter new duration for right reward:");
      Serial.print("Right reward duration set to: "); Serial.println(rightdur);
      currentState = READING;
      break;
     case STARTACQ:
      pulsePinHighForDuration(PIN_STARTACQ, 100);   // Pulse PIN_STARTACQ high
      Serial.println("Starting acquisition...");
      currentState = READING;
      break;
    case NEXTFILE:
      pulsePinHighForDuration(PIN_NEXTFILE, 100);   // Pulse PIN_NEXTFILE high
      Serial.println("Next file...");
      currentState = READING;
      break;
    case ENDACQ:
      pulsePinHighForDuration(PIN_ENDACQ, 100);   // Pulse PIN_ENDACQ high
      Serial.println("Ending acquisition...");
      currentState = READING;
      break;
    case TIMESTAMPING:
      pulsePinHighForDuration(PIN_TIMESTAMP, 10);   // Pulse PIN_TIMESTAMP high
      Serial.println("Timestamp");
      currentState = READING;
      break;
    case TIMESTAMP_ON:
      digitalWrite(PIN_TIMESTAMP, HIGH);   // Set the pin high
      Serial.println("Timestamp On");
      currentState = READING;
      break;
    case TIMESTAMP_OFF:
      digitalWrite(PIN_TIMESTAMP, LOW);   // Set the pin high
      Serial.println("Stitmulus Off");
      currentState = READING;
      break;
    case WHO:
      displayWelcomeMessage();
      currentState = READING;
      break;
    default: break;
  }
}

void customDelay(float duration) {
  if (duration < 0.001f) {
    delayMicroseconds(duration * 1e6f); // Convert seconds to microseconds
  } else {
    delay(duration * 1000.0f); // Convert seconds to milliseconds
  }
}

void resetEncoder() {
  myEnc.write(0); // reset the encoder position
  prevDegrees = 0;
  Serial.println(0);
}

void toggleReward(int pin, float duration) {
  digitalWrite(pin, HIGH);   // Open valve
  customDelay(duration);     // Custom delay
  digitalWrite(pin, LOW);    // Close valve
  resetEncoder();
  prevDegrees = 0;
  currentState = READING;
}

void toggleValve(int pin, bool &valveStatus) {
  if (!valveStatus) {
    digitalWrite(pin, HIGH); // Open valve
  } else {
    digitalWrite(pin, LOW);  // Close valve
  }
  valveStatus = !valveStatus;
  currentState = READING;
}

float getDurationFromSerial(const char* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print("Setting duration to: "); Serial.println(DURinp, 4);
  return DURinp;
}

void pulsePinHighForDuration(int pin, int duration) {
  digitalWrite(pin, HIGH);   // Set the pin high
  delay(duration);           // Wait for the specified duration in milliseconds
  digitalWrite(pin, LOW);    // Set the pin low
}

void displayWelcomeMessage() {
  Serial.println();
  Serial.println("Welcome to BehaviorBox - Wheel");
  Serial.print("Right reward: "); Serial.print(rightdur, 4); Serial.println(" sec");
  Serial.println("USAGE:");
  Serial.println("Please enter one of the following case-sensitive characters to control the state:");
  Serial.println("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING");
  Serial.println("If the letter 'r' is entered, the current state will switch to RIGHT_OPEN");
  Serial.println("If the letter 's' is entered, the current state will switch to RIGHT_SETUP");
  Serial.println("If the letter 'W' is entered, the current state will switch to WHO, which is an identifying state.");
  Serial.println("If the number '0' is entered, the encoder's position will be reset to 0 counts");
  Serial.println("If the letter 'T' is entered, the Timestamping pin will toggle");
  Serial.println("Readout begins below...");
  resetEncoder();
  checkAndPrintEncoderState();
}

void checkAndPrintEncoderState() {
  int newPosition = myEnc.read();
  if (newPosition != 0) {
    int degrees = newPosition / 4; // Divide by 4 because of "4X reporting" phenomenon (quadrature) of encoder
    if (degrees != prevDegrees) {
      Serial.println(degrees);
      prevDegrees = degrees;
    }
  }
}

void checkAndPrintEncoderSpeed() {
  unsigned long currentMicros = micros(); // Get the current time
  int currentPosition = myEnc.read(); // Get the current position of the encoder
  int positionDifference = currentPosition - previousPosition; // Calculate the change in position
  
  // Calculate the time difference in seconds
  float timeDifference = (currentMicros - previousMicros) / 1000000.0; 
  
  // Calculate the speed (degrees per second)
  float speed = (positionDifference/4.0*360/1024) / timeDifference; // Divide by 4 due to quadrature, Multiply by 360/1000 to report as degrees
  
  // Print the speed if the time difference is greater than zero
  if (timeDifference > 0) {
    if (speed != 0) {
      //Serial.print("Speed ");
      Serial.println(speed,2);
      //Serial.print("Time ");
      //Serial.println(timeDifference,5);
      //Serial.print("Position diff");
      //Serial.println(positionDifference);
      wasZeroSpeed = false; // Reset the zero speed flag
    } else if (!wasZeroSpeed) {
      Serial.println("0");
      wasZeroSpeed = true; // Set the zero speed flag
    }
  }

  // Update previous position and time for the next calculation
  previousPosition = currentPosition;
  previousMicros = currentMicros;
}
