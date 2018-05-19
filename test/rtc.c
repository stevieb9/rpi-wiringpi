#include <stdio.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>

int deviceI2CAddress = 0x68;

int dec2bcd(int k){
   return((k/10)*16+(k%10));
}

setHour(int deviceHandle, int hours){
    char buf[2];
    buf[0] = 2;
    buf[1] = dec2bcd(hours);

    int x = write(deviceHandle, buf, 2);

    printf("buf: %d, %d\n", buf[0], buf[1]);
    printf("err: %d\n", x);
}

int main (void)
{

    int deviceI2CAddress = 0x68;
	// print infos
	printf("Raspberry Pi RTC DS1307 Sample\n");
	printf("========================================\n");
  
	int deviceHandle;
	int readBytes;
	char buffer[7];
 
	// initialize buffer
	buffer[0] = 0x00;
  
	// open device on /dev/i2c-1
	if ((deviceHandle = open("/dev/i2c-1", O_RDWR)) < 0) {
		printf("Error: Couldn't open device! %d\n", deviceHandle);
		return 1;
	}

	// connect to DS1307 as i2c slave
	if (ioctl(deviceHandle, I2C_SLAVE_FORCE, deviceI2CAddress) < 0) {
		printf("Error: Couldn't find device on address!\n");
		return 1;
	}  
  
    setHour(deviceHandle, 11);        

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
