package main

import (
    "fmt"
    "encoding/json"
    "net/http"
    "bytes"
    "errors"
    "io/ioutil"
    "time"
)

type AuthSettings struct {
    RestHostname string
    DBHostname string
    Database string
    DBPort int
    RestPort int
    SSL bool
    SSLKeystashPath string
    SSLKeystorePath string
    Password string
    Username string
    ExpiryTime string
}

type AuthenticationResponse struct {
    Token string `json:"token"`
}

type QueryResponse struct {
    JobStatus int `json:"jobStatus"`
    JobStatusDescription *string `json:"jobStatusDescription"`
    ResultSet *[]interface{} `json:"resultSet"`
    RowCount int `json"rowCount"`
}

type JobResponse struct {
    ID string `json:"id"`
}

type Job struct {
    Client *http.Client
    PageRequest *http.Request
    StopRequest *http.Request
}

func Db2Authenticate(authSettings AuthSettings) (string, error) {
    authURL := fmt.Sprintf("http://%s:%d/v1/auth", authSettings.RestHostname, authSettings.RestPort) // http://52.117.200.43:50000/v1/auth
    params := map[string]interface{}{
        "dbHost": authSettings.DBHostname,
        "dbName": authSettings.Database,
        "dbPort": authSettings.DBPort,
        "isSSLConnection": authSettings.SSL,
        "sslKeystashPath": authSettings.SSLKeystashPath,
        "sslKeystorePath": authSettings.SSLKeystorePath,
        "password": authSettings.Password,
        "username": authSettings.Username,
    }
    requestBody := map[string]interface{}{
        "dbParms": params,
        "expiryTime": authSettings.ExpiryTime,
    }
    requestBodyBytes, err := json.Marshal(requestBody)
    if err != nil { return "", err }
    request, err := http.NewRequest("POST", authURL, bytes.NewBuffer(requestBodyBytes))
    if err != nil { return "", err }
    request.Header.Add("Content-Type", "application/json")

    client := &http.Client{}
    response, err := client.Do(request)
    if err != nil { return "", err }
    defer response.Body.Close()
    responseBytes, err := ioutil.ReadAll(response.Body)
    if err != nil { return "", err }

    if response.StatusCode != 200 {
        return "", errors.New(string(responseBytes))
    }
    authResponse := AuthenticationResponse{}
    json.Unmarshal(responseBytes, &authResponse)
    return authResponse.Token, nil
}

func Db2RunQuery(authToken string, authSettings AuthSettings, service string, version string, parameters map[string]interface{}, sync bool) ([]byte, error) {
    uploadURL := fmt.Sprintf("http://%s:%d/v1/services/%s/%s", authSettings.RestHostname, authSettings.RestPort, service, version)
    requestBody := map[string]interface{}{
        "parameters": parameters,
        "sync": sync,
    }
    requestBodyBytes, err := json.Marshal(requestBody)
    if err != nil { return []byte{}, err }
    request, err := http.NewRequest("POST", uploadURL, bytes.NewBuffer(requestBodyBytes))
    if err != nil { return []byte{}, err }
    request.Header.Add("Content-Type", "application/json")
    request.Header.Add("authorization", authToken)

    client := &http.Client{}
    client.Timeout = 40 * time.Second
    response, err := client.Do(request)
    if err != nil { return []byte{}, err }
    defer response.Body.Close()
    responseBytes, err := ioutil.ReadAll(response.Body)
    if err != nil { return []byte{}, err }

    if response.StatusCode != 200 && response.StatusCode != 202 { // 200 is ok for sync, 202 is ok for async
        return []byte{}, errors.New(string(responseBytes))
    }
    return responseBytes, nil
}

