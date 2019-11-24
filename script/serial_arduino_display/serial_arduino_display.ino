#include <MemoryFree.h>
#include <SoftwareSerial.h>
#include <Wire.h>
#include <SPI.h>

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_ST7735.h>

#include <stdio.h>

#define PI_BYTES 6
#define DEBUG 1

#define RX 2
#define TX 3

#define OLED_I2C_ADDR 0x3C
#define OLED_RESET 4
#define OLED_WIDTH 128
#define OLED_HEIGHT 64

/* Colour TFT Pins
 *
 * Name     Uno_Pin     ATMega-328P_Pin
 **************************************
 * SCL      13          13
 * SDA      17          17
 * RST      9           15
 * DC       8           14
 * CS       10          16
*/

#define TFT_RST 9
#define TFT_DC  8
#define TFT_CS  10

#define TFT_LINE_1      0
#define TFT_LINE_2      16
#define TFT_LINE_3      32
#define TFT_LINE_4      48
#define TFT_LINE_5      64
#define TFT_LINE_6      80
#define TFT_LINE_7      96
#define TFT_LINE_8      112

#define TFT_COL_0   0
#define TFT_COL_1   12
#define TFT_COL_2   24
#define TFT_COL_3   36
#define TFT_COL_4   48
#define TFT_COL_5   60
#define TFT_COL_6   72
#define TFT_COL_7   84
#define TFT_COL_8   96
#define TFT_COL_9   108
#define TFT_COL_10  120
#define TFT_COL_11  132
#define TFT_COL_12  144

#define TFT_STATUS_COL  60

// security bit locations

#define BIT_BSMT    0
#define BIT_DOOR    1
#define BIT_MAIN    2
#define BIT_ALRM    6

// object instantiation

SoftwareSerial pi(RX, TX);
Adafruit_SSD1306 screen(OLED_WIDTH, OLED_HEIGHT, &Wire, OLED_RESET);
Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_RST);

unsigned long memStartTime = millis();
unsigned long memDelay = 1000;

void displaySysInfo (uint8_t *sysInfo) {

    char cpu[16], mem[16], cTemp[16];

    sprintf(cpu, "CPU:  %d%%    ", sysInfo[0]);
    sprintf(mem, "RAM:  %d%%    ", sysInfo[1]);
    sprintf(cTemp, "TEMP: %d F  ", sysInfo[2]);

    screen.clearDisplay();

    /* CPU percent */

    screen.setCursor(0, 0);

    screen.print(F("CPU %: "));
    screen.print(sysInfo[0]);

    /* Memory percent */

    screen.setCursor(0, 16);

    screen.print(F("RAM %: "));
    screen.print(sysInfo[1]);

    /* CPU temperature */

    screen.setCursor(0, 32);

    screen.print(F("TMP F: "));
    screen.print(sysInfo[2]);

    uint16_t testNum = (sysInfo[3] << 8 ) | (sysInfo[4] & 0xff);

    if (testNum != 0) {
        
        screen.setCursor(0, 48);

        if (testNum < 1000) {
            screen.print(F("TEST#: "));
            screen.print(testNum);
        }
        else if (testNum >= 1000 && testNum < 10000) {
            screen.print(F("TST#: "));
            screen.print(testNum);
        }
        else {
            screen.print(F("TST: "));
            screen.print(testNum);
        }
    }

    screen.display();
}

void serialPrintSysInfo(uint8_t *sysInfo) {

    Serial.println(F("System Info"));
    Serial.print(F("CPU:  "));
    Serial.print(sysInfo[0]);
    Serial.println(F("%"));
    Serial.print(F("RAM:  "));
    Serial.print(sysInfo[1]);
    Serial.println(F("%"));
    Serial.print(F("TEMP: "));
    Serial.print(sysInfo[2]);
    Serial.println(F("F\n"));

    uint16_t testNum = (sysInfo[3] << 8 ) | (sysInfo[4] & 0xff);

    Serial.print(F("TEST: "));
    Serial.println(testNum);

}

