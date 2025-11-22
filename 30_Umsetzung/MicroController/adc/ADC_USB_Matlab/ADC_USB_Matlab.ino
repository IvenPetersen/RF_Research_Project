#include <Arduino.h>

#define BLOCK_SIZE 1024
#define BLOCKS 8

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE];
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0;

const uint32_t SAMPLE_RATE = 100000; // gewünschte Abtastrate
const uint32_t BAUD = 2000000;

void setup() {
  SerialUSB.begin(BAUD);
  delay(2000);

  analogReadResolution(12);
  pmc_enable_periph_clk(ID_ADC);

  // ADC Reset und Konfiguration
  ADC->ADC_CR = ADC_CR_SWRST;
  ADC->ADC_MR = ADC_MR_PRESCAL(10) | ADC_MR_STARTUP_SUT64 | ADC_MR_TRACKTIM(3); 
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
  // Solange genug Samples verfügbar sind, direkt aus Ringpuffer schreiben
  while (samplesAvailable >= BLOCK_SIZE) {
    uint32_t idx = readIndex;

    // Prüfen, ob Block bis zum Ende des Ringpuffers passt
    if (idx + BLOCK_SIZE <= BLOCKS * BLOCK_SIZE) {
      // Direkt schreiben
      SerialUSB.write((uint8_t*)&adcBuffer[idx], BLOCK_SIZE * 2);
    } else {
      // Block teilt sich über Ringpuffer-Ende → zwei Teilblöcke
      uint32_t firstPart = BLOCKS * BLOCK_SIZE - idx;
      SerialUSB.write((uint8_t*)&adcBuffer[idx], firstPart * 2);
      SerialUSB.write((uint8_t*)&adcBuffer[0], (BLOCK_SIZE - firstPart) * 2);
    }

    // readIndex und samplesAvailable aktualisieren
    readIndex = (readIndex + BLOCK_SIZE) % (BLOCKS * BLOCK_SIZE);
    samplesAvailable -= BLOCK_SIZE;
  }
}

// Timer Interrupt: ADC Sample holen (ohne Mittelung)
void TC0_Handler() {
    TC_GetStatus(TC0, 0);

    // Einfacher ADC-Wert
    ADC->ADC_CR = ADC_CR_START;
    while ((ADC->ADC_ISR & ADC_ISR_EOC7) == 0);
    uint16_t sample = ADC->ADC_CDR[7];

    // In Ringpuffer schreiben
    adcBuffer[writeIndex++] = sample;
    if (writeIndex >= BLOCKS * BLOCK_SIZE) writeIndex = 0;
    if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
}