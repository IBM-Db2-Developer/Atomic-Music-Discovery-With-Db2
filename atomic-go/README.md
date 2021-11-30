# Atomic

Build:

```
clang FFTHandler.c -L/usr/local/lib -lfftw3 -lm -Ofast -shared -fPIC -o libffthandler.so
go build .
```
