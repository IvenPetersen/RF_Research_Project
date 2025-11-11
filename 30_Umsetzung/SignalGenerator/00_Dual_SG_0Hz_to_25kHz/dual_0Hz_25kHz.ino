#include <Arduino.h>

#define M 1
#define USB_SIZE 128
#define NWAVE (USB_SIZE * M)
#define RC (420 / M) 

volatile uint8_t sptr = 0;
volatile bool ready_for_new_data = true;

uint32_t Sinewave[3][NWAVE];

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

  DACC->DACC_TPR = (uint32_t)&Sinewave[0][0];
  DACC->DACC_TCR = NWAVE;

  DACC->DACC_TNPR = (uint32_t)&Sinewave[1][0];
  DACC->DACC_TNCR = NWAVE;

  dacc_enable_interrupt(DACC, DACC_IER_ENDTX);
  NVIC_EnableIRQ(DACC_IRQn);

  DACC->DACC_PTCR = DACC_PTCR_TXTEN;
}

TcChannel *tc = &TC0->TC_CHANNEL[0];

void timer_setup() {

  pmc_enable_periph_clk(ID_TC0);  

  tc->TC_CCR = TC_CCR_CLKDIS;
  tc->TC_IDR = 0xFFFFFFFF;
  tc->TC_SR;
  tc->TC_CMR = TC_CMR_TCCLKS_TIMER_CLOCK1 | TC_CMR_WAVE | TC_CMR_WAVSEL_UP_RC | TC_CMR_ACPA_SET | TC_CMR_ACPC_CLEAR;
  tc->TC_RC = RC;
  tc->TC_RA = RC / 2;
  tc->TC_CCR = TC_CCR_CLKEN | TC_CCR_SWTRG;
}

static uint8_t rxbuf[2 * USB_SIZE];  // 2 Kanäle * NWAVE Samples
static int idx = 0;
int i = 0;

void setup() {

  SerialUSB.begin(230400);
  Serial.begin(115200);


  for (int i = 0; i < NWAVE; i++) {
    Sinewave[0][i] = 0x08000800 | (1 << 28);
    Sinewave[1][i] = 0x08000800 | (1 << 28);
    Sinewave[2][i] = 0x08000800 | (1 << 28);
  }

  while (!SerialUSB) {
    ;  // do nothing, nur warten
  }

  while (SerialUSB.available() > 0) SerialUSB.read();

  SerialUSB.write('R');

  dac_setup();
  timer_setup();
  
}

void DACC_Handler() {

  if (DACC->DACC_ISR & DACC_ISR_ENDTX) {

    if (ready_for_new_data == true) {

      DACC->DACC_TNPR = (uint32_t)&Sinewave[2][0];
      DACC->DACC_TNCR = NWAVE;

    } else {
      sptr = (sptr == 1) ? 0 : 1;
      DACC->DACC_TNPR = (uint32_t)&Sinewave[sptr][0];
      DACC->DACC_TNCR = NWAVE;

      ready_for_new_data = true;
    }
  }
}

void loop() {
  static int len = 0;

  if (ready_for_new_data) {
    len = SerialUSB.readBytes((char *)rxbuf, 2 * USB_SIZE);  // Blockweise lesen
    i = 0;

    if (len == 0)
    {
      Serial.println("E");
      return;
    }
      

    // Rohdaten → DAC-Format wandeln
    for (idx = 0; idx < NWAVE; idx += M) {

      // DAC-Paket (12 Bit + Tag für CH1)
      Sinewave[!sptr][idx] = (rxbuf[i++] << 4) | (rxbuf[i++] << 20) | (1 << 28);
    }

    ready_for_new_data = false;  // DMA arbeitet, warten auf nächsten Interrupt
  }
}