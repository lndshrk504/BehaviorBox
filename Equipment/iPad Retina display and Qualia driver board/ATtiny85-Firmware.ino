/* Adafruit Qualia firmware for DisplayPort to LP097QX1 driver board
   Basically, a Trinket w/PWM output to the LT backlight driver. :)
   Recompile with Adafruit Trinket 8MHz supported Arduino IDE. 
   Upload w/USBtinyISP
*/

#include "EEPROM.h"

#define led 1
#define upbutton 4
#define downbutton 3
#define onoffbutton 0

int16_t brightness;      // range from 0 to 255 (0 is off)

boolean on = true;       // whether the display is 'on' or not
boolean dirtee = false;  // is the EEPROM brightness wrong?

void setBrightness(uint8_t b) {
  OCR1A = b; 
}


void setup() {
  digitalWrite(led, LOW);
  pinMode(led, OUTPUT);
  
  // way faster than analogWrite, 15.625Khz!
  OCR1C = 255;
  OCR1A = 0;
  TCCR1 = _BV(CS10) | _BV(CS11) | _BV(PWM1A) | _BV(COM1A1);
  
  // read the eeprom location 0!
  brightness = EEPROM.read(0);
  
  // slowly fade up!
  for (uint8_t i=0; i < brightness; i++) {
    setBrightness(i);
    delay(10);
  }
   
  pinMode(upbutton, INPUT);
  digitalWrite(upbutton, HIGH);
  pinMode(downbutton, INPUT);
  digitalWrite(downbutton, HIGH);
  pinMode(onoffbutton, INPUT);
  digitalWrite(onoffbutton, HIGH);
}


void loop() {
  if (on) {
    while (! digitalRead(downbutton)) {

      // Don't let it get dimmer than 2/255
      if (brightness > 2) {
        brightness --;
        setBrightness(brightness);
        dirtee = true;
      }
      delay(10);
    }
    while (! digitalRead(upbutton)) {
      if (brightness != 255) {
        brightness ++;
        setBrightness(brightness);
        dirtee = true;
      }
      delay(10);
    }
    // once they release the button, write the new brightness to EEPROM
    if (dirtee) {
      EEPROM.write(0, brightness);
      dirtee = false;
    }
  }
  
  if (! digitalRead(onoffbutton)) {
    delay(10);
    while (! digitalRead(onoffbutton));
    delay(10);
    if (on) {
      // quickly turn off
      setBrightness(0);
      delay(100);
      on = false;
    } else {
      // slowly fade up!
      for (uint8_t i=0; i < brightness; i++) {
        setBrightness(i);
        delay(10);
      }
      // give me a break to avoid any bouncing
      delay(100);
      // we're on
      on = true;
    }
  }
}