#include <Servo.h> // servo library
#include <Encoder.h> // encoder library
#include <Wire.h>
#include <Adafruit_MotorShield.h>
#include "utility/Adafruit_MS_PWMServoDriver.h"

// Encoder input pins:
//   Best Performance: both pins have interrupt capability
//   Good Performance: only the first pin has interrupt capability
//   Low Performance:  neither pin has interrupt capability
//   avoid using pins with LEDs attached
//   Arduino uno: pins 2,3 have interrupt, pin 13 has LED

// I/O params
// NEVER USE pins 0 and 1 for general I/O. That would interfere with serial communication!
const int encoder_pin0 = 2;
const int encoder_pin1 = 3;
const int wisim_clk_pin = 7;
const int airpuff_trg_pin = 4;
const int whisker_trg_pin = 5;
const int led_pin = 6;
const int servo_pin = 9;
const unsigned long led_pulse_len_micros = 50000;
const unsigned long airpuff_pulse_len_micros = 200000;

// Experiment params
const int servo_pos0 = 40; // 75
const int servo_pos1 = 0;
const float servo_step = -0.005; // this should be a divisor of (servo_pos1 - servo_pos0)

// Variables
unsigned long time_start = 0;
unsigned long time_curr = 0;
unsigned long time_led_on = 0;
unsigned long time_airpuff_on = 0;
unsigned long time_last_treadmill_serial = 0;
long treadmill_pos_prev = 0;
long treadmill_pos_curr = 0;
int wisim_clk_prev = LOW;
int wisim_clk_curr = LOW;
int whisker_trg_prev = LOW;
int whisker_trg_curr = LOW;
int airpuff_trg_prev = LOW;
int airpuff_trg_curr = LOW;
int servo_move_dir = 0;
float servo_pos = servo_pos0;
int led_prev = LOW;
int led_curr = LOW;
bool waiting_for_start = false; // 0 = waiting for first clk, 1 = running
Encoder treadmill_encoder(encoder_pin0, encoder_pin1);
Servo whisker_servo;
Adafruit_MotorShield AFMS = Adafruit_MotorShield();
Adafruit_DCMotor *airpuff_valve_motor = AFMS.getMotor(4);
// Adafruit_DCMotor *motor2 = AFMS.getMotor(2);
// Adafruit_DCMotor *motor3 = AFMS.getMotor(3);
// Adafruit_DCMotor *motor4 = AFMS.getMotor(4);

byte serial_msg = 0;
// bit 0: clk rising edge occurred
// bit 1: 1 = clk rising edge is first since reset
// bit 2: 1 = moved whisker servo in
// bit 3: 1 = moved whisker servo out
// bit 4: 1 = treadmill pos changed
byte serial_msg_prev = 0;

void setup() {
  time_start = micros();
  Serial.begin(115200);
  
  // Init inputs
  pinMode(wisim_clk_pin,   INPUT);
  pinMode(whisker_trg_pin, INPUT);
  pinMode(airpuff_trg_pin, INPUT);
  wisim_clk_prev = digitalRead(wisim_clk_pin);
  whisker_trg_prev = digitalRead(whisker_trg_pin);
  airpuff_trg_prev = digitalRead(airpuff_trg_pin);
  treadmill_pos_prev = treadmill_encoder.read();

  // Init outputs
  pinMode(led_pin, OUTPUT);
  digitalWrite(led_pin, LOW);
  //whisker_servo.attach(servo_pin, 553, 2520); // Hitec HS-425BB
  whisker_servo.attach(servo_pin, 900, 2100); // Hitec HS-422
  whisker_servo.write(servo_pos);

  AFMS.begin();
  airpuff_valve_motor->setSpeed(255);
  airpuff_valve_motor->run(RELEASE);
//  motor2->setSpeed(0);
//  motor2->run(RELEASE);
//  motor3->setSpeed(0);
//  motor3->run(RELEASE);
//  motor4->setSpeed(0);
//  motor4->run(RELEASE);
}

