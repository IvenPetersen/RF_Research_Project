#include <Arduino.h>

#define BLOCK_SIZE 512
#define BLOCKS 8

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE];
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0;

const uint32_t SAMPLE_RATE = 25000; // gewünschte Abtastrate
const uint32_t BAUD = 2000000;

void setup() {
  SerialUSB.begin(BAUD);
  delay(2000);

  analogReadResolution(12);
  pmc_enable_periph_clk(ID_ADC);

  // ADC Reset und Konfiguration
  ADC->ADC_CR = ADC_CR_SWRST;
  ADC->ADC_MR = ADC_MR_PRESCAL(10) | ADC_MR_STARTUP_SUT64 | ADC_MR_TRACKTIM(3); 
  // TRACKTIM etwas erhöhen für stabilere Abtastung
  ADC->ADC_CHER = ADC_CHER_CH7;

  // Timer für exakte Abtastung (Interrupt)
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
  static uint8_t outBlock[BLOCK_SIZE * 2];

  while (samplesAvailable >= BLOCK_SIZE) {
    for (uint32_t i = 0; i < BLOCK_SIZE; i++) {
      uint16_t val = adcBuffer[readIndex++];
      if (readIndex >= BLOCKS * BLOCK_SIZE) readIndex = 0;
      samplesAvailable--;

      outBlock[2*i] = val & 0xFF;
      outBlock[2*i+1] = (val >> 8) & 0xFF;
    }
    SerialUSB.write(outBlock, sizeof(outBlock));
  }
}

// Timer Interrupt: ADC Sample holen
void TC0_Handler() {
  TC_GetStatus(TC0, 0);

  // --- Exakte Sampling-Logik ---
  // Oversampling: 4 Samples mitteln für besseres SNR
  uint32_t sum = 0;
  const uint8_t OVERSAMPLE = 4;
  for (uint8_t j = 0; j < OVERSAMPLE; j++) {
    ADC->ADC_CR = ADC_CR_START;       // ADC starten
    while ((ADC->ADC_ISR & ADC_ISR_EOC7) == 0); // Warten auf End-of-Conversion
    sum += ADC->ADC_CDR[7];
  }
  uint16_t sample = sum / OVERSAMPLE;  // Mittelwert

  adcBuffer[writeIndex++] = sample;
  if (writeIndex >= BLOCKS * BLOCK_SIZE) writeIndex = 0;
  if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
}
