package main

import (
    "fmt"
    "os"
    "io"
    "strings"

    "github.com/youpy/go-wav"
)

func LoadAudioFromFile(filename string, sampleRate int) ([]float64, error) {
    file, err := os.Open(filename)
    if err != nil {
        return []float64{}, err
    }
    defer file.Close()

    reader := wav.NewReader(file)
    format, err := reader.Format()
    if err != nil {
        return []float64{}, err
    }
    originalSampleRate := int(format.SampleRate)

    values := []float64{}
    for {
        samples, err := reader.ReadSamples()
        if err == io.EOF {
            break
        }
        for _, sample := range samples {
            values = append(values, float64(sample.Values[0]))
        }
    }

    if originalSampleRate == sampleRate {
        return values, nil
    } else {
        return ResampleAudio(values, originalSampleRate, sampleRate), nil
    }
}

func ResampleAudio(audio []float64, oldRate int, newRate int) []float64 {
    ratio := float64(newRate) / float64(oldRate)
    newLen := int(float64(len(audio)) * ratio)
    newAudio := make([]float64, newLen)

    newAudio[0] = audio[0]
    lastIdx := 0
    for i := 0; i < len(audio); i++ {
        newIdx := int(float64(i) * ratio)
        newAudio[newIdx] = audio[i]

        if newIdx > (lastIdx + 1) {
            diff := newAudio[newIdx] - newAudio[lastIdx]
            step := diff / float64((newIdx - lastIdx) - 1)
            for j := lastIdx + 1; j < newIdx; j++ {
                newAudio[j] = newAudio[j - 1] + step
            }
        }

        lastIdx = newIdx
    }

    return newAudio
}

func UploadQueryFingerprintsSingle(fingerprints map[int][]int, queryID int, authToken string, authSettings AuthSettings) error {
    valuesStrings := []string{}
    for fingerprint, timestamps := range fingerprints {
        for _, timestamp := range timestamps {
            valuesStrings = append(valuesStrings, fmt.Sprintf("(%d, %d, %d)", queryID, fingerprint, timestamp))
        }
    }
    for i := 0; i < len(valuesStrings); i += 20000 {
        valuesStringsChunk := valuesStrings[i:min(i+20000, len(valuesStrings))]
        insertString := "INSERT INTO QUERYHASH VALUES " + strings.Join(valuesStringsChunk, ", ") + ";"
        _, err := Db2RunSyncSQL(authToken, authSettings, insertString, map[string]interface{}{})
        if err != nil {
            return err
        }
    }
    return nil
}

func UploadReferenceFingerprintsSingle(fingerprints map[int][]int, fileID int, name string, authToken string, authSettings AuthSettings) error {
    valuesStrings := []string{}
    for fingerprint, timestamps := range fingerprints {
        for _, timestamp := range timestamps {
            valuesStrings = append(valuesStrings, fmt.Sprintf("(%d, %d, %d)", fileID, fingerprint, timestamp))
        }
    }
    for i := 0; i < len(valuesStrings); i += 20000 {
        valuesStringsChunk := valuesStrings[i:min(i+20000, len(valuesStrings))]
        hashInsertString := "INSERT INTO REFHASH VALUES " + strings.Join(valuesStringsChunk, ", ") + ";"
        _, err := Db2RunSyncSQL(authToken, authSettings, hashInsertString, map[string]interface{}{})
        if err != nil {
            return err
        }
    }

    nameInsertString := "INSERT INTO FILELIST VALUES (?, ?);"
    _, err := Db2RunSyncSQL(authToken, authSettings, nameInsertString, map[string]interface{}{
        "1": fileID,
        "2": name,
    })
    if err != nil {
        return err
    }

    return nil
}