void setup() {
    Serial.begin(9600);

    delay(2000);
    
    // Pi comms setup

    pi.begin(9600);
        
    // OLED display setup

    screen.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR);
    
    screen.clearDisplay();
    screen.display();

    screen.setTextSize(2);
    screen.setTextColor(WHITE);
    screen.setCursor(0, 0);
    
    // colour TFT setup

    tft.initR(INITR_144GREENTAB);

    tft.fillScreen(ST77XX_BLACK);
    tft.setTextSize(2);

    tft.setCursor(0, TFT_LINE_1);
    tft.print(F("BSMT: "));

    tft.setCursor(0, TFT_LINE_2);
    tft.print(F("DOOR: "));

    tft.setCursor(0, TFT_LINE_3);
    tft.print(F("MAIN: "));

    tft.setCursor(0, TFT_LINE_4);
    tft.print(F("ALRM: "));

    tft.setCursor(0, TFT_LINE_5);
    tft.print(F("FMEM: "));
}

unsigned long test = 0;

void processData (void) {

    uint8_t sysInfo[PI_BYTES-1];
    byte securityByte = 0;

    if (pi.available() == PI_BYTES) {

        securityByte = pi.read();
        
        for (uint8_t i = 0; i < PI_BYTES-1; i++) {
            sysInfo[i] = pi.read();
        }

        int freeMem = freeMemory();
     
        if (DEBUG) {
            serialPrintSysInfo(sysInfo);
            Serial.print(F("fmem: "));
            Serial.println(freeMem);
            Serial.print(F("SEC BYTE: "));
            Serial.println(securityByte);
        }

        displaySysInfo(sysInfo);
        displaySecurityInfo(securityByte, freeMem);
    }
}

void displaySecurityInfo (uint8_t secByte, int freeMem){

    const uint16_t fg_colour[2] = { ST77XX_GREEN, ST77XX_WHITE };
    const uint16_t bg_colour[2] = { ST77XX_BLACK, ST77XX_RED };
    char* secText[2] = { "OK ", "NOK" };
    
    tft.setCursor(TFT_STATUS_COL, TFT_LINE_1);
    uint8_t bsmt_state = (secByte >> BIT_BSMT) & 1;
    tft.setTextColor(fg_colour[bsmt_state], bg_colour[bsmt_state]);
    tft.print(secText[bsmt_state]);

    tft.setCursor(TFT_STATUS_COL, TFT_LINE_2);
    uint8_t door_state = (secByte >> BIT_DOOR) & 1;
    tft.setTextColor(fg_colour[door_state], bg_colour[door_state]);
    tft.print(secText[door_state]);

    tft.setCursor(TFT_STATUS_COL, TFT_LINE_3);
    uint8_t main_state = (secByte >> BIT_MAIN) & 1;
    tft.setTextColor(fg_colour[main_state], bg_colour[main_state]);
    tft.print(secText[main_state]);

    tft.setCursor(TFT_STATUS_COL, TFT_LINE_4);
    uint8_t alrm_state = (secByte >> BIT_ALRM) & 1;
    tft.setTextColor(fg_colour[alrm_state], bg_colour[alrm_state]);
    tft.print(secText[alrm_state]);

    tft.setCursor(TFT_STATUS_COL, TFT_LINE_5);
    tft.setTextColor(ST77XX_WHITE, ST77XX_BLUE);
    tft.print(freeMem);

    tft.setCursor(0, TFT_LINE_7);
    tft.setTextColor(ST77XX_MAGENTA, ST77XX_BLACK);
    tft.print(F("Sec Byte:"));

    tft.setCursor(0, TFT_LINE_8);
    tft.setTextColor(ST77XX_YELLOW, ST77XX_ORANGE);

    for (uint8_t i = 1 << 7; i > 0; i = i / 2){ 
        (secByte & i)? tft.print(1): tft.print(0); 
    }
}

void loop() {
    if (DEBUG){
        if (millis() - memStartTime >= memDelay){
            Serial.print(F("Free Memory: "));
            Serial.println(freeMemory());
            memStartTime = millis();
        }
    }
    processData();
}


