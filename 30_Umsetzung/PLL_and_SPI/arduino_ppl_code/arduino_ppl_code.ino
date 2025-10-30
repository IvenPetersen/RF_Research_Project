#include <SPI.h>

#define PIN_LE 10
#define F_2400_MHZ 0x00780000
#define F_2600_MHZ 0x00820000 
//Dont Change R1 to R5
#define R1_DEFAULT 0x08008011
#define R2_DEFAULT 0x00004E42
#define R3_DEFAULT 0x000004B3
#define R4_DEFAULT 0x0085003C
#define R5_DEFAULT 0x00580005

// Beispiel-Registerwerte – müssen für deine Ziel-Frequenz angepasst werden!
uint32_t regs[6] = {
  F_2600_MHZ, // R0 – f_PPL
  R1_DEFAULT, // R1
  R2_DEFAULT, // R2
  R3_DEFAULT, // R3
  R4_DEFAULT, // R4
  R5_DEFAULT  // R5 – zuerst schreiben
};

void writeRegister(uint32_t val) {
  digitalWrite(PIN_LE, LOW);
  SPI.transfer((val >> 24) & 0xFF);
  SPI.transfer((val >> 16) & 0xFF);
  SPI.transfer((val >> 8)  & 0xFF);
  SPI.transfer(val & 0xFF);
  digitalWrite(PIN_LE, HIGH);
}

void setup() {
  // put your setup code here, to run once:
  pinMode(PIN_LE, OUTPUT);
  digitalWrite(PIN_LE, HIGH);

  SPI.begin();
  SPI.beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));

  // Reihenfolge R5→R0
  for(int i = 5; i >= 0; i--) {
    writeRegister(regs[i]);
    delay(10);
  }

}

void loop() {
  // put your main code here, to run repeatedly:
  
}
