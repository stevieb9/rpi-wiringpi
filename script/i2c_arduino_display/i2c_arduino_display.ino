#include <Wire.h>
#include "Multi_BitBang.h"
#include "Multi_OLED.h"
#include <SoftwareSerial.h>
#include <stdio.h>

#define SLAVE_ADDR 0x05

// pseudo registers

#define PROCESS_SYSINFO 35

#define I2C_SHARED_SCL_PIN 9
#define I2C_BUS_0_SDA_PIN 5

#define NUM_DISPLAYS 1
#define NUM_BUSES 1

#define PI_BYTES 3

#define RX 6
#define TX 7

SoftwareSerial pi(RX, TX);

// I2C bit-bang bus info

uint8_t scl_list[NUM_BUSES] = {I2C_SHARED_SCL_PIN};
uint8_t sda_list[NUM_BUSES] = {I2C_BUS_0_SDA_PIN};
int32_t speed_list[NUM_BUSES] = {400000L};

// OLED display info

uint8_t bus_list[NUM_DISPLAYS] = {0};
uint8_t addr_list[NUM_DISPLAYS] = {0x3c};
uint8_t type_list[NUM_DISPLAYS] = {OLED_128x64};
uint8_t flip_list[NUM_DISPLAYS] = {0};
uint8_t invert_list[NUM_DISPLAYS] = {0};

uint8_t sysInfo[PI_BYTES];

uint8_t pseudoRegister;

void sendData (){
  switch (pseudoRegister) {
    /*** for read requests ***/
  }
}

void receiveData (int numBytes){

  uint8_t i2cBytes = numBytes - 1; // we shift off the pseudoRegister
  uint8_t sysInfo[i2cBytes];

  while(Wire.available()){

    // save the register value for use later

    pseudoRegister = Wire.read();
        
    switch (pseudoRegister) {

      case PROCESS_SYSINFO: {
        for (uint8_t i=0; i<i2cBytes; i++){
          sysInfo[i] = Wire.read();
        }
      }
    }
  }
  
  displaySysInfo(sysInfo);
  serialPrintSysInfo(sysInfo);
}

void displaySysInfo (uint8_t *sysInfo){
  
  char cpu[15], mem[15], cTemp[15];
    
  sprintf(cpu, "CPU: %d%%     ", sysInfo[0]);
  sprintf(mem, "RAM: %d%%     ", sysInfo[1]);
  sprintf(cTemp, "TEMP: %dF   ", sysInfo[2]);

  Multi_OLEDWriteString(0, 0, 0, cpu, FONT_NORMAL, 0);
  Multi_OLEDWriteString(0, 0, 2, mem, FONT_NORMAL, 0);
  Multi_OLEDWriteString(0, 0, 4, cTemp, FONT_NORMAL, 0);
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
  pi.begin(9600);

  Wire.begin(SLAVE_ADDR);
  Wire.onReceive(receiveData);
  Wire.onRequest(sendData);
  
  Multi_I2CInit(sda_list, scl_list, speed_list, NUM_BUSES);
  Multi_OLEDInit(bus_list, addr_list, type_list, flip_list, invert_list, NUM_DISPLAYS);
  
  Multi_OLEDFill(0, 0);
  Multi_OLEDSetContrast(0, 20);

}

void loop() {
/*
  if (pi.available() == 3){
    for (uint8_t i=0; i<3; i++){
      sysInfo[i] = pi.read();
    }
  }

  serialPrintSysInfo(sysInfo);
  displaySysInfo(sysInfo);
*/
}
