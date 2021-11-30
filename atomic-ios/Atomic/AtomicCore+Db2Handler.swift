//
//  AtomicCore+Db2Handler.swift
//  AtomicCore+Db2Handler
//
//  Created by Tanmay Bakshi on 2021-09-06.
//

import Foundation

extension AtomicCore {
    struct Match: Codable {
        enum CodingKeys: String, CodingKey {
            case fileID = "FILEID"
            case diff = "DIFF"
            case filename = "FILENAME"
        }
        
        var fileID: Int
        var diff: Int
        var filename: String
    }
    
    static func upload(fingerprints: [TimeInvariantFingerprint: [Int32]], to db2: Db2Handler, in table: String, id: Int) async throws {
        var rows: [String] = []
        for (fingerprint, times) in fingerprints {
            for time in times {
                rows.append("(\(id),\(fingerprint.customHash),\(time))")
            }
        }
        for chunk in rows.chunks(size: 20000) {
            let insertString = "INSERT INTO \(table) VALUES \(chunk.joined(separator: ","))"
            try await db2.runSyncSQL(statement: insertString, parameters: [:])
        }
        print("Hash upload complete")
    }
    
    func match(id: Int, in db2: Db2Handler) async throws -> Match? {
        let response: Db2Handler.QueryResponse<Match> = try await db2.runSyncJob(service: "GetScores", version: "1.0", parameters: ["QUERYID": id])
        print("Match response complete")
        try await db2.runSyncSQL(statement: "DELETE FROM QUERYHASH WHERE QUERYID=?", parameters: ["1": id])
        print("Delete complete")
        return response.resultSet?.first
    }
}
