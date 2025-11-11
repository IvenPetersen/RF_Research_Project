#include <Arduino.h>

#define NWAVE 64
#define RC 420

volatile uint8_t sptr = 0;
volatile bool ready_for_new_data = true;

uint32_t Sinewave[2][NWAVE];

void dac_setup() {
  PMC->PMC_PCER1 |= (1 << (DACC_INTERFACE_ID - 32));
  DACC->DACC_CR = DACC_CR_SWRST;

  DACC->DACC_MR = DACC_MR_TRGEN_EN
                | DACC_MR_TRGSEL(1)
                | DACC_MR_WORD
                | DACC_MR_TAG_EN
                | DACC_MR_MAXS
                | DACC_MR_STARTUP_8;

  DACC->DACC_CHER = DACC_CHER_CH0 | DACC_CHER_CH1;

  DACC->DACC_TPR  = (uint32_t)Sinewave[0];
  DACC->DACC_TCR  = NWAVE;
  DACC->DACC_TNPR = (uint32_t)Sinewave[1];
  DACC->DACC_TNCR = NWAVE;

  dacc_enable_interrupt(DACC, DACC_IER_ENDTX);
  NVIC_EnableIRQ(DACC_IRQn);

  DACC->DACC_PTCR = DACC_PTCR_TXTEN;
}

void timer_setup() {
  pmc_enable_periph_clk(ID_TC0);
  TcChannel *tc = &TC0->TC_CHANNEL[0];

  tc->TC_CCR = TC_CCR_CLKDIS;
  tc->TC_IDR = 0xFFFFFFFF;
  tc->TC_SR;
  tc->TC_CMR = TC_CMR_TCCLKS_TIMER_CLOCK1 | TC_CMR_WAVE |
               TC_CMR_WAVSEL_UP_RC | TC_CMR_ACPA_SET | TC_CMR_ACPC_CLEAR;
  tc->TC_RC = RC;
  tc->TC_RA = RC / 2;
  tc->TC_CCR = TC_CCR_CLKEN | TC_CCR_SWTRG;
}

void setup() {
  SerialUSB.begin(230400);
  dac_setup();
  timer_setup();

  for (int i = 0; i < NWAVE; i++) {
    Sinewave[0][i] = 0x08000800;
    Sinewave[1][i] = 0x08000800;
  }
}

void DACC_Handler() {
  if (DACC->DACC_ISR & DACC_ISR_ENDTX) {
    sptr ^= 1;
    DACC->DACC_TNPR = (uint32_t)Sinewave[sptr];
    DACC->DACC_TNCR = NWAVE;
    ready_for_new_data = true;
    //SerialUSB.write('R'); // „Ready“ – Host darf neue Daten schicken
  }
}

void loop() {
  static uint8_t rxbuf[2 * NWAVE];  // 2 Kanäle * NWAVE Samples
  static int idx = 0;

  if (ready_for_new_data) {
    // Nur lesen, wenn genug Bytes da sind
    if (SerialUSB.available() >= 2 * NWAVE) {

      SerialUSB.readBytes((char*)rxbuf, 2 * NWAVE);  // Blockweise lesen

      // Rohdaten → DAC-Format wandeln
      for (idx = 0; idx < NWAVE; idx++) {
        uint32_t d0 = rxbuf[2 * idx];       // Kanal 0
        uint32_t d1 = rxbuf[2 * idx + 1];   // Kanal 1

        // DAC-Paket (12 Bit + Tag für CH1)
        Sinewave[!sptr][idx] = (d0 << 4) | (d1 << 20) | (1 << 28);
      }

      ready_for_new_data = false;  // DMA arbeitet, warten auf nächsten Interrupt
    }
  }
}
