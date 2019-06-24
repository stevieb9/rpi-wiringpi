#include <SoftwareSerial.h>
#include <stdio.h>

#define PI_BYTES 3

#define RX 6
#define TX 7

SoftwareSerial pi(RX, TX);

uint8_t sysInfo[PI_BYTES];

void displaySysInfo (uint8_t *sysInfo){
  
  char cpu[16], mem[16], cTemp[16];
    
  sprintf(cpu, "CPU:  %d%%    ", sysInfo[0]);
  sprintf(mem, "RAM:  %d%%    ", sysInfo[1]);
  sprintf(cTemp, "TEMP: %d F  ", sysInfo[2]);

  // draw on display here!
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
}

uint8_t *processData (){
  if (pi.available() == 3){
    for (uint8_t i=0; i<3; i++){
      sysInfo[i] = pi.read();
    }
  }
}

void loop() {
  uint8_t *sysInfo = processData();

  serialPrintSysInfo(sysInfo);
  displaySysInfo(sysInfo);
}
