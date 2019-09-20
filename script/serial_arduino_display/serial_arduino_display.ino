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

#define TFT_SEC_LINE_1      0
#define TFT_SEC_LINE_2      16
#define TFT_SEC_LINE_3      32
#define TFT_SEC_LINE_4      48

#define TFT_SEC_STATUS_COL  60

// object instantiation

SoftwareSerial pi(RX, TX);
Adafruit_SSD1306 screen(OLED_WIDTH, OLED_HEIGHT, &Wire, OLED_RESET);
Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_RST);

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

    // Pi comms setup

    pi.begin(9600);

    // OLED display setup

    if (!screen.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
        Serial.println(F("I2C OLED attach failure..."));
        for (;;);
    }

    screen.clearDisplay();
    screen.display();

    screen.setTextSize(2);
    screen.setTextColor(WHITE);
    screen.setCursor(0, 0);

    // colour TFT setup

    tft.initR(INITR_144GREENTAB);

    tft.fillScreen(ST77XX_BLACK);
    tft.setTextSize(2);

    tft.setCursor(0, TFT_SEC_LINE_1);
    tft.print(F("BSMT: "));

    tft.setCursor(0, TFT_SEC_LINE_2);
    tft.print(F("DOOR: "));

    tft.setCursor(0, TFT_SEC_LINE_3);
    tft.print(F("MAIN: "));

    tft.setCursor(0, TFT_SEC_LINE_4);
    tft.print(F("ALRM: "));
}

void processData (void) {

    uint8_t sysInfo[PI_BYTES-1];
    uint8_t securityByte = 0;

    if (pi.available() == PI_BYTES) {
        securityByte = pi.read();

        for (uint8_t i = 0; i < PI_BYTES-1; i++) {
            sysInfo[i] = pi.read();
        }

        securityByte = pi.read();
        
        for (uint8_t i = 0; i < PI_BYTES-1; i++) {
            sysInfo[i] = pi.read();
        }
        
        if (DEBUG) {
            serialPrintSysInfo(sysInfo);
            Serial.print(F("SEC BYTE: "));
            Serial.println(securityByte);
        }

        displaySysInfo(sysInfo);
        displaySecurityInfo(securityByte);
    }
}

void displaySecurityInfo (uint8_t secByte){

    tft.setCursor(TFT_SEC_STATUS_COL, TFT_SEC_LINE_1);
    tft.setTextColor(ST77XX_WHITE, ST77XX_RED);
    tft.print("NOK");

    tft.setCursor(TFT_SEC_STATUS_COL, TFT_SEC_LINE_2);
    tft.setTextColor(ST77XX_WHITE, ST77XX_RED);
    tft.print("NOK");

    tft.setCursor(TFT_SEC_STATUS_COL, TFT_SEC_LINE_3);
    tft.setTextColor(ST77XX_WHITE, ST77XX_RED);
    tft.print("NOK");

    tft.setCursor(TFT_SEC_STATUS_COL, TFT_SEC_LINE_4);
    tft.setTextColor(ST77XX_GREEN, ST77XX_BLACK);
    tft.print("OK");

/*
    tft.setCursor(60, 0);
    tft.setTextColor(ST77XX_GREEN, ST77XX_BLACK);
    tft.println("OK ");

    delay(1000);

    tft.setCursor(60, 0);
    tft.setTextColor(ST77XX_BLACK, ST77XX_BLACK);
    tft.print("OK ");

    tft.setCursor(60, 0);
    tft.setTextColor(ST77XX_RED, ST77XX_BLACK);
    tft.println("NOK");
*/


}

void loop() {
    processData();
}
