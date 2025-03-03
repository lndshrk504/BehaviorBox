// pin connected to the screen backlight
const byte pulse_pin = 13;

// Only use the falling edge from the resonant mirror signal
// (You can leave the falling edge pin as before)
const byte interrupt_pin_falling = 3;

// (Optionally, if you have a rising edge input on pin 2, you can simply not attach it.)
//
// const byte interrupt_pin_rising = 2;  // Not used in this version

// For a 120 MHz clock, 1 tick ~8.3 ns.
int sys_clock = 120000;

// --------------------------------------------
// For your system:
//   - The line clock low period is 18 µs.
//   - You want a 6 µs buffer after the falling edge,
//     then unblank (backlight on) for 6 µs.
// Thus, for the falling edge:
//   delay_falling = 6 µs in ticks ≈ 720 ticks
//   pulse_ticks_falling = 6 µs in ticks ≈ 720 ticks
// --------------------------------------------
int delay_falling = 760;          // 6 µs delay after falling edge
int pulse_ticks_falling = 680;      // 6 µs pulse width

// (We don’t use the rising edge at all, so you can ignore its parameters.)
int delay_rising = 0;               // not used
int pulse_ticks_rising = 0;         // not used

int current_time_f, current_time;
int next_falling_pulse_start_tick;
int current_pulse_start_tick;
int current_pulse_end_tick;
int max_delay;
int pulse_on = 0;
int diff = 0;

void setup() {
  pulse_on = 0;
  // We only care about the falling-edge parameters now.
  max_delay = delay_falling + pulse_ticks_falling + 1000;
  
  pinMode(pulse_pin, OUTPUT);
  // Depending on your hardware, setting HIGH may mean “screen blanked.”
  // (The original code did digitalWrite(pulse_pin, HIGH) to start with.)
  digitalWrite(pulse_pin, HIGH);
  
  // Only attach the falling edge interrupt:
  pinMode(interrupt_pin_falling, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(interrupt_pin_falling), pulse_falling, FALLING);
}

int check_time(int current_time, int target_time) {
  diff = current_time - target_time;
  if (diff < 0) { diff += sys_clock; }
  if (diff > sys_clock) { return 0; }
  if (diff > (sys_clock - max_delay)) {
    return 1;
  }
  return 0;
}

void loop() {
  current_time = SysTick->VAL;

  // We only have one pulse (from falling edge) to check.
  if (pulse_on == 0) {
    if (check_time(current_time, next_falling_pulse_start_tick)) {
      pulse_on = 1;
      current_pulse_start_tick = current_time;
      // Subtract the pulse duration to determine when to end the pulse.
      current_pulse_end_tick = current_time - pulse_ticks_falling;
      if (current_pulse_end_tick < 0) { current_pulse_end_tick += sys_clock; }
      // Set the next falling pulse start to a value that won’t be reached.
      next_falling_pulse_start_tick = -sys_clock - 1;
      digitalWrite(pulse_pin, HIGH);  // Turn on the backlight (unblank)
    }
  }
  
  if (pulse_on == 1) {
    if (check_time(current_time, current_pulse_end_tick)) {
      pulse_on = 0;
      digitalWrite(pulse_pin, LOW);  // Turn off the backlight (blank)
    }
  }
}

void pulse_falling(){
  // Interrupt routine for falling edge:
  // Capture the current timer value.
  current_time_f = SysTick->VAL;
  // Schedule the falling-edge pulse to start 6 µs (720 ticks) after the falling edge.
  next_falling_pulse_start_tick = (current_time_f - delay_falling) % sys_clock;
}
