#include <Wire.h>

#define SLAVE_ADDR 0x05

// pseudo registers

#define PROCESS_SYSINFO 35

uint8_t pseudoRegister;

void sendData (){
    switch (pseudoRegister) {
      
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
              for (int i=0; i<i2cBytes; i++){
                sysInfo[i] = Wire.read();
              }
            }
        }
    }

  serialPrintSysInfo(sysInfo);
}

void serialPrintSysInfo(uint8_t *sysInfo){
  Serial.print(F("\nCPU:  "));
  Serial.print(sysInfo[0]);
  Serial.println(F("%"));
  Serial.print(F("RAM:  "));
  Serial.print(sysInfo[1]);
  Serial.println(F("%"));
  Serial.print(F("TEMP: "));
  Serial.print(sysInfo[2]);
  Serial.println(F("°F"));  
}

void setup() {
    Serial.begin(9600);
    Wire.begin(SLAVE_ADDR);
    Wire.onReceive(receiveData);
    Wire.onRequest(sendData);
}

void loop() {
}
