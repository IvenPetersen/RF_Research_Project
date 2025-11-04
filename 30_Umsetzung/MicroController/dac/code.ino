#include <Arduino.h>


#define NWAVE 256

volatile uint16_t sptr = 0;  // Zeiger für Ping-Pong DMA Buffer

// Zwei Ping-Pong-Buffers für den DAC
uint32_t Sinewave[2][NWAVE];

// ----- DAC Setup -----
void dac_setup() {


  PMC->PMC_PCER1 |= (1 << (DACC_INTERFACE_ID - 32));  // DAC-Takt aktivieren
  DACC->DACC_CR = DACC_CR_SWRST;
  DACC->DACC_MR |= DACC_MR_TRGEN_EN  // Timer-Trigger
                   | DACC_MR_TRGSEL(1)
                   | DACC_MR_WORD                   // Ganzes Wort (16-bit) Transfer
                   | DACC_MR_TAG_EN                 // Channel-Tag aktiviert
                   | DACC_MR_MAXS                   // Max Speed Mode
                   | DACC_MR_STARTUP_8;             // Startup time
  DACC->DACC_CHER = DACC_CHER_CH0 | DACC_CHER_CH1;  // DAC0 + DAC1 aktivieren

  // ----- DMA / PDC Setup -----
  // Pointer auf ersten Buffer
  DACC->DACC_TPR = (uint32_t)Sinewave[0][0];  // Transmit Pointer Register
  DACC->DACC_TCR = NWAVE;                  // Anzahl Werte im Buffer

  // Pointer auf zweiten Buffer (Ping-Pong)
  DACC->DACC_TNPR = (uint32_t)Sinewave[1][0];  // Next Transmit Pointer Register
  DACC->DACC_TNCR = NWAVE;                  // Anzahl Werte im Next Buffer

  // Interrupt aktivieren
  dacc_enable_interrupt(DACC, DACC_IER_ENDTX);  // Interrupt wenn Buffer fertig übertragen
  NVIC_EnableIRQ(DACC_IRQn);                    // NVIC DAC Interrupt aktivieren

  // PDC TX enable → startet DMA-Übertragung
  DACC->DACC_PTCR = DACC_PTCR_TXTEN;  // PDC Transfer Enable
}

// ----- Timer Setup -----
void timer_setup() {


  // 1. Timer Clock aktivieren
  pmc_enable_periph_clk(ID_TC0);  // Timer0 Clock aktivieren

  TcChannel *tc = &(TC0->TC_CHANNEL)[0];  // Pointer auf Channel 0

  // 2. Timer stoppen und Interrupts löschen
  tc->TC_CCR = TC_CCR_CLKDIS;  // Timer Clock disable
  tc->TC_IDR = 0xFFFFFFFF;     // Alle Interrupts deaktivieren
  tc->TC_SR;                   // Statusregister lesen → löscht Pending Flags

  // 3. Timer Mode konfigurieren
  tc->TC_CMR = TC_CMR_TCCLKS_TIMER_CLOCK1 |  // Clock = MCK/2 = 42 MHz
               TC_CMR_WAVE |                 // Waveform Mode
               TC_CMR_WAVSEL_UP_RC |         // Zählen bis RC, dann Reset
               TC_CMR_ACPA_SET |             // TIOA bei RA → HIGH
               TC_CMR_ACPC_CLEAR;            // TIOA bei RC → LOW

  // 4. Perioden einstellen
  tc->TC_RC = 8400;
  tc->TC_RA = 4200;

  // 5. Timer starten
  tc->TC_CCR = TC_CCR_CLKEN | TC_CCR_SWTRG;  // Clock enable + Software Trigger
}

volatile int idx = 0;
// ----- DAC Interrupt Handler -----
void DACC_Handler() {
  // Prüfen ob DMA Buffer fertig
  if ((dacc_get_interrupt_status(DACC) & DACC_ISR_ENDTX) == DACC_ISR_ENDTX) {
    sptr ^= 1;                                   // Ping-Pong Buffer wechseln
    DACC->DACC_TNPR = (uint32_t)Sinewave[sptr];  // Nächsten Buffer setzen
    DACC->DACC_TNCR = NWAVE;                     // Buffer Länge setzen

    idx = 0;
  }
}

// ----- Arduino Setup -----
void setup() {
  dac_setup();    // DAC initialisieren
  timer_setup();  // Timer initialisieren

  SerialUSB.begin(230400);

  for (int i = 0; i < NWAVE; i++) {
    Sinewave[0][i] = 0;
    Sinewave[1][i] = 0;
  }
}

void loop() {
  while (1) {
    while (idx++ < NWAVE) {
      Sinewave[!sptr][idx] = (SerialUSB.read() << 4) | (1 << 28) | (SerialUSB.read() << 20);
    }
      
  }
}
