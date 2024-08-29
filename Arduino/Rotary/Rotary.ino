// Define necessary headers and macros
#define ENCODER_OPTIMIZE_INTERRUPTS // makes it faster: https://www.pjrc.com/teensy/td_libs_Encoder.html
#include <Encoder.h>

// Define pin constants
#define PIN_8 8   // Reward
#define PIN_9 9   // Start Acquisition (SI)
#define PIN_10 10 // Next File (SI)
#define PIN_11 11 // End Acquisition (SI)
#define PIN_12 12 // Timestamp (Time)

// Define state for different states
enum State {
  WHO, RIGHT_SETUP, READING, RIGHT_REWARDING, RIGHT_OPEN, TIMESTAMPING
};

// Initialize variables
State currentState = WHO;
char str;
Encoder myEnc(2, 3); // 2 and 3 are interrupt pins for Arduino Uno
int prevDegrees = 0; // Starting value for rotor position
bool RightOpen = false; // Valve status
float rightdur = 0.05;  // Length of a right pulse
bool TimeFlag = false; // Timestamp flag

// Function prototypes
void handleStateChange();
void setupPins();
void initializeSerial();
void customDelay(float duration);
void resetEncoder();
void toggleValve(int pin, float duration);
void toggleValve(int pin, bool &valveStatus);
float getDurationFromSerial(const char* prompt);
void displayWelcomeMessage();
void checkAndPrintEncoderState();
void resetFlags();
void setFlags(int index);

void setup() {
  initializeSerial();
  setupPins();
}

void loop() {
  if (Serial.available() > 0) {
    str = Serial.read();
    switch (str) {
      case 'R': currentState = RIGHT_REWARDING; break;
      case 'T': currentState = TIMESTAMPING; break;
      case 's': currentState = RIGHT_SETUP; break;
      case 'W': currentState = WHO; break;
      case 'O': currentState = RIGHT_OPEN; break;
      case 'r': // 'r' for reset
        resetEncoder();
        prevDegrees = 0;
        Serial.println(0);
        break;
      default: break;
    }
  }
  handleStateChange();
}

void handleStateChange() {
  switch (currentState) {
    case RIGHT_REWARDING:
      toggleValve(PIN_8, rightdur);
      Serial.println("Right reward dispensed");
      currentState = READING;
      break;
    case RIGHT_OPEN:
      toggleValve(PIN_8, RightOpen);
      Serial.print("Right Valve: ");
      Serial.println(RightOpen ? "Open" : "Closed");
      currentState = READING;
      break;
    case TIMESTAMPING:
      digitalW
      rite(PIN_12, TimeFlag ? HIGH : LOW);
      Serial.println(TimeFlag ? "Time Pin is high" : "Time Pin is low");
      TimeFlag = !TimeFlag;
      currentState = READING;
      break;
    case RIGHT_SETUP:
      rightdur = getDurationFromSerial("Enter new duration for right reward:");
      Serial.println("Setup complete");
      currentState = READING;
      break;
    case WHO:
      displayWelcomeMessage();
      currentState = READING;
      break;
    case READING:
    default:
      checkAndPrintEncoderState();
      break;
  }
}

void setupPins() {
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  pinMode(PIN_9, OUTPUT); // set pin 9 as output
  pinMode(PIN_10, OUTPUT); // set pin 10 as output
  pinMode(PIN_11, OUTPUT); // set pin 11 as output
  pinMode(PIN_12, OUTPUT); // set pin 12 as output
}

void initializeSerial() {
  Serial.begin(9600); // start the serial at 9600 baud
  while (!Serial) { } // wait for serial port to connect. Needed for native USB port only
}

void customDelay(float duration) {
  if (duration < 0.001) {
    delayMicroseconds(duration * 1e6); // Convert seconds to microseconds
  } else {
    delay(duration * 1000); // Convert seconds to milliseconds
  }
}

void resetEncoder() {
  myEnc.write(0); // reset the encoder position
  prevDegrees = 0;
}

void toggleValve(int pin, float duration) {
  digitalWrite(pin, HIGH);   // Open valve
  customDelay(duration);     // Custom delay
  digitalWrite(pin, LOW);    // Close valve
  resetEncoder();
  prevDegrees = 0;
}

void toggleValve(int pin, bool &valveStatus) {
  if (!valveStatus) {
    digitalWrite(pin, HIGH); // Open valve
  } else {
    digitalWrite(pin, LOW);  // Close valve
  }
  valveStatus = !valveStatus;
}

float getDurationFromSerial(const char* prompt) {
  Serial.println(prompt);
  float DURinp = Serial.parseFloat(); // Read a number until terminating character
  Serial.print("Setting duration to: ");
  Serial.println(DURinp);
  return DURinp;
}

void displayWelcomeMessage() {
  Serial.println();
  Serial.println("Welcome to BehaviorBox - Wheel");
  Serial.println();
  Serial.println("WIRING:");
  Serial.println("The encoder 'myEnc' is connected to the interrupt pins 2 and 3");
  Serial.println("PIN_8 (Reward) is connected to digital pin 8");
  Serial.println("PIN_9 (Start Acquisition (SI)) is connected to digital pin 9");
  Serial.println("PIN_10 (Next File (SI)) is connected to digital pin 10");
  Serial.println("PIN_11 (End Acquisition (SI)) is connected to digital pin 11");
  Serial.println("PIN_12 (Timestamp (Time)) is connected to digital pin 12");
  Serial.println();
  Serial.println("SETTINGS:");
  Serial.print("Right reward: ");
  Serial.print(rightdur);
  Serial.println(" sec");
  Serial.println();
  Serial.println("USAGE:");
  Serial.println("The default behavior is to read from the Photogates and output L, M, R or -");
  Serial.println("Please enter one of the following characters to control the state:");
  Serial.println("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING");
  Serial.println("If the letter 'O' is entered, the current state will switch to RIGHT_OPEN");
  Serial.println("If the letter 'S' is entered, the current state will switch to RIGHT_SETUP");
  Serial.println("If the letter 'W' is entered, the current state will switch to WHO, which is an identifying state.");
  Serial.println("If the letter 'r' is entered, the encoder's position will be reset to 0 counts");
  Serial.println("If the letter 'T' is entered, the Timestamping pin will toggle");
  Serial.println("Note: The system is case sensitive, uppercase and lowercase letters will trigger different states.");
  Serial.println("Readout begins below...");
  Serial.println();
  resetEncoder();
  Serial.println(0);
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