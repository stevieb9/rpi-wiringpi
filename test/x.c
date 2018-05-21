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

uint8_t bcd2dec (uint8_t bcdByte)
{
  return (((bcdByte & 0xF0) >> 4) * 10) + (bcdByte & 0x0F);
}
int dec2bcd(int num){
   return((num/10) * 16 + (num%10));
}

int setRegister(int fd, int reg, int value, char* name){
    printf("setting hour to: %d\n", value);
    char buf[2] = {reg, dec2bcd(value)};
    if ((write(fd, buf, sizeof(buf))) != 2){
        printf("Could not write the %s: %s\n", name, strerror(errno));
        return -1;
    }
    return 0;
}

int setDec(int fd, int reg, uint8_t value, char* name){
    char buf[2] = {reg, value};
    if ((write(fd, buf, sizeof(buf))) != 2){
        printf("Could not write the %s: %s\n", name, strerror(errno));
        return -1;
    }
    return 0;
}

int main (void)
{
	int deviceHandle;
	int readBytes;
	char buffer[7];
 
	// initialize buffer
	buffer[0] = 0x00;
  
	// open device on /dev/i2c-1
	if ((deviceHandle = open("/dev/i2c-1", O_RDWR)) < 0) {
        printf("Couldn't open the device: %s\n", strerror(errno));
		return -1;
	}

	// connect to DS1307 as i2c slave
	if (ioctl(deviceHandle, I2C_SLAVE_FORCE, RTC_ADDR) < 0) {
        printf("Couldn't find device at addr %d: %s\n", RTC_ADDR, strerror(errno));
		return -1;
	}  
 
//    setRegister(deviceHandle, RTC_HOUR, 9, "hour");        
    setRegister(deviceHandle, RTC_HOUR, 9, "12_24");        
    setRegister(deviceHandle, RTC_HOUR, (9 | 0b01000000), "12_24"); // 73 (9 + 64)
    printf("is 12: %d\n", (9 | 0b01000000) >> 6); // get the single 12/24 hr bit

    // begin transmission and request acknowledgement

	readBytes = write(deviceHandle, buffer, 1);
	if (readBytes != 1){
		printf("Error: Received no ACK-Bit, couldn't established connection!");
	}
    else{
		// read response
		readBytes = read(deviceHandle, buffer, 7);
		if (readBytes != 7){
			printf("Error: Received no data!");
		}
		else {
            int hour = bcd2dec(buffer[2]);
//            int hour = bcd2dec(buffer[2]);
            printf("hour: %d\n", hour);

            if (hour > 12){
                hour = (hour - 12) | 0b01100000;
            }
            else {
                hour = hour & 0b11011111;
            }
            printf("%d\n", hour);

            printf("12/24: %d\n", hour & 0b01000000);
		}
	}	

	close(deviceHandle);
	return 0;
}
