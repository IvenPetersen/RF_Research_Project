#include <Arduino.h>

#define BLOCK_SIZE 256       // Anzahl Samples pro Paket (größer = effizienter)
#define BLOCKS 16            // Ringpuffer-Größe (16*256=4096 Samples)

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE];
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0;

const uint32_t SAMPLE_RATE = 25000;  // Abtastrate
const uint32_t BAUD = 2000000;       // Native USB Baudrate

void setup() {
  SerialUSB.begin(BAUD);
  delay(2000); // Warte, bis Host verbunden ist

  analogReadResolution(12);
  pmc_enable_periph_clk(ID_ADC);
  ADC->ADC_CR = ADC_CR_SWRST; // Reset ADC
  ADC->ADC_MR = ADC_MR_PRESCAL(10) | ADC_MR_STARTUP_SUT64 | ADC_MR_TRACKTIM(2) | ADC_MR_FREERUN_ON;
  ADC->ADC_CHER = ADC_CHER_CH7;

  // Timer konfigurieren
  pmc_enable_periph_clk(ID_TC0);
  TC_Configure(TC0, 0, TC_CMR_TCCLKS_TIMER_CLOCK1 | TC_CMR_WAVE | TC_CMR_WAVSEL_UP_RC);
  uint32_t rc = (SystemCoreClock / 2) / SAMPLE_RATE;
  TC_SetRC(TC0, 0, rc);
  TC0->TC_CHANNEL[0].TC_IER = TC_IER_CPCS;
  NVIC_SetPriority(TC0_IRQn, 0);
  NVIC_EnableIRQ(TC0_IRQn);
  TC_Start(TC0, 0);
}

void loop() {
  static uint8_t outBlock[BLOCK_SIZE * 2]; // 2 Byte pro Sample

  // Prüfen, ob ein kompletter Block vorliegt
  while (samplesAvailable >= BLOCK_SIZE) {
    // Block aus dem Ringpuffer holen
    for (uint32_t i = 0; i < BLOCK_SIZE; i++) {
      uint16_t val = adcBuffer[readIndex++];
      if (readIndex >= BLOCKS * BLOCK_SIZE) readIndex = 0;
      samplesAvailable--;

      outBlock[2 * i]     = val & 0xFF;
      outBlock[2 * i + 1] = (val >> 8) & 0xFF;
    }

    // Ganzen Block in einem Rutsch senden
    SerialUSB.write(outBlock, sizeof(outBlock));
  }
}

void TC0_Handler() {
  TC_GetStatus(TC0, 0);
  uint16_t sample = ADC->ADC_CDR[7];
  adcBuffer[writeIndex++] = sample;
  if (writeIndex >= BLOCKS * BLOCK_SIZE) writeIndex = 0;
  if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
}