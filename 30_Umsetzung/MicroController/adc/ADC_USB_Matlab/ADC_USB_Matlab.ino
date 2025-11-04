#include <Arduino.h>

#define BLOCK_SIZE 64        // Muss zu MATLAB passen
#define BLOCKS 64            // Ringpuffer-Größe (64*64=4096 Samples)

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE];
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0;

const uint32_t SAMPLE_RATE = 250000;  // Timer-Abtastrate (250 kHz)
const uint32_t DOWNSAMPLE_FACTOR = 10; // Downsampling auf 25 kHz
const uint32_t BAUD = 2000000;        // Native USB Baudrate

volatile uint32_t downsampleCounter = 0; // Zähler für Downsampling

void setup() {
  // --- LED ---
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  // --- USB starten ---
  SerialUSB.begin(BAUD);
  delay(2000); // Warte 2s, bis Host verbunden ist

  // --- ADC konfigurieren (Free-Running, 12-bit, Kanal 7 = A0) ---
  analogReadResolution(12);
  pmc_enable_periph_clk(ID_ADC);
  ADC->ADC_CR = ADC_CR_SWRST;             // Reset ADC
  ADC->ADC_MR = ADC_MR_PRESCAL(10)       // Prescaler
              | ADC_MR_STARTUP_SUT64
              | ADC_MR_TRACKTIM(2)
              | ADC_MR_FREERUN_ON;        // Free-Running Mode
  ADC->ADC_CHER = ADC_CHER_CH7;          // Kanal 7 aktivieren

  // --- Timer konfigurieren (TC0, Channel 0) ---
  pmc_enable_periph_clk(ID_TC0);
  TC_Configure(TC0, 0,
               TC_CMR_TCCLKS_TIMER_CLOCK1 |  // MCK/2
               TC_CMR_WAVE |
               TC_CMR_WAVSEL_UP_RC);

  uint32_t rc = (SystemCoreClock / 2) / SAMPLE_RATE;
  TC_SetRC(TC0, 0, rc);

  TC0->TC_CHANNEL[0].TC_IER = TC_IER_CPCS; // Interrupt on RC
  TC0->TC_CHANNEL[0].TC_IDR = ~TC_IER_CPCS;

  NVIC_SetPriority(TC0_IRQn, 0);
  NVIC_EnableIRQ(TC0_IRQn);

  TC_Start(TC0, 0);
}

void loop() {
  // --- Datenpakete über USB senden ---
  while (samplesAvailable >= BLOCK_SIZE) {
    for (uint32_t i = 0; i < BLOCK_SIZE; i++) {
      uint16_t val = adcBuffer[readIndex++];
      if (readIndex >= BLOCKS * BLOCK_SIZE) readIndex = 0;
      samplesAvailable--;

      SerialUSB.write(val & 0xFF);
      SerialUSB.write((val >> 8) & 0xFF);
    }
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN)); // Blink als Aktivitätsanzeige
  }
}

// --- Timer Interrupt: ADC Sampling + Downsampling ---
void TC0_Handler() {
  TC_GetStatus(TC0, 0);  // Interrupt-Flag löschen

  // --- Wert direkt aus Free-Running ADC lesen ---
  uint16_t sample = ADC->ADC_CDR[7]; // Kanal 7 = A0

  // --- Downsampling ---
  downsampleCounter++;
  if (downsampleCounter >= DOWNSAMPLE_FACTOR) {
    downsampleCounter = 0;

    adcBuffer[writeIndex++] = sample;
    if (writeIndex >= BLOCKS * BLOCK_SIZE) writeIndex = 0;

    if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
  }
}