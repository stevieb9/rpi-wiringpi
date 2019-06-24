#include <SoftwareSerial.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <stdio.h>

#define PI_BYTES 3
#define DEBUG 0

#define RX 2
#define TX 3

#define OLED_I2C_ADDR 0x3C
#define OLED_RESET 4 
#define OLED_WIDTH 128 
#define OLED_HEIGHT 64 

// object instantiation

SoftwareSerial pi(RX, TX);
Adafruit_SSD1306 screen(OLED_WIDTH, OLED_HEIGHT, &Wire, OLED_RESET);

void displaySysInfo (uint8_t *sysInfo){
  
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

  screen.display();
}

void serialPrintSysInfo(uint8_t *sysInfo){
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
}

void setup() {
  Serial.begin(9600);

  // Pi comms setup
  
  pi.begin(9600);

  // OLED display setup
  
  if(!screen.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
    Serial.println(F("I2C OLED attach failure..."));
    for(;;);
  }

  screen.clearDisplay();

  screen.setTextSize(2);
  screen.setTextColor(WHITE);
  screen.setCursor(0, 0);
}

void processData (void){
  
  uint8_t sysInfo[PI_BYTES];
  
  if (pi.available() == PI_BYTES){
    for (uint8_t i=0; i<3; i++){
      sysInfo[i] = pi.read();
    }

    if (DEBUG){
      serialPrintSysInfo(sysInfo);
    }
    
    displaySysInfo(sysInfo);
  }
}

void loop() {
  processData();
}
