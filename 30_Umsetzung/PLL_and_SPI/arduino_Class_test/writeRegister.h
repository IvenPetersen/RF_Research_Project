#include <SPI.h>
#include "config.h"


void writeRegister(uint32_t val[], uint32_t PIN_LE, uint8_t Num) {
  for (int i = (Num-1); i >= 0; --i) {
    digitalWrite(PIN_LE, LOW);
    SPI.transfer((val[i] >> 24) & 0xFF);
    SPI.transfer((val[i] >> 16) & 0xFF);
    SPI.transfer((val[i] >> 8)  & 0xFF);
    SPI.transfer(val[i] & 0xFF);
    digitalWrite(PIN_LE, HIGH);
    delay(10);
  };
}