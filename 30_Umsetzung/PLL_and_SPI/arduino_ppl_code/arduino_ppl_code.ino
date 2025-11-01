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

#define REF_FREQ 10   // 25 MHz Reference
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
  // --- 0) Plausibilitätscheck
  if (freqMHz < 138 || freqMHz > 4400) {  // ADF4350: 137.5 MHz … 4.4 GHz
    if (Debug) { Serial.println("Freq out of range"); }
    return;
  }

  // --- 1) Divider wählen, damit Fvco in [2200..4400] MHz liegt
  uint8_t divSel = 0;   // 0: /1, 1:/2, 2:/4, 3:/8, 4:/16  (R4 D12..D10)
  uint8_t divVal = 1;
  while ((uint64_t)freqMHz * divVal < 2200UL) {   // <== korrekt: 2.2 GHz
    divSel++;
    divVal <<= 1;
    if (divSel > 4) { if (Debug) Serial.println("Too low for /16"); return; }
  }
  double Fvco_Hz = (double)freqMHz * (double)divVal;

  // --- 2) INT/FRAC berechnen: Fvco = (INT + FRAC/MOD)*fPFD
  const uint32_t fPFD = REF_FREQ;     // REFIN=25 MHz, R=1, Doubler/2=0
  //const uint32_t MOD  = MOD_VALUE;    // 4095
  double N = Fvco_Hz / (double)fPFD;
  uint32_t INT  = (uint32_t)floor(N);
  uint32_t FRACTION = (uint32_t)((N - (double)INT) * 10);
  define_MOD_and_FRAC(FRACTION);

  //if (FRAC == MOD) { INT += 1; FRAC = 0; }  // sauber rundungsfest

  // --- Mindest-INT prüfen bei Prescaler 8/9 (PR1=1): INT >= 75
  if (INT < 75) { if (Debug) Serial.println("INT < 75 (8/9)"); return; }  // :contentReference[oaicite:6]{index=6}

  // --- 3) Register berechnen (siehe Register-Map im DB)

  // R0 (INT/FRAC)  [DB31..15]=INT, [DB14..3]=FRAC, C3..C1=000
  ADF4350_REG[0] = (INT << 15) | (FRAC << 3) | 0x0;                                       // :contentReference[oaicite:7]{index=7}

  // R1 (PR1=8/9, PHASE=1, MOD=4095), C3..C1=001
  // PR1@DB27, PHASE@DB26..15, MOD@DB14..3
  ADF4350_REG[1] = (1u << 27) | (PHASE << 15) | (MOD << 3) | 0x01;

  // R2 (Low Spur Mode, R=1, CP=2.5mA, DB13=1 für double-buffered Divider, MUXOUT=Digital LD), C3..C1=010
  // L2:L1@DB30..29=11, MUXOUT@DB28..26=110 (Digital Lock Detect), RD2/RD1=0,
  // R@[DB23..14]=1, DB13=1, CP@[DB12..9]=0b0111 (2.5mA), U5(LDP)=1, U4(PD_POL)=1
  ADF4350_REG[2] = 0x4E42;                                      // :contentReference[oaicite:9]{index=9}

  // R3 (Clock Divider aus, CSR aus), C3..C1=011  – Standardwert ausreichend
  ADF4350_REG[3] = 0x000004B3;                                                             // :contentReference[oaicite:10]{index=10}

  // R4 (RF OUT enable, +5 dBm, Feedback=VCO, BS=200, DividerSelect=divSel), C3..C1=100
  // Feedback Select: DB23=1 → VCO direkt (Loop vor Divider)                               // :contentReference[oaicite:11]{index=11}
  // Band-Select-Clock-Divider: DB19..12 = 200 (25 MHz / 200 = 125 kHz)                    // :contentReference[oaicite:12]{index=12}
  uint32_t BS = 80u;
  ADF4350_REG[4] =
      (1u << 23) |                  // Feedback = FUNDAMENTAL
      ((uint8_t)divSel << 20) |     // RF Divider Select
      (BS << 12) |                  // 8-BIT BAND SELECT CLOCK DIVIDER VALUE
      (1u << 5) |                   // RF OUT enable
      (3u << 3) |                   // Output power = +5 dBm
      4u;                           // C3..C1 = 100 (R4)                                    // :contentReference[oaicite:13]{index=13}

  // R5 (LD pin = Digital Lock Detect), C3..C1=101
  ADF4350_REG[5] = 0x00580005;                                                             // :contentReference[oaicite:14]{index=14}

  // --- 4) Schreiben in empfohlener Init-Reihenfolge
  for (int i = 5; i >= 0; --i) {
    writeRegister(ADF4350_REG[i]);
    delay(10);
  }

  // --- 5) Debug
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
  // put your setup code here, to run once:
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
  // put your main code here, to run repeatedly:
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
