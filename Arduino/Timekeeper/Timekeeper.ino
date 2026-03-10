// WBS 2026 - 03 - 10
// Timekeeper records:
//   - Pin 2 stimulus edges
//   - Pin 3 frame clocks
//
// Key design points:
//   1) One continuous monotonic session clock in microseconds.
//   2) 64-bit timestamp extension across micros() wrap.
//   3) Interrupt handlers only capture data into a ring buffer.
//   4) loop() handles all serial formatting/printing.

#include <Arduino.h>

constexpr uint8_t INPUT_PIN_2 = 2;  // Stimulus signal (BB)
constexpr uint8_t INPUT_PIN_3 = 3;  // Frame clock signal (SI)
constexpr uint8_t EVENT_BUFFER_SIZE = 64;
constexpr uint64_t MICROS_WRAP_US = (1ULL << 32);

enum RecordType : uint8_t {
  RECORD_STIMULUS = 1,
  RECORD_FRAME = 2
};

struct __attribute__((packed)) EventRecord {
  uint64_t t_us;   // Session-relative microseconds
  uint32_t data;   // Stimulus state (0/1) or frame count
  uint8_t type;    // RecordType
};

volatile EventRecord eventBuffer[EVENT_BUFFER_SIZE];
volatile uint8_t eventHead = 0;
volatile uint8_t eventTail = 0;
volatile uint32_t droppedEvents = 0;

volatile uint32_t lastMicrosLow = 0;
volatile uint64_t microsEpochUs = 0;
volatile uint64_t sessionStartUs = 0;
volatile uint32_t frameCount = 0;

static inline uint64_t getSessionMicrosISR() {
  const uint32_t currentMicros = micros();
  if (currentMicros < lastMicrosLow) {
    microsEpochUs += MICROS_WRAP_US;
  }
  lastMicrosLow = currentMicros;
  return (microsEpochUs + static_cast<uint64_t>(currentMicros)) - sessionStartUs;
}

static inline void enqueueRecordISR(uint8_t type, uint32_t data, uint64_t t_us) {
  const uint8_t nextHead = static_cast<uint8_t>((eventHead + 1) % EVENT_BUFFER_SIZE);
  if (nextHead == eventTail) {
    droppedEvents++;
    return;
  }

  eventBuffer[eventHead].type = type;
  eventBuffer[eventHead].data = data;
  eventBuffer[eventHead].t_us = t_us;
  eventHead = nextHead;
}

static bool dequeueRecord(EventRecord &record) {
  noInterrupts();
  if (eventTail == eventHead) {
    interrupts();
    return false;
  }

  record.type = eventBuffer[eventTail].type;
  record.data = eventBuffer[eventTail].data;
  record.t_us = eventBuffer[eventTail].t_us;
  eventTail = static_cast<uint8_t>((eventTail + 1) % EVENT_BUFFER_SIZE);
  interrupts();
  return true;
}

static void printUint64(uint64_t value) {
  char buffer[21];
  uint8_t idx = sizeof(buffer) - 1;
  buffer[idx] = '\0';

  do {
    --idx;
    buffer[idx] = static_cast<char>('0' + (value % 10ULL));
    value /= 10ULL;
  } while (value > 0 && idx > 0);

  Serial.print(&buffer[idx]);
}

void RecordStimulus() {
  const uint64_t t_us = getSessionMicrosISR();
  const uint32_t state = (digitalRead(INPUT_PIN_2) == HIGH) ? 1UL : 0UL;
  enqueueRecordISR(RECORD_STIMULUS, state, t_us);
}

// Frame clock from ScanImage, goes HIGH when the Y-Galvo flies back to start a new frame.
void RecordFrame() {
  const uint64_t t_us = getSessionMicrosISR();
  frameCount++;
  enqueueRecordISR(RECORD_FRAME, frameCount, t_us);
}

void setup() {
  Serial.begin(115200);
  while (!Serial) { }  // Needed for native USB boards.

  const uint32_t startupMicros = micros();
  lastMicrosLow = startupMicros;
  microsEpochUs = 0;
  sessionStartUs = static_cast<uint64_t>(startupMicros);
  frameCount = 0;

  pinMode(INPUT_PIN_2, INPUT_PULLUP);  // Pullup reduces spurious timestamps.
  pinMode(INPUT_PIN_3, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_2), RecordStimulus, CHANGE);
  attachInterrupt(digitalPinToInterrupt(INPUT_PIN_3), RecordFrame, RISING);

  Serial.println(F("Box ID: Time1"));
  Serial.println(F("Timestamp on rise:"));
  Serial.println(F("Pin 2 Stimulus"));
  Serial.println(F("Pin 3 Frame"));
}

void loop() {
  EventRecord record;
  while (dequeueRecord(record)) {
    if (record.type == RECORD_STIMULUS) {
      if (record.data == 1UL) {
        Serial.print(F("S On "));
      } else {
        Serial.print(F("S Off "));
      }
      printUint64(record.t_us);
      Serial.println();
    } else if (record.type == RECORD_FRAME) {
      printUint64(record.t_us);
      Serial.print(F(", F "));
      Serial.println(record.data);
    }
  }
}
