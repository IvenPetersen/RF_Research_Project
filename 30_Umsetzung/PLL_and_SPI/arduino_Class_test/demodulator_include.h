#include <SPI.h>
#include "config.h"

// Minimal LTC5594 class modeled after your LTC5589 style
class LTC5594 {
  public:
    void setup();
    void set_PIN_LE(uint8_t pin);
    void writeAll();              // burst-write the whole register map

    void setLoMatch(uint8_t r0x12, uint8_t r0x13); // LO matching (Table 2)
    void setIfGainRaw(uint8_t reg15);             // raw write of 0x15 (gain etc.)

    uint8_t pin_le = DEMOD_PIN_LE;   // define DEMOD_PIN_LE in config.h

    // Very small register map: only the registers we actually touch
    // You can extend this later if you want full coverage.
    // Index 0 -> Reg 0x12, 1 -> Reg 0x13, 2 -> Reg 0x15, 3 -> Reg 0x16
    uint8_t registers[4] = {
      0x48, // R0: Reg 0x12 default (LVCM/CF1)
      0x80, // R1: Reg 0x13 default (BAND/LF1/CF2)
      0x6A, // R2: Reg 0x15 default (PHA/AMPG/...)
      0xF0  // R3: Reg 0x16 default (EDEM/EDC/EADJ/EAMP/SRST/SDO)
    };

    size_t len = sizeof(registers) / sizeof(registers[0]);
};

// -------- Implementation --------

void LTC5594::setup() {
  pinMode(pin_le, OUTPUT);
  digitalWrite(pin_le, HIGH);

  // optional: one-time soft reset via Reg 0x16, bit SRST
  SPI.beginTransaction(SPISettings(SPI_SPEED, MSBFIRST, SPI_MODE0));
  digitalWrite(pin_le, LOW);
  SPI.transfer((uint8_t)0x16);      // address 0x16
  SPI.transfer((uint8_t)(registers[3] | 0x08)); // set SRST bit
  digitalWrite(pin_le, HIGH);
  SPI.endTransaction();

  delay(1);

  // clear SRST again to normal operation
  SPI.beginTransaction(SPISettings(SPI_SPEED, MSBFIRST, SPI_MODE0));
  digitalWrite(pin_le, LOW);
  SPI.transfer((uint8_t)0x16);
  SPI.transfer(registers[3] & ~0x08);
  digitalWrite(pin_le, HIGH);
  SPI.endTransaction();

  // bring local copy in sync (SRST=0)
  registers[3] &= ~0x08;

#if DEBUG
  Serial.println("Demod:  LTC5594 setup done (soft reset + defaults)!" );
#endif
}

void LTC5594::set_PIN_LE(uint8_t pin) {
  pin_le = pin;
}

// Set LO matching values taken from datasheet Table 2
// r0x12 -> full byte for register 0x12
// r0x13 -> full byte for register 0x13
void LTC5594::setLoMatch(uint8_t r0x12, uint8_t r0x13) {
  registers[0] = r0x12; // Reg 0x12
  registers[1] = r0x13; // Reg 0x13
  writeAll();
}

// Raw write for register 0x15 (gain / phase)
// If you just want default gain, leave registers[2] = 0x6A
void LTC5594::setIfGainRaw(uint8_t reg15) {
  registers[2] = reg15;
  writeAll();
}

// Burst-write all four bytes starting at register 0x12
// (auto-increment: 0x12, 0x13, 0x14, 0x15 -- but we only care about 0x12,0x13,0x15,0x16)
void LTC5594::writeAll() {
  SPI.beginTransaction(SPISettings(SPI_SPEED, MSBFIRST, SPI_MODE0));

  digitalWrite(pin_le, LOW);
  SPI.transfer((uint8_t)0x12); // start address

  // 0x12, 0x13, 0x14, 0x15 in one go
  // We map our small array as: [0] -> 0x12, [1] -> 0x13, [2] -> 0x15, [3] -> 0x16
  SPI.transfer(registers[0]);  // Reg 0x12
  SPI.transfer(registers[1]);  // Reg 0x13
  SPI.transfer(0x80);          // Reg 0x14 (unused, keep at 0x80 for now)
  SPI.transfer(registers[2]);  // Reg 0x15

  digitalWrite(pin_le, HIGH);
  SPI.endTransaction();

#if DEBUG
  Serial.println("Demod:  LTC5594 registers written (0x12..0x15):");
  Serial.print("  R0x12 = 0x"); Serial.println(registers[0], HEX);
  Serial.print("  R0x13 = 0x"); Serial.println(registers[1], HEX);
  Serial.print("  R0x15 = 0x"); Serial.println(registers[2], HEX);
#endif

  // write 0x16 separately if needed
  SPI.beginTransaction(SPISettings(SPI_SPEED, MSBFIRST, SPI_MODE0));
  digitalWrite(pin_le, LOW);
  SPI.transfer((uint8_t)0x16);
  SPI.transfer(registers[3]);
  digitalWrite(pin_le, HIGH);
  SPI.endTransaction();

#if DEBUG
  Serial.print("  R0x16 = 0x"); Serial.println(registers[3], HEX);
#endif
}
