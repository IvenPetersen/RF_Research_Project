#include <SPI.h>
#include "config.h"

class LTC5589{
  public:
    void setFrequency(uint32_t fMHz);
    void set_PIN_LE(uint8_t pin_le);
    void setGain(uint32_t minusGain);
    void setQDISABLE(bool QDISABLE);
    void setup();
    uint8_t pin_le = MOD_PIN_LE;
    uint32_t registers[9] = {MOD_R1_DEFAULT, MOD_R2_DEFAULT, MOD_R3_DEFAULT, MOD_R4_DEFAULT, MOD_R5_DEFAULT, MOD_R6_DEFAULT, MOD_R7_DEFAULT, MOD_R8_DEFAULT, MOD_R9_DEFAULT};
    size_t len = sizeof(registers) / sizeof(registers[0]);
};

// Return the HEX register value for a given LO frequency in MHz.
// Ranges are [LOWER, UPPER) with UPPER exclusive. 0x04 is f >= 9204 MHz.
// Returns 0xFF if the frequency is out of all listed ranges.
void LTC5589::setFrequency(uint32_t fMHz) {
  struct Range { uint16_t lower; uint16_t upper; };
  static const Range R[] = {
    // reg 0x04..0x3D
    {9204,    0},    // 0x04: [9204, +inf)
    {9015, 9204},    // 0x05
    {8829, 9015},    // 0x06
    {8648, 8829},    // 0x07
    {8470, 8648},    // 0x08
    {8295, 8470},    // 0x09
    {8125, 8295},    // 0x0A
    {7958, 8125},    // 0x0B
    {7794, 7958},    // 0x0C
    {7634, 7794},    // 0x0D
    {7477, 7634},    // 0x0E
    {7323, 7477},    // 0x0F
    {7172, 7323},    // 0x10
    {7025, 7172},    // 0x11
    {6880, 7025},    // 0x12
    {6739, 6880},    // 0x13
    {6600, 6739},    // 0x14
    {6464, 6600},    // 0x15
    {6332, 6464},    // 0x16
    {6201, 6332},    // 0x17
    {6074, 6201},    // 0x18
    {5862, 6074},    // 0x19
    {5768, 5862},    // 0x1A
    {5622, 5768},    // 0x1B
    {5556, 5622},    // 0x1C
    {5223, 5556},    // 0x1D
    {5167, 5223},    // 0x1E
    {5031, 5167},    // 0x1F
    {4951, 5031},    // 0x20
    {4789, 4951},    // 0x21
    {4725, 4789},    // 0x22
    {4618, 4725},    // 0x23
    {4439, 4618},    // 0x24
    {4260, 4439},    // 0x25
    {4178, 4260},    // 0x26
    {4092, 4178},    // 0x27
    {4008, 4092},    // 0x28
    {3926, 4008},    // 0x29
    {3845, 3926},    // 0x2A
    {3766, 3845},    // 0x2B
    {3688, 3766},    // 0x2C
    {3613, 3688},    // 0x2D
    {3538, 3613},    // 0x2E
    {3465, 3538},    // 0x2F
    {3394, 3465},    // 0x30
    {3324, 3394},    // 0x31
    {3256, 3324},    // 0x32
    {3189, 3256},    // 0x33
    {3123, 3189},    // 0x34
    {3059, 3123},    // 0x35
    {2996, 3059},    // 0x36
    {2935, 2996},    // 0x37
    {2874, 2935},    // 0x38
    {2815, 2874},    // 0x39
    {2757, 2815},    // 0x3A
    {2701, 2757},    // 0x3B
    {2645, 2701},    // 0x3C
    {2591, 2645},    // 0x3D
    {2537, 2591},    // 0x3E
    {2485, 2537},    // 0x3F
    {2434, 2485},    // 0x40
    {2384, 2434},    // 0x41
    {2335, 2384},    // 0x42
    {2287, 2335},    // 0x43
    {2240, 2287},    // 0x44
    {2194, 2240},    // 0x45
    {2149, 2194},    // 0x46
    {2104, 2149},    // 0x47
    {2061, 2104},    // 0x48
    {2019, 2061},    // 0x49
    {1818, 2019},    // 0x4A
    {1710, 1818},    // 0x4B
    {1590, 1710},    // 0x4C
    {1506, 1590},    // 0x4D
    {1479, 1506},    // 0x4E
    {1453, 1479},    // 0x4F
    {1427, 1453},    // 0x50
    {1402, 1427},    // 0x51
    {1377, 1402},    // 0x52
    {1353, 1377},    // 0x53
    {1329, 1353},    // 0x54
    {1305, 1329},    // 0x55
    {1282, 1305},    // 0x56
    {1278, 1282},    // 0x57
    {1221, 1278},    // 0x58
    {1160, 1221},    // 0x59
    {1143, 1160},    // 0x5A
    {1140, 1143},    // 0x5B
    {1116, 1140},    // 0x5C
    {1088, 1116},    // 0x5D
    {1085, 1088},    // 0x5E
    {1079, 1085},    // 0x5F
    {1062, 1079},    // 0x60
    {1037, 1062},    // 0x61
    {1030, 1037},    // 0x62
    {1017, 1030},    // 0x63
    { 999, 1017},    // 0x64
    { 981,  999},    // 0x65
    { 964,  981},    // 0x66
    { 947,  964},    // 0x67
    { 930,  947},    // 0x68
    { 914,  930},    // 0x69
    { 897,  914},    // 0x6A
    { 880,  897},    // 0x6B
    { 860,  880},    // 0x6C
    { 849,  860},    // 0x6D
    { 829,  849},    // 0x6E
    { 810,  829},    // 0x6F
    { 792,  810},    // 0x70
    { 774,  792},    // 0x71
    { 757,  774},    // 0x72
    { 741,  757},    // 0x73
    { 726,  741},    // 0x74
    { 712,  726},    // 0x75
    { 699,  712},    // 0x76
    { 687,  699},    // 0x77
    { 675,  687},    // 0x78
    { 663,  675},    // 0x79
    { 651,  663},    // 0x7A
    { 639,  651},    // 0x7B
    { 628,  639},    // 0x7C
    { 618,  628},    // 0x7D
    { 609,  618},    // 0x7E
    {   0,  609},    // 0x7F    
  };

  // Loop over 0x04..0x3D
  for (uint32_t i = 0; i < sizeof(R)/sizeof(R[0]); ++i) {
    const uint16_t lo = R[i].lower;
    const uint16_t hi = R[i].upper; // 0 means "no upper bound"
    if (fMHz >= lo && (hi == 0 || fMHz < hi)) {
      registers[0] = (0x04 + i);
      writeRegister(registers, pin_le, len);
      if(DEBUG){
        Serial.println("Modulator:  registers set by LTC5589.setFrequency!");
        for (int i=0; i < len; i++){ Serial.print("Modulator:  R");Serial.print(i);Serial.print(" = 0x"); Serial.println(registers[i], HEX); }
      }
      return;
    }
  }
  Serial.println("Modulator:  ERROR:  Frequency for Modulator LTC5589 out of bound!");
  registers[0] = 0x3E; // not found
  Serial.println("Modulator:    Frequency for Modulator LTC5589 set to DEFAULT (2537 to 2591) [registers[0] = 0x3E]. Because LTC5589 out of bound! \n");
  
  writeRegister(registers, pin_le, len);

}
 
