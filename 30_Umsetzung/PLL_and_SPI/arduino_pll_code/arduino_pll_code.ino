#include <SPI.h>

#define PIN_LE 10
#define F_2400_MHZ 0x00780000
#define F_2600_MHZ 0x00820000 
#define DEBUG_VALUE 1
#define PHASE 1

//Do not Change R1 to R5
#define R1_DEFAULT 0x08008011
#define R2_DEFAULT 0x00004E42
#define R3_DEFAULT 0x000004B3
#define R4_DEFAULT 0x0085003C
#define R5_DEFAULT 0x00580005

#define REF_FREQ 10   // 10 MHz Reference
#define MOD_VALUE 4095
#define PIN_LE 10


uint8_t Debug = DEBUG_VALUE;
uint32_t ADF4350_REG[6];
uint32_t FRAC = 0;
uint32_t MOD = 2;

// Beispiel-Registerwerte 
uint32_t regs[6] = {
  F_2400_MHZ, // R0 – f_PPL
  R1_DEFAULT, // R1
  R2_DEFAULT, // R2
  R3_DEFAULT, // R3
  R4_DEFAULT, // R4
  R5_DEFAULT  // R5 – zuerst schreiben
};

void define_MOD_and_FRAC(uint32_t FRACTION){
  switch (FRACTION) {
    case 1:
    FRAC = 1;
    MOD = 10;
    break;

    case 2:
    FRAC = 1;
    MOD = 10;
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
  return;
}
// Eingabe in MHz!
void setFrequency(uint32_t freqMHz)
{
  // Plausibilitätscheck
  if (freqMHz < 138 || freqMHz > 4400) {  // ADF4350: 137.5 MHz … 4.4 GHz
    if (Debug) { Serial.println("Freq out of range"); }
    return;
  }

  // Divider wählen, damit Fvco in [2200..4400] MHz liegt
  uint8_t divSel = 0;   // 0: /1, 1:/2, 2:/4, 3:/8, 4:/16 
  uint8_t divVal = 1;
  while ((uint64_t)freqMHz * divVal < 2200UL) {   // <== korrekt: 2.2 GHz
    divSel++;
    divVal <<= 1;
    if (divSel > 4) { if (Debug) Serial.println("Too low for /16"); return; }
  }
  double Fvco_Hz = (double)freqMHz * (double)divVal;

  // INT/FRAC berechnen: Fvco = (INT + FRAC/MOD)*fPFD
  const uint32_t fPFD = REF_FREQ;  
  double N = Fvco_Hz / (double)fPFD;
  uint32_t INT  = (uint32_t)floor(N);
  uint32_t FRACTION = (uint32_t)((N - (double)INT) * 10);
  define_MOD_and_FRAC(FRACTION);

  //if (FRAC == MOD) { INT += 1; FRAC = 0; }  // sauber rundungsfest

  // Mindest-INT prüfen bei Prescaler 8/9 (PR1=1): INT >= 75
  if (INT < 75) { if (Debug) Serial.println("INT < 75 (8/9)"); return; }  // :contentReference[oaicite:6]{index=6}

  // Register berechnen

  // R0 
  ADF4350_REG[0] = (INT << 15) | (FRAC << 3) | 0x0;                                      

  // R1 (PR1=8/9, PHASE=1, MOD), C3..C1=001
  ADF4350_REG[1] = (1u << 27) | (PHASE << 15) | (MOD << 3) | 0x01;

  ADF4350_REG[2] = R2_DEFAULT;                                      

  // R3 (Clock Divider aus, CSR aus)
  ADF4350_REG[3] = R3_DEFAULT; 

  uint32_t BS = 80u;
  ADF4350_REG[4] =
      (1u << 23) |                  // Feedback = FUNDAMENTAL
      ((uint8_t)divSel << 20) |     // RF Divider Select
      (BS << 12) |                  // 8-BIT BAND SELECT CLOCK DIVIDER VALUE
      (1u << 5) |                   // RF OUT enable
      (3u << 3) |                   // Output power = +5 dBm
      4u;                           // C3..C1 = 100 (R4)                                    // :contentReference[oaicite:13]{index=13}

  // R5 (LD pin = Digital Lock Detect), C3..C1=101
  ADF4350_REG[5] = R5_DEFAULT;                                                             // :contentReference[oaicite:14]{index=14}

  // Schreiben
  for (int i = 5; i >= 0; --i) {
    writeRegister(ADF4350_REG[i]);
    delay(10);
  }

  // Debug
  if (Debug) {
    Serial.print("Freq Set: "); Serial.print(freqMHz); Serial.println(" MHz");
    Serial.print("VCO: "); Serial.print(Fvco_Hz / 1e6); Serial.println(" MHz"); // korrekt in MHz
    Serial.print("INT="); Serial.print(INT);
    Serial.print(" FRAC="); Serial.print(FRAC);
    Serial.print("  DIV=/"); Serial.println(divVal);
    for (int i=0;i<6;i++){ Serial.print("R");Serial.print(i);Serial.print("=0x"); Serial.println(ADF4350_REG[i], HEX); }
  }
}


void writeRegister(uint32_t val) {
  digitalWrite(PIN_LE, LOW);
  SPI.transfer((val >> 24) & 0xFF);
  SPI.transfer((val >> 16) & 0xFF);
  SPI.transfer((val >> 8)  & 0xFF);
  SPI.transfer(val & 0xFF);
  digitalWrite(PIN_LE, HIGH);
}

void setup() {
  
  pinMode(PIN_LE, OUTPUT);
  digitalWrite(PIN_LE, HIGH);
  Serial.begin(115200);
  SPI.begin();
  SPI.beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE0));

  // Reihenfolge R5→R0
  for(int i = 5; i >= 0; i--) {
    writeRegister(regs[i]);
    delay(10);
  }
  Serial.print("setup done!\n");
}

void loop() 
{

  if(Serial.available())
  {
     Serial.print("Message received: "); 
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    Serial.print(cmd);
    Serial.print("\n");
    if(cmd.startsWith("F= "))
    {
      uint32_t freq = cmd.substring(3).toInt();
      Serial.print("substring (freq) is: ");
      Serial.print(freq, DEC);
      Serial.print("\n");
      setFrequency(freq);
    }
  }
}
