#include <stdlib.h>
#include <stdio.h>

#include <wiringPi.h>
#include <lcd.h>

static void waitForEnter(void);

static void waitForEnter (void)
{
  printf ("Press ENTER to continue: ") ;
  (void)fgetc (stdin) ;
}

void main(){
    wiringPiSetup();
    int fd = lcdInit(2, 16, 4, 6,5, 4,2,1,3, 0,0,0,0);

    lcdPosition(fd, 0, 0);
    lcdPuts(fd, "Steve Bertrand");
    lcdPosition(fd, 0, 1);
    lcdPuts(fd, "perlmonks.org");
    waitForEnter();
    lcdClear(fd);
}
