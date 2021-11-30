#include "FFTHandler.h"

FFTHandler *newHandler(int n, int samplingRate) {
    FFTHandler *handler = malloc(sizeof(FFTHandler));
    handler->n = n;
    handler->fftCount = n / 2 + 1;
    handler->samplingRate = samplingRate;
    handler->in = malloc(sizeof(double) * n);
    handler->out = malloc(sizeof(fftw_complex) * (n / 2 + 1));
    handler->plan = fftw_plan_dft_r2c_1d(n, handler->in, handler->out, FFTW_MEASURE);
    return handler;
}

void destroyHandler(FFTHandler *handler) {
    free(handler->in);
    free(handler->out);
    free(handler);
}

double multiplyByConjugate(fftw_complex x) {
    return x[0] * x[0] - x[1] * (-x[1]);
}

void snippetFrequencies(double *data, FFTHandler *handler) {
    double windowSum = 0;
    for (int i = 0; i < handler->n; i++) {
        double multiplier = 0.5 * (1 - cos(2 * M_PI * i / handler->n));
        data[i] *= multiplier;
        double absMultiplier = fabs(multiplier);
        windowSum += absMultiplier * absMultiplier;
    }
    memcpy(handler->in, data, handler->n * sizeof(double));
    fftw_execute(handler->plan);
    for (int i = 0; i < handler->fftCount; i++) {
        double val = multiplyByConjugate(handler->out[i]);
        data[i] = val;
        if (i > 1) {
            data[i - 1] *= 2;
        }
    }
    for (int i = 0; i < handler->fftCount; i++) {
        data[i] = data[i] / handler->samplingRate;
        data[i] = data[i] / windowSum;
    }
    data[handler->fftCount - 1] *= -1;
    for (int i = 0; i < handler->fftCount; i++) {
        data[i] = log10(data[i]) * 10;
    }
}

double *spectrogram(double *data, int count, int stride, FFTHandler *handler) {
    int totalWindows = (count - handler->n) / stride;
    double *buffers = malloc(sizeof(double) * totalWindows * handler->fftCount);
    
    size_t workBufferSize = sizeof(double) * handler->n;
    double *workBuffer = malloc(workBufferSize);
    
    size_t fftBytes = handler->fftCount * sizeof(double);
    
    for (int i = 0; i < totalWindows; i++) {
        memcpy(workBuffer, data + i * stride, workBufferSize);
        snippetFrequencies(workBuffer, handler);
        memcpy(buffers + (i * handler->fftCount), workBuffer, fftBytes);
    }
    
    free(workBuffer);
    
    return buffers;
}
