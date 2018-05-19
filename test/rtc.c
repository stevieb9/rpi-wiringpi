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
#define RTC_DAY     0x03    // day of week (1-7)
#define RTC_DATE    0x04 // day of month (1-31)
#define RTC_MONTH   0x05
#define RTC_YEAR    0x06

#define RTC_AM_PM   0x20
#define RTC_12_24   0x40

int deviceI2CAddress = 0x68;

int dec2bcd(int num){
   return((num/10) * 16 + (num%10));
}

int setRegister(int fd, int reg, uint8_t value, char* name){
    char buf[2] = {reg, dec2bcd(value)};
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
  
    setRegister(deviceHandle, RTC_SEC, 1, "sec");        
    setRegister(deviceHandle, RTC_MIN, 1, "min");        
    setRegister(deviceHandle, RTC_HOUR, 3, "hour");        

    // begin transmission and request acknowledgement
	readBytes = write(deviceHandle, buffer, 1);
	if (readBytes != 1)
	{
		printf("Error: Received no ACK-Bit, couldn't established connection!");
	}
	else
	{
		// read response
		readBytes = read(deviceHandle, buffer, 7);
		if (readBytes != 7)
		{
			printf("Error: Received no data!");
		}
		else
		{
			// get data
			int seconds = buffer[0];	// 0-59
			int minutes = buffer[1];	// 0-59
			int hours = buffer[2];		// 1-23
			int dayOfWeek = buffer[3];	// 1-7
			int day = buffer[4];		// 1-28/29/30/31
			int month = buffer[5];		// 1-12
			int year = buffer[6];		// 0-99;
			
			// and print results
			printf("Actual RTC-time:\n");
			printf("Date: %x-%x-%x\n", year, month, day);
			printf("Time: %x:%x:%x\n", hours, minutes, seconds);
		}
	}	

	// close connection and return
	close(deviceHandle);
	return 0;
}
