// config.h

#define DEBUG             1
#define PLL_PIN_LE        10
#define MOD_PIN_LE        11
#define SERIAL_BAUD_RATE  115200
#define SPI_SPEED         100000



//Do not Change if you Jon Snow (know nothing)!
#define PLL_PHASE       1 
#define PLL_F_2400_MHZ  0x00780000
#define PLL_F_2600_MHZ  0x00820000 
#define PLL_R1_DEFAULT  0x08008011
#define PLL_R2_DEFAULT  0x00004E42
#define PLL_R3_DEFAULT  0x000004B3
#define PLL_R4_DEFAULT  0x0085003C
#define PLL_R5_DEFAULT  0x00580005
#define PLL_BS          80u
#define PLL_REF_FREQ    10   // 10 MHz Reference
#define PLL_MOD_VALUE   4095


#define MOD_MASK_GAIN       0x1F
#define MOD_MASK_QDISABLE   0x20
#define MOD_R1_DEFAULT      0x3E
#define MOD_R2_DEFAULT      0x84
#define MOD_R3_DEFAULT      0x80
#define MOD_R4_DEFAULT      0x80
#define MOD_R5_DEFAULT      0x80
#define MOD_R6_DEFAULT      0x10
#define MOD_R7_DEFAULT      0x50
#define MOD_R8_DEFAULT      0x06
#define MOD_R9_DEFAULT      0x00