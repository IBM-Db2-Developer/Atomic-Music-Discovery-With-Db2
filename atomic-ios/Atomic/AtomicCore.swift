//
//  AtomicCore.swift
//  AtomicCore
//
//  Created by Tanmay Bakshi on 2021-09-06.
//

import Foundation
import Metal

class MetalMaxFilter {
    enum MetalError: Error {
        case noDevice
        case noLibrary
        case noFunction
        case noCommandQueue
        case noBuffer
        case noCommandBuffer
        case noComputeEncoder
    }
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let maxFilterFunction: MTLFunction
    private let maxFilterFunctionPSO: MTLComputePipelineState
    private let commandQueue: MTLCommandQueue
    
    let threshold: Int
    
    init(device: MTLDevice? = nil, threshold: Int) throws {
        if let device = device {
            self.device = device
        } else {
            self.device = try MTLCreateSystemDefaultDevice() ?? { throw MetalError.noDevice }()
        }
        
        self.library = try self.device.makeDefaultLibrary() ?? { throw MetalError.noLibrary }()
        self.maxFilterFunction = try library.makeFunction(name: "maxFilter")  ?? { throw MetalError.noFunction }()
        self.maxFilterFunctionPSO = try self.device.makeComputePipelineState(function: self.maxFilterFunction)
        self.commandQueue = try self.device.makeCommandQueue() ?? { throw MetalError.noCommandQueue }()
        
        self.threshold = threshold
    }
    
    func compute<T>(data: UnsafeMutableBufferPointer<Float>, width: Int, height: Int, completion: (UnsafeMutablePointer<Int8>) -> (T)) throws -> T {
        // Create buffers for input, output, params
        guard let outputBuffer = device.makeBuffer(length: MemoryLayout<Int8>.size * data.count, options: .storageModeShared) else {
            throw MetalError.noBuffer
        }
        guard let inputBuffer = device.makeBuffer(bytes: data.baseAddress!, length: MemoryLayout<Float>.size * data.count, options: .storageModeShared) else {
            throw MetalError.noBuffer
        }
        var paramsBuffer: MTLBuffer!
        var params = [width, height, threshold].map { Int32($0) }
        params.withUnsafeMutableBufferPointer { ptr in
            paramsBuffer = device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count * MemoryLayout<Int32>.size, options: .storageModeShared)
        }
        guard let paramsBuffer = paramsBuffer else {
            throw MetalError.noBuffer
        }
        
        // Create GPU objects
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalError.noCommandBuffer
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.noComputeEncoder
        }
        
        // Encode max filter function
        computeEncoder.setComputePipelineState(maxFilterFunctionPSO)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        
        let gridSize = MTLSizeMake(data.count, 1, 1)
        let threadGroupSize = MTLSizeMake(min(maxFilterFunctionPSO.maxTotalThreadsPerThreadgroup, data.count), 1, 1)
        
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        
        // End encoding & run function, then wait
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Cleanup buffers & return output
        return completion(outputBuffer.contents().assumingMemoryBound(to: Int8.self))
    }
}

class AtomicCore {
    struct TimeInvariantFingerprint: Hashable, Codable {
        var f1: Int
        var f2: Int
        var delta: Int
        
        var customHash: Int {
            f1 << 0 | f2 << 16 | delta << 32
        }
        
        init(f1: Int, f2: Int, delta: Int) {
            self.f1 = f1
            self.f2 = f2
            self.delta = delta
        }
        
        init(hash: Int) {
            self.f1 = hash & 0b1111111111111111
            self.f2 = (hash & 0b11111111111111110000000000000000) >> 16
            self.delta = (hash & 0b111111111111111100000000000000000000000000000000) >> 32
        }
    }
    
    struct Audio {
        var data: UnsafeMutableBufferPointer<Double>
    }
    
    private let windowSize: Int32
    private let stride: Int32
    private let samplingRate: Int32
    private let lookahead: Int
    private let handler: UnsafeMutablePointer<FFTHandler>
    private let spectrogramWidth: Int
    private let maxFilter: MetalMaxFilter
    
    deinit {
        destroyHandler(handler)
    }
    
    init(windowSize: Int32, stride: Int32, samplingRate: Int32, lookahead: Int, threshold: Int) throws {
        self.windowSize = windowSize
        self.stride = stride
        self.samplingRate = samplingRate
        self.lookahead = lookahead
        self.handler = newHandler(windowSize, samplingRate)
        self.spectrogramWidth = Int(handler.pointee.fftCount)
        self.maxFilter = try MetalMaxFilter(threshold: threshold)
    }
    
    private func audioSpectrogram(audio: Audio) -> (UnsafeMutableBufferPointer<Float>, Int) {
        let result = spectrogram(audio.data.baseAddress!, Int32(audio.data.count), stride, handler)!
        let timesteps = (audio.data.count - Int(windowSize)) / Int(stride)
        let floatResult = UnsafeMutablePointer<Float>.allocate(capacity: spectrogramWidth * timesteps)
        for i in 0..<spectrogramWidth * timesteps {
            floatResult.advanced(by: i).pointee = Float(result.advanced(by: i).pointee)
        }
        result.deallocate()
        return (UnsafeMutableBufferPointer(start: floatResult, count: spectrogramWidth * timesteps), timesteps)
    }
    
    private func constellation(data: UnsafeMutableBufferPointer<Float>, timesteps: Int) throws -> [(Int, Int)] {
        try maxFilter.compute(data: data, width: spectrogramWidth, height: timesteps) { ptr -> [(Int, Int)] in
            var results: [(Int, Int)] = []
            for i in 0..<data.count {
                if ptr.advanced(by: i).pointee == 1 {
                    results.append((i / spectrogramWidth, i % spectrogramWidth))
                }
            }
            return results.sorted(by: { $0.0 < $1.0 })
        }
    }
    
    private func fingerprints(peaks: [(time: Int, frequency: Int)]) -> [TimeInvariantFingerprint: [Int32]] {
        var fingerprints: [TimeInvariantFingerprint: [Int32]] = [:]
        for i in 0..<peaks.count-1 {
            let peak = peaks[i]
            let distances = peaks[i+1..<min(i + 1001, peaks.count)]
                .map { (pow(Float($0.frequency - peak.frequency), 2) + pow(Float($0.time - peak.time), 2), $0) }
                .sorted { $0.0 < $1.0 }
                .filter { $0.1.time > peak.time }
            for (_, otherPeak) in distances[0..<min(lookahead, distances.count)] {
                let fingerprint = TimeInvariantFingerprint(f1: peak.frequency, f2: otherPeak.frequency, delta: otherPeak.time - peak.time)
                fingerprints[fingerprint, default: []].append(Int32(peak.time))
            }
        }
        return fingerprints
    }
    
    func fingerprints(for audio: Audio) throws -> [TimeInvariantFingerprint: [Int32]] {
        let (spectrogram, timesteps) = audioSpectrogram(audio: audio)
        let peaks = try constellation(data: spectrogram, timesteps: timesteps)
        let fingerprints = fingerprints(peaks: peaks)
        return fingerprints
    }
}
