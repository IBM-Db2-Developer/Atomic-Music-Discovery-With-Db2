//
//  ContentView.swift
//  Atomic
//
//  Created by Tanmay Bakshi on 2021-09-05.
//

import SwiftUI

struct ContentView: View {
    struct UIMatch {
        var title: String
        var thumbnailURL: URL
        var minutes: Int
        var seconds: Int
    }
    
    @ObservedObject var recorder = AudioRecorder()
    let atomicCore: AtomicCore
    let db2: Db2Handler
    
    @State var match: UIMatch?
    
    init() {
        atomicCore = try! AtomicCore(windowSize: 4096, stride: 2048,
                                     samplingRate: 48000, lookahead: 20,
                                     threshold: 10)
        db2 = try! Db2Handler(authSettings: .init(hostnameREST: "<HOSTNAME OF REST SERVER>",
                                                  hostnameDB: "<HOSTNAME OF DB2 INSTANCE>",
                                                  database: "BLUDB", dbPort: <DATABASE PORT>, restPort: 50050,
                                                  ssl: true, password: "<PASSWORD>",
                                                  username: "<USERNAME>", expiryTime: "24h"))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                if let match = match {
                    VStack {
                        AsyncImage(url: match.thumbnailURL) { image in
                            image
                                .resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: geometry.size.width - 40, height: (geometry.size.width - 40) * 0.75)
                        
                        Text(match.title)
                            .bold()
                        
                        Text("\(match.minutes):\("\(match.seconds)".padding(with: "0", to: 2))")
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(height: 60)
                        .padding()
                        .foregroundColor(!recorder.canRecord || recorder.recording ? .gray : .blue)
                    
                    Text(!recorder.canRecord ? "Waiting for permissions..." : (recorder.recording ? "Recording..." : "Record"))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                .onTapGesture {
                    if recorder.canRecord && !recorder.recording {
                        self.match = nil
                        getAudioRunMatch()
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            recorder.setup()
        }
    }
    
    func getAudioRunMatch() {
        do {
            try recorder.startRecording()
        } catch let error {
            print("Couldn't record. Error: \(error)")
        }
        
        Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { timer in
            let audio: [Float]
            do {
                audio = try recorder.finishRecording()
            } catch let error {
                print("Couldn't finish recording. Error: \(error)")
                return
            }
            
            var processedAudio = audio.map { Double(floor($0 * 32768)) }
            processedAudio.withUnsafeMutableBufferPointer { ptr in
                let fingerprints: [AtomicCore.TimeInvariantFingerprint: [Int32]]
                do {
                    fingerprints = try self.atomicCore.fingerprints(for: .init(data: ptr))
                } catch let error {
                    print("Couldn't upload fingerprints. Error: \(error)")
                    return
                }
                
                Task {
                    let id = Int.random(in: 1...10000000)
                    print("\(id): \(fingerprints.count)")
                    try await AtomicCore.upload(fingerprints: fingerprints, to: db2, in: "QUERYHASH", id: id)
                    guard let match = try await atomicCore.match(id: id, in: db2) else {
                        print("No match!")
                        return
                    }
                    
                    print(match)
                    
                    let youtubeID = match.filename
                        .components(separatedBy: "-").last!
                        .components(separatedBy: ".").first!
                    let title = match.filename
                        .replacingOccurrences(of: "/root/allsongs/", with: "")
                        .replacingOccurrences(of: "-\(youtubeID).mp3.wav", with: "")
                    guard let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(youtubeID)/hqdefault.jpg") else {
                        print("Invalid thumbnail URL!")
                        return
                    }
                    let diffSeconds = Int(Float(match.diff * 2048) / 48000)
                    
                    self.match = UIMatch(title: title, thumbnailURL: thumbnailURL,
                                         minutes: diffSeconds / 60, seconds: diffSeconds % 60)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
