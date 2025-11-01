#include <SPI.h>

#define PIN_LE 10
#define F_2400_MHZ 0x00780000
#define F_2600_MHZ 0x00820000 
#define DEBUG_VALUE 1


//Do not Change R1 to R5
#define R1_DEFAULT 0x08008011
#define R2_DEFAULT 0x00004E42
#define R3_DEFAULT 0x000004B3
#define R4_DEFAULT 0x0085003C
#define R5_DEFAULT 0x00580005

#define REF_FREQ 25000000UL   // 25 MHz Reference
#define MOD_VALUE 4095
#define PIN_LE 10

uint8_t Debug = DEBUG_VALUE;
uint32_t ADF4350_REG[6];

// Beispiel-Registerwerte – müssen für deine Ziel-Frequenz angepasst werden!
uint32_t regs[6] = {
  F_2400_MHZ, // R0 – f_PPL
  R1_DEFAULT, // R1
  R2_DEFAULT, // R2
  R3_DEFAULT, // R3
  R4_DEFAULT, // R4
  R5_DEFAULT  // R5 – zuerst schreiben
};
// setFrequency freqHz in MHz
void setFrequency(uint32_t freqHz)
{
  Serial.print("setFrequency( "); Serial.print(freqHz, DEC); Serial.print(" )begins! \n");
  // 1.) Divider bestimmen
  uint8_t divSel = 0;
  uint8_t divVal = 1;
  while(freqHz * divVal < 4400) {
      divSel++;
      divVal <<= 1;
      if(divSel > 4) return; // <137.5 MHz nicht möglich
  }

  // Ziel-VCO Frequenz
  double Fvco = (double)freqHz * 1e6 * (double)divVal;

  // 2.) INT + FRAC berechnen
  double ratio = Fvco / (double)REF_FREQ;
  uint32_t INT  = (uint32_t)ratio;
  uint32_t FRAC = (uint32_t)((ratio - INT) * MOD_VALUE);

  // 3.) Register setzen
  // R0 - INT + FRAC
  ADF4350_REG[0] = (INT << 15) | (FRAC << 3) | 0;

  // R1 - Prescaler 8/9, PHASE = 1, MOD = 4095
  ADF4350_REG[1] = 0x08008011;

  // R2 - Low Spur Mode, CP = 2.5mA, R=1, Digital Lock Detect
  ADF4350_REG[2] = 0x00004E42;

  // R3 - Clock Divider off, CSR off
  ADF4350_REG[3] = 0x000004B3;

  // R4 - Divider Select dynamisch (Bits D12:D10)
  ADF4350_REG[4] = (0x00A4003C & ~(0x7 << 10)) | (divSel << 10);

  // R5 - LD Output Mode
  ADF4350_REG[5] = 0x00580005;


  // 4.) Reihenfolge: R5 → R0 schreiben
  for(int i = 5; i >= 0; i--) {
    writeRegister(ADF4350_REG[i]);
    delay(10);
  }

  // Debug
  if( Debug == 1 ){
    Serial.print("Freq Set: "); Serial.print(freqHz / 1e3); Serial.println(" MHz");
    Serial.print("VCO: "); Serial.print(Fvco / 1e3); Serial.println(" MHz");
    Serial.print("INT="); Serial.print(INT);
    Serial.print(" FRAC="); Serial.println(FRAC);
    Serial.print("DIV: /"); Serial.println(divVal);
    Serial.print("\n");

    Serial.print("R0=0x"); Serial.println(ADF4350_REG[0], HEX);
    Serial.print("R1=0x"); Serial.println(ADF4350_REG[1], HEX);
    Serial.print("R2=0x"); Serial.println(ADF4350_REG[2], HEX);
    Serial.print("R3=0x"); Serial.println(ADF4350_REG[3], HEX);
    Serial.print("R4=0x"); Serial.println(ADF4350_REG[4], HEX);
    Serial.print("R5=0x"); Serial.println(ADF4350_REG[5], HEX);
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
