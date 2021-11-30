package main

import (
    "fmt"
    "path/filepath"
)

const WINDOW_SIZE = 4096
const SAMPLING_RATE = 48000
const STRIDE int32 = 2048
const GOROUTINES = 192

func IngestSongs(directory string, fftHandler *FFTHandler, authToken string, authSettings AuthSettings) error {
    wavs, err := filepath.Glob(directory + "/*.wav")
    if err != nil {
        return err
    }

    for i, wav := range wavs {
        fmt.Println(wav)
        audio, err := LoadAudioFromFile(wav, SAMPLING_RATE)
        if err != nil {
            return err
        }

        if len(audio) < SAMPLING_RATE {
            fmt.Println("SKIPPED! No audio.")
            continue
        }
        features := AudioFingerprints(audio, fftHandler, STRIDE, GOROUTINES)
        if len(features) < 1 {
            fmt.Println("SKIPPED! No features.")
            continue
        }
        err = UploadReferenceFingerprintsSingle(features, i, wav, authToken, authSettings)
        if err != nil {
            return err
        }
    }

    return nil
}

func main() {
    handler := NewFFTHandler(WINDOW_SIZE, SAMPLING_RATE)
    defer handler.Destroy()

    authSettings := AuthSettings{
        RestHostname: "<HOSTNAME OF REST SERVER>",
        DBHostname: "<HOSTNAME OF DB2 INSTANCE>",
        Database: "BLUDB",
        DBPort: <DATABASE PORT>,
        RestPort: 50050,
        SSL: true,
        Password: "<PASSWORD>",
        Username: "<USERNAME>",
        ExpiryTime: "24h",
    }

    authToken, err := Db2Authenticate(authSettings)
    if err != nil {
        fmt.Println(err)
        return
    }

    err = IngestSongs("<PATH TO DIRECTORY OF WAV FILES>", handler, authToken, authSettings)
    if err != nil {
        fmt.Println(err)
    }
    return
}
