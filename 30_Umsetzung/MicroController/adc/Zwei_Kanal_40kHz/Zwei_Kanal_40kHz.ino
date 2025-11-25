#include <Arduino.h>

#define BLOCK_SIZE 512        // Samples pro Kanal
#define BLOCKS 8
#define DELTA_ARRAY 1024      // für Timing-Statistik

volatile uint16_t adcBuffer[BLOCKS * BLOCK_SIZE * 2]; // Interleaved I/Q
volatile uint32_t writeIndex = 0;
volatile uint32_t readIndex = 0;
volatile uint32_t samplesAvailable = 0; // Anzahl I/Q-Paare
volatile uint32_t overflowCounter = 0;

volatile uint32_t lastSampleTime = 0;
volatile uint32_t sampleDelta = 0;
volatile uint32_t deltaHistory[DELTA_ARRAY];
volatile uint32_t deltaIndex = 0;

const uint32_t SAMPLE_RATE = 80000; // Gesamtrate (I+Q = 80 kHz -> 40 kHz pro Kanal)
const uint32_t BAUD_USB = 2000000;
const uint32_t BAUD_DEBUG = 115200;

volatile bool sampleI = true; // Kanal wechseln

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
    ADC->ADC_CHER = ADC_CHER_CH6 | ADC_CHER_CH7; // I = CH7, Q = CH6

    pmc_enable_periph_clk(ID_TC0);
    TC_Configure(TC0, 0, TC_CMR_TCCLKS_TIMER_CLOCK1 | TC_CMR_WAVE | TC_CMR_WAVSEL_UP_RC);
    uint32_t rc = (SystemCoreClock / 2) / SAMPLE_RATE; 
    TC_SetRC(TC0, 0, rc);
    TC0->TC_CHANNEL[0].TC_IER = TC_IER_CPCS;
    NVIC_SetPriority(TC0_IRQn, 0);
    NVIC_EnableIRQ(TC0_IRQn);
    TC_Start(TC0, 0);

    Serial.println("Setup abgeschlossen.");
}

void loop() {
    // Senden kompletter I/Q-Blöcke
    while (samplesAvailable >= BLOCK_SIZE) {
        uint32_t idx = readIndex * 2; // Interleaved
        if (idx + BLOCK_SIZE*2 <= BLOCKS * BLOCK_SIZE * 2) {
            SerialUSB.write((uint8_t*)&adcBuffer[idx], BLOCK_SIZE*2*2);
        } else {
            uint32_t firstPart = BLOCKS*BLOCK_SIZE*2 - idx;
            SerialUSB.write((uint8_t*)&adcBuffer[idx], firstPart*2);
            SerialUSB.write((uint8_t*)&adcBuffer[0], (BLOCK_SIZE*2 - firstPart)*2);
        }
        readIndex = (readIndex + BLOCK_SIZE) % BLOCKS*BLOCK_SIZE;
        samplesAvailable -= BLOCK_SIZE;
    }

    // Debug-Ausgabe alle 500 ms
    static uint32_t lastDebugPrint = 0;
    if (millis() - lastDebugPrint > 500) {
        lastDebugPrint = millis();
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
        Serial.print(" | Min/Max/Median Delta = "); Serial.print(minDelta);
        Serial.print("/"); Serial.print(maxDelta);
        Serial.print("/"); Serial.println(medianDelta);
    }
}

// Timer Interrupt
void TC0_Handler() {
    TC_GetStatus(TC0, 0);

    ADC->ADC_CR = ADC_CR_START;
    while ((ADC->ADC_ISR & (sampleI ? ADC_ISR_EOC7 : ADC_ISR_EOC6)) == 0);

    uint16_t sample = sampleI ? ADC->ADC_CDR[7] : ADC->ADC_CDR[6];

    if (samplesAvailable >= BLOCKS * BLOCK_SIZE) {
        overflowCounter++;
    }

    uint32_t now = micros();
    sampleDelta = now - lastSampleTime;
    lastSampleTime = now;

    deltaHistory[deltaIndex++] = sampleDelta;
    if (deltaIndex >= DELTA_ARRAY) deltaIndex = 0;

    // In Buffer schreiben (Interleaved)
    adcBuffer[writeIndex++] = sample;

    if (!sampleI) { // nach Q-Sample
        if (samplesAvailable < BLOCKS * BLOCK_SIZE) samplesAvailable++;
    }

    sampleI = !sampleI; // Kanal wechseln

    if (writeIndex >= BLOCKS * BLOCK_SIZE * 2) writeIndex = 0;
}
