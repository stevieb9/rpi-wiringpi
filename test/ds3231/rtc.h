#ifndef _RTC_H_
#define _RTC_H_
#endif

int  _establishI2C (int fd);
int getHour (int fd);
int getFh ();
void disableRegisterBit (int fd, int reg, int bit);
void enableRegisterBit (int fd, int reg, int bit);
int getRegister (int fd, int reg);
int getRegisterBit (int fd, int reg, int bit);
int getRegisterBits (int fd, int reg, int msb, int lsb);
int setRegister(int fd, int reg, int value, char* name);
int bcd2dec(int num);
int dec2bcd(int num);

