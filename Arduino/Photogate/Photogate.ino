#define PIN_4 4   // Left
#define PIN_5 5   // Middle
#define PIN_6 6   // Right
#define PIN_7 7   // Left Reward
#define PIN_8 8   // Right Reward

enum State { // Current State of the program
  READING,
  RIGHT_REWARDING,
  RIGHT_OPEN,
  LEFT_REWARDING,
  LEFT_OPEN,
  LEFT_SETUP,
  RIGHT_SETUP,
  WHO
};
State currentState = READING;
char str; // String to hold incoming serial data
bool hasPrintedL = false; // Flags to prevent repeat printing
bool hasPrintedM = false;
bool hasPrintedR = false;
bool hasPrintedNone = false;
bool RightOpen = false; // Valve status variables
bool LeftOpen = false;
// Reward Variables: 
float rightdur = 0.05;  // Length of a right Pulse
float leftdur = 0.05;  // Length of a left Pulse

void setup() {
  Serial.begin(9600); // start the serial at 9600 baud
  while (!Serial) { // wait for serial port to connect. Needed for native USB port only
    ;
  }
  // Set the serial timeout to 5000 milliseconds (5 seconds)
  Serial.setTimeout(5000);
  pinMode(PIN_4, INPUT_PULLUP); // set pin 4 as input with internal pullup resistor
  pinMode(PIN_5, INPUT_PULLUP); // set pin 5 as input with internal pullup resistor
  pinMode(PIN_6, INPUT_PULLUP); // set pin 6 as input with internal pullup resistor
  pinMode(PIN_7, OUTPUT); // set pin 7 as output
  pinMode(PIN_8, OUTPUT); // set pin 8 as output
  currentState = WHO;
}

