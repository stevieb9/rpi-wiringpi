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


// ****

int setRegister(int fd, int reg, int value, char* name){
    printf("setting hour to: %d\n", value);
    char buf[2] = {reg, dec2bcd(value)};
    if ((write(fd, buf, sizeof(buf))) != 2){
        printf("Could not write the %s: %s\n", name, strerror(errno));
        return -1;
    }
    return 0;
}

int setHourMode (int fd, uint8_t mode){
    return 0;
}

int getAmPm (int fd){
    uint8_t is12Hr = 1;

    if (getHourMode(fd) == is12Hr){

        char buf[2] = { RTC_HOUR };
        write(fd, buf, 1);
        read(fd, buf, 1);
        
        uint8_t meridiem = buf[0] >> 5;
        printf("am/pm: %d\n", meridiem);

        return meridiem;
    }
    else {
        printf("Not in 12 hour mode\n");
        return -1;
    }
}

int getHourMode (int fd){
    char buf[2];
    buf[0] = RTC_HOUR;
    write(fd, buf, 1);    
    read(fd, buf, 1);
    printf("mode: %d\n", buf[0] >> 6);

    return buf[0] >> 6;
}
int getHour (int fd){

    /*
    setRegister(fd, RTC_HOUR, 9, "hour");
    setRegister(fd, RTC_MIN, 11, "min");        
    setRegister(fd, RTC_SEC, 10, "sec");        
    */
    char time[7];
    time[0] = 0x00;
    write(fd, time, 1);
    read(fd, time, 7);

    printf("%d:%d:%d\n", bcd2dec(time[2]), bcd2dec(time[1]), bcd2dec(time[0]));
/*
    getHourMode(fd);
    setRegister(fd, RTC_HOUR, time[2] &= ~(1 << 6), "mode"); 
    getHourMode(fd);

    time[0] = 0x00;
    write(fd, time, 1);
    read(fd, time, 7);

    printf("%d:%d:%d\n", bcd2dec(time[2]), bcd2dec(time[1]), bcd2dec(time[0]));
*/
    printf("hour raw: %d\n", time[2]);
    return time[2];
}

// ***

/*uint8_t* getTime(int fd, uint8_t* buf){
    int fd = getFh();

}*/

int main (void){
    int fd = getFh();

/* 
    setRegister(deviceHandle, RTC_HOUR, 18, "12_24");        
    setRegister(deviceHandle, RTC_HOUR, (18 | 0b01000000), "12_24"); // 73 (9 + 64)
    printf("is 12: %d\n", (18 | 0b01000000) >> 6); // get the single 12/24 hr bit

    int hour = bcd2dec(buffer[2]);
            int hour = bcd2dec(buffer[2]);
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
    */

//    getHourMode(fd);
    getHour(fd);
    getAmPm(fd);
	close(fd);
	return 0;
}
