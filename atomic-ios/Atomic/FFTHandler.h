//
//  FFTHandler.h
//  Swiftzam
//
//  Created by Tanmay Bakshi on 2021-06-24.
//

#ifndef FFTHandler_h
#define FFTHandler_h

#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "fftw3.h"

typedef struct FFTHandler {
    int n;
    int fftCount;
    int samplingRate;
    double *in;
    fftw_complex *out;
    fftw_plan plan;
} FFTHandler;

FFTHandler *newHandler(int n, int samplingRate);
void destroyHandler(FFTHandler *handler);
void snippetFrequencies(double *data, FFTHandler *handler);
double *spectrogram(double *data, int count, int stride, FFTHandler *handler);

#endif /* FFTHandler_h */