func Db2RunSyncSQL(authToken string, authSettings AuthSettings, sql string, parameters map[string]interface{}) ([]byte, error) {
    uploadURL := fmt.Sprintf("http://%s:%d/v1/services/execsql", authSettings.RestHostname, authSettings.RestPort)
    requestBody := map[string]interface{}{
        "parameters": parameters,
        "isQuery": false,
        "sqlStatement": sql,
        "sync": true,
    }
    requestBodyBytes, err := json.Marshal(requestBody)
    if err != nil { return []byte{}, err }
    request, err := http.NewRequest("POST", uploadURL, bytes.NewBuffer(requestBodyBytes))
    if err != nil { return []byte{}, err }
    request.Header.Add("Content-Type", "application/json")
    request.Header.Add("authorization", authToken)

    client := &http.Client{}
    client.Timeout = 10 * time.Second
    response, err := client.Do(request)
    if err != nil { return []byte{}, err }
    defer response.Body.Close()
    responseBytes, err := ioutil.ReadAll(response.Body)
    if err != nil { return []byte{}, err }

    if response.StatusCode != 200 {
        return []byte{}, errors.New(string(responseBytes))
    }
    return responseBytes, nil
}

func Db2RunSyncJob(authToken string, authSettings AuthSettings, service string, version string, parameters map[string]interface{}) (QueryResponse, error) {
    result, err := Db2RunQuery(authToken, authSettings, service, version, parameters, true)
    if err != nil { return QueryResponse{}, err }
    response := QueryResponse{}
    json.Unmarshal(result, &response)
    return response, nil
}

func Db2RunSyncJobWithoutResponse(authToken string, authSettings AuthSettings, service string, version string, parameters map[string]interface{}) error {
    _, err := Db2RunQuery(authToken, authSettings, service, version, parameters, true)
    return err
}

func Db2RunAsyncJob(authToken string, authSettings AuthSettings, service string, version string, parameters map[string]interface{}, limit int) (Job, error) {
    result, err := Db2RunQuery(authToken, authSettings, service, version, parameters, false)
    if err != nil { return Job{}, err }
    response := JobResponse{}
    json.Unmarshal(result, &response)

    nextPageURL := fmt.Sprintf("http://%s:%d/v1/services/%s", authSettings.RestHostname, authSettings.RestPort, response.ID) // POST
    requestBodyNext := map[string]interface{}{
        "limit": limit,
    }
    requestBodyNextBytes, err := json.Marshal(requestBodyNext)
    if err != nil { return Job{}, err }
    requestNext, err := http.NewRequest("POST", nextPageURL, bytes.NewBuffer(requestBodyNextBytes))
    requestNext.Header.Add("Content-Type", "application/json")
    requestNext.Header.Add("authorization", authToken)
    if err != nil { return Job{}, err }

    stopURL := fmt.Sprintf("http://%s:%d/v1/services/stop/%s", authSettings.RestHostname, authSettings.RestPort, response.ID) // PUT
    requestStop, err := http.NewRequest("PUT", stopURL, bytes.NewBuffer([]byte{}))
    requestStop.Header.Add("authorization", authToken)
    if err != nil { return Job{}, err }

    client := &http.Client{}
    client.Timeout = 40 * time.Second

    job := Job{client, requestNext, requestStop}
    return job, nil
}

func (job *Job) NextPage() (*QueryResponse, error) {
    responseNext, err := job.Client.Do(job.PageRequest)
    if err != nil { return nil, err }
    defer responseNext.Body.Close()

    responseNextBytes, err := ioutil.ReadAll(responseNext.Body)
    if err != nil { return nil, err }

    if responseNext.StatusCode != 200 { // no need for 202 since always accessing an existing job, never making a new one
        if responseNext.StatusCode == 404 { return nil, nil } // not found, no error code associated with 404 not found error
        return nil, errors.New(string(responseNextBytes))
    }

    response := QueryResponse{}
    json.Unmarshal(responseNextBytes, &response)
    return &response, nil
}

func (job *Job) Stop() error {
    responseStop, err := job.Client.Do(job.StopRequest)
    if err != nil { return err }
    defer responseStop.Body.Close()

    responseStopBytes, err := ioutil.ReadAll(responseStop.Body)
    if err != nil { return err }

    if responseStop.StatusCode != 204 { // stopped successfully
        return errors.New(string(responseStopBytes))
    }

    return nil
}
