//
//  Utils.h
//  Swiftzam
//
//  Created by Tanmay Bakshi on 2021-06-30.
//

#ifndef Utils_h
#define Utils_h

#include <stdio.h>
#include <stdlib.h>

short read2ByteCount(FILE *file);
int read4ByteCount(FILE *file);
long read8ByteCount(FILE *file);
char *readString(FILE *file);

#endif /* Utils_h */
