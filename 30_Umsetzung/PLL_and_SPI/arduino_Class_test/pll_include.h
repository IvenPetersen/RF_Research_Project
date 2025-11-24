#include <SPI.h>
#include "writeRegister.h"
#include "config.h"





class ADF4350
{
  public:
    uint32_t pin_le = PLL_PIN_LE;
    uint32_t registers[6] = {PLL_F_2400_MHZ, PLL_R1_DEFAULT, PLL_R2_DEFAULT, PLL_R3_DEFAULT, PLL_R4_DEFAULT, PLL_R5_DEFAULT};
    size_t len = sizeof(registers) / sizeof(registers[0]);
    uint32_t FRAC = 0;
    uint32_t MOD = 2;
    //uint32_t freqMHz = 2400;
    uint32_t INT;
    uint32_t FRACTION;
    void define_MOD_and_FRAC(uint32_t FRACTION);
    void setFrequency(uint32_t freqMHz);
    void set_PIN_LE(uint8_t pin_le);
    void setup();
};



void ADF4350::setup() {
  
  pinMode(pin_le, OUTPUT);
  digitalWrite(pin_le, HIGH);
  

  

  // Reihenfolge R5→R0

  Serial.println("PLL:  setup done!");
  Serial.println("PLL:  Set to Default: 2400 MHz");

}




// Set the SPI LE Pin for ADF4350
void ADF4350::set_PIN_LE(uint8_t pin_le){
  pin_le = pin_le;
}




void ADF4350::define_MOD_and_FRAC(uint32_t FRACTION)
  {
    if(DEBUG){Serial.print("PLL: Function ADF4350.define_MOD_and_FRAC( "); Serial.print(FRACTION); Serial.println(" )");}
    switch (FRACTION) 
    {
      case 0:
      FRAC = 0;
      MOD = 2;
      break;

      case 1:
      FRAC = 1;
      MOD = 10;
      break;

      case 2:
      FRAC = 1;
      MOD = 5;
      break;

      case 3:
      FRAC = 3;
      MOD = 10;
      break;
      
      case 4:
      FRAC = 2;
      MOD = 5;
      break;
          
      case 5:
      FRAC = 1;
      MOD = 2;
      break;

      case 6:
      FRAC = 3;
      MOD = 5;
      break;

      case 7:
      FRAC = 7;
      MOD = 10;
      break;

      case 8:
      FRAC = 4;
      MOD = 5;
      break;

      case 9:
      FRAC = 9;
      MOD = 10;
      break;
    }
  }




// Set PLL Frequency. Input in MHz! 
void ADF4350::setFrequency(uint32_t freqMHz)
  {
    // validity check
    if (freqMHz < 138 || freqMHz > 4400) {  // ADF4350: 137.5 MHz … 4.4 GHz
      if (DEBUG) { Serial.println("Freq out of range"); }
      return;
    }

    // Select divider so that Fvco is in the range [2200..4400] MHz
    uint8_t divSel = 0;   // 0: /1, 1:/2, 2:/4, 3:/8, 4:/16 
    uint8_t divVal = 1;
    while ((uint64_t)freqMHz * divVal < 2200UL) {   // <== Correct: 2.2 GHz
      divSel++;
      divVal <<= 1;
      if (divSel > 4) { if (DEBUG) Serial.println("Too low for /16"); return; }
    }
    double Fvco_Hz = (double)freqMHz * (double)divVal;

    // Calculate INT/FRAC: Fvco = (INT + FRAC/MOD)*fPFD
    const uint32_t fPFD = PLL_REF_FREQ;  
    double N = Fvco_Hz / (double)fPFD;
    INT  = (uint32_t)floor(N);
    FRACTION = (uint32_t)(((N - (double)INT) + 0.05) * 10);
    define_MOD_and_FRAC(FRACTION);

    // if (FRAC == MOD) { INT += 1; FRAC = 0; }  // sauber rundungsfest

    // Check minimum INT for prescaler 8/9 (PR1=1): INT >= 75
    if (INT < 75) { if (DEBUG) Serial.println("INT < 75 (8/9)"); return; }  // :contentReference[oaicite:6]{index=6}

    // Calculate registers

    // R0 
    registers[0] = (INT << 15) | (FRAC << 3) | 0x0;                                      

    // R1 (PR1=8/9, PHASE=1, MOD), C3..C1=001
    registers[1] = (1u << 27) | (PLL_PHASE << 15) | (MOD << 3) | 0x01;

    registers[2] = PLL_R2_DEFAULT;                                      

    // R3 (clock divider off, CSR off)
    registers[3] = PLL_R3_DEFAULT; 

    registers[4] =
      (1u << 23) |                  // Feedback = FUNDAMENTAL
      ((uint8_t)divSel << 20) |     // RF Divider Select
      (PLL_BS << 12) |              // 8-BIT BAND SELECT CLOCK DIVIDER VALUE
      (1u << 5) |                   // RF OUT enable
      (3u << 3) |                   // Output power = +5 dBm
      4u;                           // C3..C1 = 100 (R4)                                          // :contentReference[oaicite:13]{index=13}

    // R5 (LD pin = Digital Lock Detect), C3..C1=101
    registers[5] = PLL_R5_DEFAULT;                                                             // :contentReference[oaicite:14]{index=14}

    // Schreiben
    writeRegister(registers, pin_le, len);


    // DEBUG
    if (DEBUG) {
      Serial.print("PLL:  Freq Set: "); Serial.print(freqMHz); Serial.println(" MHz");
      Serial.print("PLL:  VCO: "); Serial.print(Fvco_Hz / 1e6); Serial.println(" MHz"); 
      Serial.print("PLL:  INT="); Serial.print(INT);
      Serial.print(" PLL:  FRAC="); Serial.print(FRAC);
      Serial.print(" PLL:  N="); Serial.print(N);
      Serial.print(" PLL:  DIV=/"); Serial.println(divVal);
      for (int i=0; i < len; i++){ Serial.print(" PLL:  R");Serial.print(i);Serial.print(" = 0x"); Serial.println(registers[i], HEX); }
    }
  }