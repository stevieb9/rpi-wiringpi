#include <errno.h>
#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <stdio.h>
#include <stdint.h>

#define RTC_ADDR    0x68

#define RTC_SEC     0x00
#define RTC_MIN     0x01
#define RTC_HOUR    0x02
#define RTC_DAY     0x03 // day of week (1-7)
#define RTC_MDAY    0x04 // day of month (1-31)
#define RTC_MONTH   0x05
#define RTC_YEAR    0x06

#define RTC_AM_PM   0x20
#define RTC_12_24   0x40

int bcd2dec (int bcdByte)
{
  return (((bcdByte & 0xF0) >> 4) * 10) + (bcdByte & 0x0F);
}

int dec2bcd(int num){
   return((num/10) * 16 + (num%10));
}

int establishI2C (int fd){
    int buf[1] = { 0x00 };
    if (write(fd, buf, 1) != 1){
		printf("Error: Received no ACK-Bit, couldn't established connection!");
        return -1;
    }
    return 0;
}

int getFh (){
    int fd;

    if ((fd = open("/dev/i2c-1", O_RDWR)) < 0) {
        printf("Couldn't open the device: %s\n", strerror(errno));
		return -1;
	}

	if (ioctl(fd, I2C_SLAVE_FORCE, RTC_ADDR) < 0) {
        printf("Couldn't find device at addr %d: %s\n", RTC_ADDR, strerror(errno));
		return -1;
	}  

    int established = establishI2C(fd);
    return fd;
}

int setRegister(int fd, int reg, int value, char* name){

    char buf[2] = {reg, dec2bcd(value)};
    if ((write(fd, buf, sizeof(buf))) != 2){
        printf("Could not write the %s: %s\n", name, strerror(errno));
        return -1;
    }

    return 0;
}

int getElement (int fd, int element){

    char time[7];
    time[0] = 0x00;
    write(fd, time, 1);
    read(fd, time, 7);

    printf("%d:%d:%d\n",bcd2dec(time[2]),bcd2dec(time[1]),bcd2dec(time[0]));

    return bcd2dec(time[element]);
}

int main (void){

    int fd = getFh();

    printf("elem %d: %d\n", 0, getElement(fd, 0));
    printf("elem %d: %d\n", 1, getElement(fd, 1));
    printf("elem %d: %d\n", 2, getElement(fd, 2));
    printf("elem %d: %d\n", 3, getElement(fd, 3));
    printf("elem %d: %d\n", 4, getElement(fd, 4));
    printf("elem %d: %d\n", 5, getElement(fd, 5));
    printf("elem %d: %d\n", 6, getElement(fd, 6));
    
    close(fd);
	return 0;
}