void loop() {
  // in each loop, read wisim_clk_pin. if high: report, and flash LED for led_pulse_len_micros
  // in each loop, read whisker_trg_pin. if high: move in. if low, move out.
  // in each loop, read airpuff_trg_pin. if high: puff for puff_pulse_len_micros
  // in each loop, read encoder
  // only report serial output if clk, whisker or encoder event happened
  // reset the clock on first wisim_clk_edge
  
  time_curr = micros();  
  wisim_clk_curr = digitalRead(wisim_clk_pin);
  whisker_trg_curr = digitalRead(whisker_trg_pin);
  airpuff_trg_curr = digitalRead(airpuff_trg_pin);
  treadmill_pos_curr = treadmill_encoder.read();
  serial_msg = 0;

  if (Serial.available()) {
    if (Serial.readString() == "r") {
      waiting_for_start = true;
    }
  }

  if (time_led_on != 0 && ((time_curr - time_led_on) >= led_pulse_len_micros)) {
  //if (wisim_clk_prev == HIGH && wisim_clk_curr == LOW) {
    digitalWrite(led_pin, LOW);
    time_led_on = 0;
  }
  
  // if wisim_clk had a transition from low to high, we record the timestamp and toggle the LED on
  if (wisim_clk_prev == LOW && wisim_clk_curr == HIGH) {
    serial_msg = serial_msg | 1; // set bit 0 to report that a rising clk edge occurred
    if (true == waiting_for_start) {
      waiting_for_start = false;
      time_start = micros();
      serial_msg = serial_msg | 1 << 1; // set bit 1 to report that we got the first clk edge after reset
    }
    digitalWrite(led_pin, HIGH);
    time_led_on = micros();
  }

  // if whisker_trg_curr has changed, move servo accordingly
  if (whisker_trg_prev == LOW && whisker_trg_curr == HIGH) {
    servo_move_dir = 1;
    serial_msg = serial_msg | 1 << 2;
  }
  if (whisker_trg_prev == HIGH && whisker_trg_curr == LOW) {
    servo_move_dir = -1;
    serial_msg = serial_msg | 1 << 3;
  }

  if (+1 == servo_move_dir) {
    if (servo_pos <= servo_pos1) { // flip < and > here for moving larger to smaller pos
      servo_move_dir = 0;
    } else {
      servo_pos += servo_step;
      whisker_servo.write(servo_pos);
    }
  } else if (-1 == servo_move_dir) {
    if (servo_pos >= servo_pos0) { // flip < and > here for moving larger to smaller pos
      servo_move_dir = 0;
    } else {
      servo_pos -= servo_step;
      whisker_servo.write(servo_pos);
    }
  }

  if (treadmill_pos_prev != treadmill_pos_curr) {
    serial_msg = serial_msg | 1 << 4;
  }

  // if airpuff has been going on for long enough, close solenoid valve
  if (time_airpuff_on != 0 && ((time_curr - time_airpuff_on) >= airpuff_pulse_len_micros)) {
    airpuff_valve_motor->run(RELEASE);
    time_airpuff_on = 0;
  }

  // if airpuff_trg_curr has changed, open solenoid for airpuff
  if (airpuff_trg_prev == LOW && airpuff_trg_curr == HIGH) {
    time_airpuff_on = time_curr;
    airpuff_valve_motor->run(FORWARD);
    serial_msg = serial_msg | 1 << 5;
  }

  if (0 != serial_msg) {
    // if this and the previous message are only treadmill updates, hold off for at least 5 milliseconds
    if (!(1 << 4 == serial_msg && serial_msg_prev == serial_msg && (time_curr - time_last_treadmill_serial) < 5000)) {
      // message format: time_curr as dec int, serial_msg as hex int, treadmill_pos_curr as dec int
      Serial.print(time_curr - time_start);
      Serial.print("\t");
      Serial.print(serial_msg, BIN);
      Serial.print("\t");
      Serial.print(treadmill_pos_curr);
      Serial.print('\n');
      serial_msg_prev = serial_msg;
      if (1 << 4 == serial_msg) time_last_treadmill_serial = time_curr;
    }
  }
    
  treadmill_pos_prev = treadmill_pos_curr;
  wisim_clk_prev = wisim_clk_curr;
  whisker_trg_prev = whisker_trg_curr;
  airpuff_trg_prev = airpuff_trg_curr;
  led_prev = led_curr;

  //delayMicroseconds(100);
}
