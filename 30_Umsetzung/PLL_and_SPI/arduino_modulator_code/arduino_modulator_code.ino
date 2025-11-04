#include <SPI.h>
#define MODULATOR_PIN_LE 11
#define DEBUG 1

uint32_t D_REGS[9] = {0x3E, 0xA0, 0x80, 0x80, 0x80, 0x10, 0x50, 0x06, 0x00};



 

void writeRegister(uint32_t val, int PIN_LE) {
  digitalWrite(PIN_LE, LOW);
  SPI.transfer((val >> 24) & 0xFF);
  SPI.transfer((val >> 16) & 0xFF);
  SPI.transfer((val >> 8)  & 0xFF);
  SPI.transfer(val & 0xFF);
  digitalWrite(PIN_LE, HIGH);
}
void setup() {
  // put your setup code here, to run once:
  pinMode(MODULATOR_PIN_LE, OUTPUT);
  digitalWrite(MODULATOR_PIN_LE, HIGH);
  Serial.begin(115200);
  SPI.begin();
  SPI.beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));

  // Reihenfolge R5→R0
  for(int i = 8; i >= 0; i--) {
    writeRegister(D_REGS[i],MODULATOR_PIN_LE);
    delay(10);
  }
  Serial.print("setup done!\n");

}

void loop() {
  // put your main code here, to run repeatedly:

}
