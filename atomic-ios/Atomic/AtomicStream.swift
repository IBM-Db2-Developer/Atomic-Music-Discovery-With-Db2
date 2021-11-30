//
//  AtomicStream.swift
//  AtomicStream
//
//  Created by Tanmay Bakshi on 2021-09-09.
//

import Foundation

/*class AtomicStream {
    class AudioBufferList {
        class Node {
            var next: Node?
            var buffer: [Float]
            
            init(next: Node? = nil, buffer: [Float]) {
                self.next = next
                self.buffer = buffer
            }
        }
        
        private var list: (start: Node, end: Node)?
        private var lastRecv: TimeInterval?
        private var recvDelay: TimeInterval
        private let semaphore = DispatchSemaphore(value: 1)
        
        init(recvDelay: TimeInterval) {
            self.recvDelay = recvDelay
        }
        
        func addToEnd(buffer: [Float]) {
            semaphore.wait()
            defer { semaphore.signal() }
            
            let node = Node(buffer: buffer)
            list?.end.next = node
            list = (list?.start ?? node, node)
        }
        
        func addToBeginning(buffer: [Float]) {
            semaphore.wait()
            defer { semaphore.signal() }
            
            let node = Node(next: list?.start, buffer: buffer)
            list = (node, list?.end ?? node)
        }
        
        private func getTopSamples() -> [Float]? {
            let start = list?.start
            if let next = start?.next {
                list = (next, list!.end)
            }
            return start?.buffer
        }
        
        func getSamples(max: Int) -> [Float] {
            semaphore.wait()
            defer { semaphore.signal() }
            
            defer { lastRecv = Date().timeIntervalSince1970 }
            if let lastRecv = lastRecv {
                let time = Date().timeIntervalSince1970
                let elapsed = time - lastRecv
                if elapsed < recvDelay {
                    semaphore.signal()
                    usleep(useconds_t((recvDelay - elapsed) * 1000000))
                    semaphore.wait()
                }
            }
            var samples: [Float] = []
            while let topSamples = getTopSamples() {
                let mergedCount = samples.count + topSamples.count
                if mergedCount > max {
                    let stop = max - samples.count
                    samples += topSamples[0..<stop]
                    addToBeginning(buffer: Array(topSamples[stop..<topSamples.count]))
                } else {
                    samples += topSamples
                }
            }
            return samples
        }
    }
    
    var bufferList: AudioBufferList
    
    init() {
        bufferList = AudioBufferList(recvDelay: 1)
    }
    
    func startStream() {
        
    }
}*/