void loop() {  
  if (currentState == READING) {
    if (Serial.available()) { // Switch between SETUP and REWARDING states
      str = (char)Serial.read(); // try this, don't wait for newline      
      switch (str) {
        case 'R':
          currentState = RIGHT_REWARDING; // switch to REWARDING state
          break;
        case 'r':
          currentState = RIGHT_OPEN;
          break;
        case 'L':
          currentState = LEFT_REWARDING; // switch to REWARDING state
          break;
        case 'l':
          currentState = LEFT_OPEN;
          break;
        case 'S': // Capital S for Left
          currentState = LEFT_SETUP; // switch to Setup
          break;
        case 's': // Lowercased s for Right
          currentState = RIGHT_SETUP; // switch to Setup
          break;
        case 'W':
          currentState = WHO; // switch to Identifying state
          break;
        // Optionally, add a default case to handle unexpected values
        default:
          // Handle unknown characters or add logging for unexpected values
          break;
      }
    }
    else {
      if (digitalRead(PIN_4) == LOW && !hasPrintedL) {
        Serial.println('L');
        hasPrintedL = true;
        hasPrintedM = false;
        hasPrintedR = false;
        hasPrintedNone = false;
      }
      else if (digitalRead(PIN_5) == LOW && !hasPrintedM) {
        Serial.println('M');
        hasPrintedM = true;
        hasPrintedL = false;
        hasPrintedR = false;
        hasPrintedNone = false;
      }
      else if (digitalRead(PIN_6) == LOW && !hasPrintedR) {
        Serial.println('R');
        hasPrintedR = true;
        hasPrintedL = false;
        hasPrintedM = false;
        hasPrintedNone = false;
      }
      else {
        if((digitalRead(PIN_4) == HIGH & digitalRead(PIN_5) == HIGH & digitalRead(PIN_6) == HIGH) && !hasPrintedNone) {
          Serial.println('-');
          hasPrintedL = false;
          hasPrintedM = false;
          hasPrintedR = false;
          hasPrintedNone = true;
        }
      }
      delay(10); // delay reduces "signal bouncing," could add debouncing circuit with resistors and capacitors or just keep the delay
    }
  }
  else if (currentState == RIGHT_REWARDING) {
    digitalWrite(PIN_8, HIGH);   // Open valve
    customDelay(rightdur);       // Custom delay
    digitalWrite(PIN_8, LOW);    // Close valve
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
    currentState = READING; // Go back to initial state
  }
  else if (currentState == RIGHT_OPEN) {
    if (RightOpen == false) {
      digitalWrite(PIN_8, HIGH);
      RightOpen = true;
      // Serial.print("right valve open");
    }
    else {
      digitalWrite(PIN_8, LOW);
      RightOpen = false;
      // Serial.print("right valve closed");
    }
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
    currentState = READING;
  }
  else if (currentState == LEFT_REWARDING) {
    digitalWrite(PIN_7, HIGH);   // Open valve
    customDelay(leftdur);        // Custom delay
    digitalWrite(PIN_7, LOW);    // Close valve
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
    currentState = READING; // Go back to initial state
  }
  else if (currentState == LEFT_OPEN) {
    if (LeftOpen == false) {
      digitalWrite(PIN_7, HIGH);
      LeftOpen = true;
      // Serial.print("left valve open");
    }
    else {
      digitalWrite(PIN_7, LOW);
      LeftOpen = false;
      // Serial.print("left valve closed");
    }
    currentState = READING;
  }
  else if (currentState == LEFT_SETUP) {
    Serial.println("Please input leftdur");
    float DURinp;
    DURinp = Serial.parseFloat(); // Read a number until terminating character
    leftdur = DURinp;
    // convert the string to float
    Serial.print("Left reward is ");
    Serial.println(leftdur);
    currentState = READING;
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
  }
  else if (currentState == RIGHT_SETUP) {
    Serial.println("Please input rightdur");
    float DURinp;
    DURinp = Serial.parseFloat(); // Read a number until terminating character
    rightdur = DURinp;    
    Serial.print("Right reward is ");
    Serial.println(rightdur, 4);
    
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
    currentState = READING;
  }
  else if (currentState == WHO) {
    // Introduction and Explanation of program
    Serial.println();
    Serial.println("Welcome to BehaviorBox - NosePoke");
    Serial.println();
    Serial.println("WIRING:");
    Serial.println("PIN_4 (Left) is connected to digital pin 4");
    Serial.println("PIN_5 (Middle) is connected to digital pin 5");
    Serial.println("PIN_6 (Right) is connected to digital pin 6");
    Serial.println("PIN_7 (Left Reward) is connected to digital pin 7");
    Serial.println("PIN_8 (Right Reward) is connected to digital pin 8");
    Serial.println();
    Serial.println("SETTINGS:");
    Serial.print("Right reward: ");
    Serial.print(rightdur, 4);
    Serial.println(" sec");
    Serial.print("Left reward: ");
    Serial.print(leftdur, 4);
    Serial.println(" sec");
    Serial.println();
    Serial.println("USAGE:");
    Serial.println("The default behavior is to read from the Photogates and output L, M, R or -");
    Serial.println("Please enter one of the following characters to control the state:");
    Serial.println("If the letter 'R' is entered, the current state will switch to RIGHT_REWARDING");
    Serial.println("If the letter 'r' is entered, the current state will switch to RIGHT_OPEN");
    Serial.println("If the letter 'L' is entered, the current state will switch to LEFT_REWARDING");
    Serial.println("If the letter 'l' is entered, the current state will switch to LEFT_OPEN");
    Serial.println("If the letter 'S' is entered, the current state will switch to LEFT_SETUP");
    Serial.println("If the letter 's' is entered, the current state will switch to RIGHT_SETUP");
    Serial.println("If the letter 'W' is entered, the current state will switch to WHO, which is an identifying state.");
    Serial.println("Note: The system is case sensitive, uppercase and lowercase letters will trigger different states.");
    Serial.println("Readout begins below...");
    Serial.println();
    Serial.println();
    hasPrintedL = false;
    hasPrintedM = false;
    hasPrintedR = false;
    hasPrintedNone = false;
    currentState = READING;
  }
}
void customDelay(float duration) {
  if (duration < 0.001) {
    delayMicroseconds(duration * 1e6); // Convert seconds to microseconds
  } else {
    delay(duration * 1000); // Convert seconds to milliseconds
  }
}
