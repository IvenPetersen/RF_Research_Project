#include <Arduino.h>

#define BLOCK_SIZE 1024
#define BLOCKS 8
#define DELTA_ARRAY 1024  // Anzahl Deltas für Statistik

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE];
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0;

volatile uint32_t overflowCounter = 0;   // Overflow-Zähler
volatile uint32_t lastSampleTime = 0;     // letzte Sample-Zeit
volatile uint32_t sampleDelta = 0;        // Delta zum vorherigen Sample

volatile uint32_t deltaHistory[DELTA_ARRAY];
volatile uint32_t deltaIndex = 0;

const uint32_t SAMPLE_RATE = 80000;    // 100 kHz
const uint32_t BAUD_USB = 2000000;      // Messdaten
const uint32_t BAUD_DEBUG = 115200;     // Debug-Ausgabe

uint32_t lastDebugPrint = 0;

void setup() {
  Serial.begin(BAUD_DEBUG);
  while (!Serial) {;}

  SerialUSB.begin(BAUD_USB);
  delay(2000);

  Serial.println("Debug-Port OK");
  Serial.println("Starte System...");

  analogReadResolution(12);
  pmc_enable_periph_clk(ID_ADC);

  ADC->ADC_CR = ADC_CR_SWRST;
  ADC->ADC_MR = ADC_MR_PRESCAL(10) | ADC_MR_STARTUP_SUT64 | ADC_MR_TRACKTIM(3);
  ADC->ADC_CHER = ADC_CHER_CH7;

  pmc_enable_periph_clk(ID_TC0);
  TC_Configure(TC0, 0, TC_CMR_TCCLKS_TIMER_CLOCK1 |
                        TC_CMR_WAVE |
                        TC_CMR_WAVSEL_UP_RC);

  uint32_t rc = (SystemCoreClock / 2) / SAMPLE_RATE;
  TC_SetRC(TC0, 0, rc);

  TC0->TC_CHANNEL[0].TC_IER = TC_IER_CPCS;
  NVIC_SetPriority(TC0_IRQn, 0);
  NVIC_EnableIRQ(TC0_IRQn);

  TC_Start(TC0, 0);

  Serial.println("Setup abgeschlossen.");
}

void loop() {
  // Messdaten senden, wenn Block bereit
  while (samplesAvailable >= BLOCK_SIZE) {
    uint32_t idx = readIndex;

    uint32_t t0 = micros();
    if (idx + BLOCK_SIZE <= BLOCKS * BLOCK_SIZE) {
      SerialUSB.write((uint8_t*)&adcBuffer[idx], BLOCK_SIZE * 2);
    } else {
      uint32_t firstPart = BLOCKS * BLOCK_SIZE - idx;
      SerialUSB.write((uint8_t*)&adcBuffer[idx], firstPart * 2);
      SerialUSB.write((uint8_t*)&adcBuffer[0], (BLOCK_SIZE - firstPart) * 2);
    }
    uint32_t usbWriteTime = micros() - t0;

    readIndex = (readIndex + BLOCK_SIZE) % (BLOCKS * BLOCK_SIZE);
    samplesAvailable -= BLOCK_SIZE;

    // Optional: USB-Write-Time kann für Debug genutzt werden
    (void)usbWriteTime; 
  }

  // Debug-Ausgabe alle 500 ms
  if (millis() - lastDebugPrint > 500) {
    lastDebugPrint = millis();

    // Delta-Statistik berechnen
    uint32_t minDelta = 0xFFFFFFFF;
    uint32_t maxDelta = 0;
    uint64_t sum = 0;
    for (uint32_t i = 0; i < DELTA_ARRAY; i++) {
      uint32_t d = deltaHistory[i];
      if (d < minDelta) minDelta = d;
      if (d > maxDelta) maxDelta = d;
      sum += d;
    }
    uint32_t medianDelta = sum / DELTA_ARRAY;

    Serial.print("Overflow = "); Serial.print(overflowCounter);
    Serial.print(" | SamplesAvailable = "); Serial.print(samplesAvailable);
    Serial.print(" | Sample Delta = "); Serial.print(sampleDelta);
    Serial.print(" | Min/Max/Median Delta = ");
    Serial.print(minDelta); Serial.print("/");
    Serial.print(maxDelta); Serial.print("/");
    Serial.println(medianDelta);
  }
}

void TC0_Handler() {
  TC_GetStatus(TC0, 0);

  ADC->ADC_CR = ADC_CR_START;
  while ((ADC->ADC_ISR & ADC_ISR_EOC7) == 0);

  uint16_t sample = ADC->ADC_CDR[7];

  // Overflow prüfen
  if (samplesAvailable >= BLOCKS * BLOCK_SIZE) {
    overflowCounter++;
  }

  // Sample-Zeit messen
  uint32_t now = micros();
  sampleDelta = now - lastSampleTime;
  lastSampleTime = now;

  // Delta-Historie speichern
  deltaHistory[deltaIndex++] = sampleDelta;
  if (deltaIndex >= DELTA_ARRAY) deltaIndex = 0;

  // Sample in Ringpuffer schreiben
  adcBuffer[writeIndex++] = sample;
  if (writeIndex >= BLOCKS * BLOCK_SIZE) writeIndex = 0;

  if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
}
