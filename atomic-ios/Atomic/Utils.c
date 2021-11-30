//
//  Utils.c
//  Swiftzam
//
//  Created by Tanmay Bakshi on 2021-06-30.
//

#include "Utils.h"

short read2ByteCount(FILE *file) {
    short x;
    fread(&x, 2, 1, file);
    return x;
}

int read4ByteCount(FILE *file) {
    int x;
    fread(&x, 4, 1, file);
    return x;
}

long read8ByteCount(FILE *file) {
    long x;
    fread(&x, 8, 1, file);
    return x;
}

char *readString(FILE *file) {
    short count = read2ByteCount(file);
    char *str = malloc(count + 1);
    str[count] = 0;
    fread(str, 1, (size_t) count, file);
    return str;
}


