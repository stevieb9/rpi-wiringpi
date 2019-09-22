#include <stdio.h>
#include <stdint.h>

#define BIT1    0
#define BIT2    1
#define BIT6    5

const uint8_t fg_colour[2] = { 10, 19 };
const uint8_t bg_colour[2] = { 90, 99 };

void main (){

    for (uint8_t secByte=0; secByte < 255; secByte++){
        uint8_t state = (secByte >> BIT1) & 1;
        printf("fg: %d, bg: %d\n", fg_colour[state], bg_colour[state]);
    }
}