// set digital Gain from 0dB to -19dB
void LTC5589::setGain(uint32_t minusGain) {
  // Clamp to valid range
  if (minusGain > 19){ 
    minusGain = 19;
    Serial.println("Modulator:  WARNING:  minusGain cant be lower then -19dB and is now set to -19dB"); Serial.print("  Modulator:  WARNING:  Youer input was: -"); Serial.print(minusGain); Serial.println("dB.");
  }
  // preserve the upper control bits, replace only GAIN[4:0]
  registers[1] = (registers[1] & ~MOD_MASK_GAIN) | ( (uint8_t)minusGain & MOD_MASK_GAIN);
  writeRegister(registers, pin_le, len);
  if(DEBUG){
    Serial.println("Modulator:  registers set by LTC5589.setGain!");
    for (int i=0; i < len; i++){ Serial.print("Modulator:  R");Serial.print(i);Serial.print(" = 0x"); Serial.println(registers[i], HEX); }
  }
}

// give bool QDISABLE. If QDISABLE is true Q is deactivated 
void LTC5589::setQDISABLE(bool QDISABLE) {
  uint8_t num = 0;
  if(QDISABLE){num = 0xFF;}

  registers[1] = (registers[1] & ~MOD_MASK_QDISABLE) | ( num & MOD_MASK_QDISABLE);
  writeRegister(registers, pin_le, len);
  if(DEBUG){
    Serial.println("Modulator:  registers set by LTC5589.setQDISABLE!");
    for (int i=0; i < len; i++){ Serial.print("Modulator:  R");Serial.print(i);Serial.print(" = 0x"); Serial.println(registers[i], HEX); }
  }
}

// setup LTC5589 
// use "LTC5589.set_PIN_LE(uint8_t pin_le)" to change pin_le mid run or check config.h for initial value
void LTC5589::setup() {
  pinMode(pin_le, OUTPUT);
  digitalWrite(pin_le, HIGH);;

  SPI.beginTransaction(SPISettings(SPI_SPEED, MSBFIRST, SPI_MODE0));

  Serial.println("Modulator:  setup done!");


}

void LTC5589::set_PIN_LE(uint8_t pin_le){
  pin_le = pin_le;
}
