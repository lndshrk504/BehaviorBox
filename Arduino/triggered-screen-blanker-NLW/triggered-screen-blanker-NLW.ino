// pin connected to the screen backlight
const byte pulse_pin = 13;

// rising and falling interrupt pins should
// both be tied to the same from the resonant mirros
const byte interrupt_pin_rising = 2;
const byte interrupt_pin_falling = 3;

// the number of incerements in SysTick->Val
// for my 120 MHz system, this is 120000, so 
// the timer wraps around 1000 times/sec
int sys_clock = 120000;

// Timing parameters:
// For my Metro M4 Grand Central
// with 120 MHz SAMD51, rough timings:
// 5000 ticks is 42.0 us
// 2000 ticks is 16.8 us
// 1000 ticks is 8.60 us
// 500  ticks is 4.40 us
// TN: NLW resonant scanner is 4 kHz, so line rate is 8 kHz. 1/8k = 125 us. Line clock output is high for ~90 us, then low for ~35 us.
// TN: We want set output to 1 soon after the falling edge (maybe 100 ticks after?), and for ~30 us = 3400 ticks

// NOTE: to connect the Grand Central board, it is best to un-plug and re-plug its USB connection, and then press the reset button
// This should cause the large LED to first go red, and then green. Now download the firmware.


// number of ticks from a rising/falling edge until
// the pulse triggered by that edge
//int delay_all = 3800; // Ali's setting for 2p-RAM
int delay_all = 13200; // 13200 places rising edge right after end of valid frame
int delay_rising = delay_all; 
int delay_falling = delay_all;

// number of ticks in a pulse triggered by 
// a rising/falling edge
//int pulse_ticks_all = 550; // Ali's setting for 2p-RAM
int pulse_ticks_all = 1950; //3900 = 100%, 1950 = 50%, ... HERE TO MODIFY THE BRIGHTNESS OF THE MONITOR
int pulse_ticks_rising = pulse_ticks_all;
int pulse_ticks_falling = pulse_ticks_all;

int current_time_r, current_time_f, current_time;
int next_rising_pulse_start_tick;
int next_falling_pulse_start_tick;
int current_pulse_start_tick;
int current_pulse_end_tick;
int max_delay;
int pulse_on = 0;
int diff = 0;

void setup() {
//  Serial.begin(115200);
  pulse_on = 0;
  max_delay = max(delay_rising, delay_falling) + max(pulse_ticks_rising, pulse_ticks_falling) + 1000;
  pinMode(pulse_pin, OUTPUT);
  digitalWrite(pulse_pin, HIGH);
  pinMode(interrupt_pin_rising, INPUT_PULLUP);
  pinMode(interrupt_pin_falling, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(interrupt_pin_rising), pulse_rising, RISING);
  attachInterrupt(digitalPinToInterrupt(interrupt_pin_falling), pulse_falling, FALLING);
}

int check_time(int current_time, int target_time){
/*  note: systick counts DOWN, which is counterintuitive. 
 *   Given the current time, and a target time, check if the current time is past 
 *   the target time. Systick wraps around to 119999 (or 120000?) when it reaches 0,
 *   so this is not trivial. Without the wraparound, we we would return 1 if 
 *   current_time - target_time < 0. Because of the wraparound, we take the modulus of 
 *   the difference and check if it is *larger* than some big number. The problem, if we 
 *   are actually "some big number" amount of ticks _past_ the target time, this function
 *   will think we are before it. Similarly, if we are "some big number" ticks _before_ the target
 *   time, this function will think we are after it. This is not a problem for our specific use case,
 *   but beware! 
     example: cur: 1; target: 5: return 1
              cur: 5; target: 5; return: 0
              cur: 6, target: 5; return: 0
              cur: 11990; target: 5: return 1
*/
  diff = current_time - target_time;
  // handle the case where there is no wraparound, so diff is a small negative number,
  // in which case we want to wrap it around to a large positive number
  if (diff < 0) {diff += sys_clock;}

  // handle the case where diff is too large 
  // this is for immediately after a pulse has started, before the next pulse
  // is triggered, we set the next_pulse_time to a really big number that the counter
  // will never reach
  if (diff > sys_clock) {return 0;}

  // if and only if diff is a large positive number, return 1
  // a large positive number is (sys_clock - max_delay), where max_delay
  // is the longest we should ever have to wait in this program
  if ((diff > (sys_clock - max_delay))){
    return 1;
  }
  return 0;
}

void loop() {
  current_time = SysTick->VAL;

  // if we are currently mid-pulse
  if (pulse_on == 0){
    // the following if block is repeated twice, one for a rising edge-triggered
    // pulse and once for a falling edge-triggered pulse. This is so you can set 
    // different pulse times, and also it can handle the case where the falling edge 
    // triggered pulse happend after the next rising edge.

    // check if it is time to turn the pulse on
    if (check_time(current_time, next_rising_pulse_start_tick)){
          pulse_on = 1;
          // calculate the start and end time of pulse
          current_pulse_start_tick = current_time;
          current_pulse_end_tick = current_time - pulse_ticks_rising;
          if (current_pulse_end_tick < 0) {current_pulse_end_tick += sys_clock;}
          // set the next pulse start tick to a large impossible number so it doesn't re
          // trigger another pulse
          next_rising_pulse_start_tick = -sys_clock - 1;
          digitalWrite(pulse_pin, HIGH);
      }
    if (check_time(current_time, next_falling_pulse_start_tick)){
          pulse_on = 1;
          current_pulse_start_tick = current_time;
          current_pulse_end_tick = current_time - pulse_ticks_falling;
          if (current_pulse_end_tick < 0) {current_pulse_end_tick += sys_clock;}
          next_falling_pulse_start_tick = -sys_clock - 1;
          digitalWrite(pulse_pin, HIGH);
      }
  }   
  // if the pulse is currently on
  if (pulse_on == 1){
    // check if it is time to turn the pulse off
    if (check_time(current_time, current_pulse_end_tick)){
          pulse_on = 0;
          digitalWrite(pulse_pin, LOW);
      }
  }
}

void pulse_rising() {
/*
 * Interrupt routine for rising edge. set the next rising pulse time.
 */
  current_time_r = SysTick->VAL;
  next_rising_pulse_start_tick = (current_time_r - delay_rising) % sys_clock;
}
void pulse_falling(){
  /*
   * Interrupt routine for rising edge. set the next rising pulse time.
   */
  current_time_f = SysTick->VAL;
  next_falling_pulse_start_tick = (current_time_f - delay_falling) % sys_clock;
}
