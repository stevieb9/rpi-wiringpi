#include <errno.h>
#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "bit.h"

#define RTC_ADDR    0x68

// top-level registers

#define RTC_REG_DT  0x00

// sub-level registers

#define RTC_SEC     0x00
#define RTC_MIN     0x01
#define RTC_HOUR    0x02
#define RTC_WDAY    0x03 // day of week (1-7)
#define RTC_MDAY    0x04 // day of month (1-31)
#define RTC_MONTH   0x05
#define RTC_YEAR    0x06

// sub-level register bits

// sub register RTC_HOUR

#define RTC_AM_PM       0x05
#define RTC_12_24       0x06

int  _establishI2C (int fd);

int bcd2dec (int num){
  return (((num & 0xF0) >> 4) * 10) + (num & 0x0F);
}

int dec2bcd(int num){
   return((num/10) * 16 + (num%10));
}

int getFh (){

    int fd;

    if ((fd = open("/dev/i2c-1", O_RDWR)) < 0) {
        printf("Couldn't open the device: %s\n", strerror(errno));
        // croak here
		return -1;
	}

	if (ioctl(fd, I2C_SLAVE_FORCE, RTC_ADDR) < 0) {
        printf("Couldn't find device at addr %d: %s\n", RTC_ADDR, strerror(errno));
        close(fd);
        // croak here
		return -1;
	}  

    int established = _establishI2C(fd);

    return fd;
}

int setRegister(int fd, int reg, int value, char* name){

    char buf[2] = {reg, value};
    if ((write(fd, buf, sizeof(buf))) != 2){
        printf("Could not write the %s: %s\n", name, strerror(errno));
        // croak here
        return -1;
    }

    return 0;
}

int getRegister (int fd, int reg){

    char buf[1];
    buf[0] = reg;

    write(fd, buf, 1); // set the register pointer

    if ((read(fd, buf, 1)) != 1){
        printf("Could not read register %d: %s\n", reg, strerror(errno));
        // croak here
        return -1;
    }

    return buf[0];
}

int getRegisterBit (int fd, int reg, int bit){
    int regData = getRegister(fd, reg);
    return bitGet(regData, bit, bit);
}

int getRegisterBits (int fd, int reg, int msb, int lsb){
    return bitGet(getRegister(fd, reg), msb, lsb);
}

void enableRegisterBit (int fd, int reg, int bit){
    int data = bitOn(getRegister(fd, reg), bit);
    setRegister(fd, reg, data, "enabling bit");
}

void disableRegisterBit (int fd, int reg, int bit){
    int data = bitOff(getRegister(fd, reg), bit);
    setRegister(fd, reg, data, "disabling bit");
}

int getHour (int fd){
   
    int hour;

    if ((getRegisterBit(fd, RTC_HOUR, RTC_12_24)) == 0){
        // 24 hr clock
        hour = getRegister(fd, RTC_HOUR);
    }
    else {
        // 12 hr clock
        hour = getRegisterBits(fd, RTC_HOUR, 4, 0);
    }

    return bcd2dec(hour);
}

int _establishI2C (int fd){

    int buf[1] = { 0x00 };

    if (write(fd, buf, 1) != 1){
		printf("Error: Received no ACK-Bit, couldn't established connection!");
        close(fd);
        // croak here
        return -1;
    }

    return 0;
}

int main (void){

    int fd = getFh();

    setRegister(fd, RTC_HOUR, 4, "hour");
//    enableRegisterBit(fd, RTC_HOUR, RTC_12_24);
    enableRegisterBit(fd, RTC_HOUR, RTC_AM_PM);
    disableRegisterBit(fd, RTC_HOUR, RTC_AM_PM);

    printf("elem %d: %d\n", 0, bcd2dec(getRegister(fd, RTC_SEC)));
    printf("elem %d: %d\n", 1, bcd2dec(getRegister(fd, RTC_MIN)));
    printf("elem %d: %d\n", 2, bcd2dec(getRegister(fd, RTC_HOUR)));
    printf("elem %d: %d\n", 3, bcd2dec(getRegister(fd, RTC_WDAY)));
    printf("elem %d: %d\n", 4, bcd2dec(getRegister(fd, RTC_MDAY)));
    printf("elem %d: %d\n", 5, bcd2dec(getRegister(fd, RTC_MONTH)));
    printf("elem %d: %d\n", 6, bcd2dec(getRegister(fd, RTC_YEAR)));

    printf("reg %d, bit am/pm: %d, value: %d\n", RTC_HOUR, RTC_AM_PM, getRegisterBit(fd, RTC_HOUR, RTC_AM_PM));
    printf("reg %d, bit 24: %d, value: %d\n", RTC_HOUR, RTC_12_24, getRegisterBit(fd, RTC_HOUR, RTC_12_24));

    printf("reg %d, value: %d\n", RTC_HOUR, getRegisterBits(fd, RTC_HOUR, 6, 0));

    printf("getHour(): %d\n", getHour(fd));
    
    close(fd);

    return 0;
}
