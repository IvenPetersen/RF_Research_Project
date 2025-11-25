#include <SPI.h>
#include "pll_include.h"
#include "modulator_include.h"

ADF4350 pll;
LTC5589 modulator;

uint32_t negativGain = 0;
uint32_t freq = 2400;

void setup() {
  SPI.begin();
  delay(1);
  Serial.begin(SERIAL_BAUD_RATE);
  delay(1);
  pll.setup();
  modulator.setup();
  Serial.flush();
  Serial.println("Waiting for: \"F= [You'reFrequencyInMHz]\" ");
  Serial.println("Waiting for: \"MOD_NG= [You'reNegativGainIn_dB]\" for \"MOD_NegativGain\" ");
  Serial.println("Waiting for: \"MOD_QD= [1 or 0]\" for \"MOD_QDISABLE\" ");
}

void loop() 
{  
  if(Serial.available())
  {
    Serial.println("Message received: "); 
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    Serial.println(cmd);
    if(cmd.startsWith("F= "))
    {
      freq = cmd.substring(3).toInt();
      Serial.print("substring (freq in MHz) is: "); Serial.println(freq, DEC);
      
      pll.setFrequency(freq);
      modulator.setFrequency(freq);
    }
    if(cmd.startsWith("MOD_NG= "))
    {
      negativGain = cmd.substring(17).toInt();
      Serial.print("substring (negativGain) is: "); Serial.println(negativGain, DEC);
      modulator.setGain(negativGain);
    }
    if(cmd.startsWith("MOD_QD= "))
    {
      negativGain = cmd.substring(14).toInt();
      Serial.print("substring (QDISABLE) is: "); Serial.println(negativGain, DEC);
      modulator.setQDISABLE((bool)negativGain);
    }
    if(cmd.startsWith("help"))
      Serial.println("HELP:");
      Serial.println("Waiting for: \"F= [You'reFrequencyInMHz]\" ");
      Serial.println("Waiting for: \"MOD_NG= [You'reNegativGainIn_dB]\" for \"MOD_NegativGain\" ");
      Serial.println("Waiting for: \"MOD_QD= [1 or 0]\" for \"MOD_QDISABLE\" ");
  }
}
