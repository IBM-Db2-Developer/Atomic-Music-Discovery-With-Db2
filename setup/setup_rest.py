import requests
import json

services = [
    {
      "isQuery": True,
      "parameters": [
        {
          "datatype": "int",
          "name": "@QueryID"
        }
      ],
      "serviceDescription": "Query Atomic using audio hashes",
      "serviceName": "GetScores",
      "sqlStatement": "SELECT MATCHCOUNTS.FileID, MATCHCOUNTS.MatchCount, DIFFCOUNTS.LargestDiffCount, MATCHCOUNTS.MatchCount * DIFFCOUNTS.LargestDiffCount AS Score FROM ( SELECT HASHMATCHES.FileID, COUNT(*) AS MatchCount FROM ( SELECT * FROM ( SELECT TIMES.FileID, TIMES.Hash AS THASH FROM TIMES GROUP BY TIMES.FileID, TIMES.Hash) FILEHASHES INNER JOIN ( SELECT QUERYHASH.Hash AS QHASH FROM QUERYHASH WHERE QUERYHASH.QUERYID = @QueryID GROUP BY QUERYHASH.Hash) QUERYHASHES ON THASH = QHASH) HASHMATCHES GROUP BY HASHMATCHES.FileID) MATCHCOUNTS LEFT JOIN ( SELECT FILEDIFFCOUNTS.FileID, MAX(FILEDIFFCOUNTS.DiffCount) AS LargestDiffCount FROM ( SELECT FILEDIFFS.FileID, FILEDIFFS.Diff, COUNT(*) AS DiffCount FROM ( SELECT TIMES.FileID, ABS(TIMES.Time - QUERYHASH.Time) AS Diff FROM TIMES INNER JOIN (SELECT * FROM QUERYHASH WHERE QUERYHASH.QUERYID = @QueryID) QUERYHASH ON TIMES.Hash = QUERYHASH.Hash) FILEDIFFS GROUP BY FILEDIFFS.FileID, FILEDIFFS.Diff) FILEDIFFCOUNTS GROUP BY FILEDIFFCOUNTS.FileID) DIFFCOUNTS ON MATCHCOUNTS.FileID = DIFFCOUNTS.FileID ORDER BY Score DESC",
      "version": "1.0"
    }
]

def authenticate(rest, body):
    url = f"{rest}/v1/auth"
    response = requests.post(url, json=body, headers={"Content-Type": "application/json"})
    resp = json.loads(response.text)
    print(resp)
    return resp["token"]

def setup(rest, token):
    url = f"{rest}/v1/metadata/setup"
    response = requests.post(url, headers={"authorization": token})
    return response.status_code == 201

def create_service(rest, token, service):
    url = f"{rest}/v1/services"
    response = requests.post(url, json=service, headers={"Content-Type": "application/json", "authorization": token})
    if response.status_code == 201:
        return
    return json.loads(response.text)

if __name__ == "__main__":
    auth_body = {
      "dbParms": {
        "dbHost": "<DATABASE HOSTNAME>",
        "dbName": "bludb",
        "dbPort": <PORT>,
        "isSSLConnection": True,
        "password": "<PASSWORD>",
        "username": "<USERNAME>"
      },
      "expiryTime": "24h"
    }
  
    rest_endpoint = "http://<REST HOSTNAME>:50050"

    token = authenticate(rest_endpoint, auth_body)

    if not setup(rest_endpoint, token):
        print("Could not setup metadata")

    for service in services:
        resp = create_service(rest_endpoint, token, service)
        if resp is not None:
            print(service)
            print("Could not create service")
            print(resp)
            print("")
