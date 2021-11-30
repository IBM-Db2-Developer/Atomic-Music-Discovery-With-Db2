//
//  Utilities.swift
//  Utilities
//
//  Created by Tanmay Bakshi on 2021-09-06.
//

import Foundation

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

class SSLTrustingURLSession: NSObject, URLSessionDelegate {
    static var shared = SSLTrustingURLSession()
    
    var session: URLSession!
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .current)
    }
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        return (.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

extension String {
    init(freeing pointer: UnsafeMutablePointer<CChar>) {
        self.init(cString: pointer)
        pointer.deallocate()
    }
    
    func padding(with pad: String, to length: Int) -> String {
        self.count < length ? [String](repeating: pad, count: length - self.count).joined() + self : self
    }
}

extension Array {
    struct ChunkIterator: Sequence, IteratorProtocol {
        private let array: [Element]
        private let chunkSize: Int
        private var start = 0
        
        init(array: [Element], chunkSize: Int) {
            self.array = array
            self.chunkSize = chunkSize
        }
        
        mutating func next() -> ArraySlice<Element>? {
            if start >= array.count {
                return nil
            }
            let chunk = array[start..<Swift.min(start + chunkSize, array.count)]
            start += chunkSize
            return chunk
        }
    }
    
    func chunks(size: Int) -> ChunkIterator {
        ChunkIterator(array: self, chunkSize: size)
    }
}
