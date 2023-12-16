//
//  ContentView.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var record = false
    @State private var session: AVAudioSession!
    @State private var recorder: AVAudioRecorder!
    @State private var audioPlayer: AVAudioPlayer?
    @State private var alert = false
    @State private var audios: [URL] = []
    @State private var isRecordingOverlayVisible = false
    @State private var recordingStartTime: Date?
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(audios, id: \.self) { audio in
                        VStack(alignment: .leading) {
                            Text(audio.lastPathComponent)
                            Text(getFormattedDate(for: audio))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: deleteAudio)
                }
//Questa parte non funziona propriamente...dovrebbe fare un overlay dove inserire nome registrazione tempo e spettrogramma
//                vedi giù l'overlay
                Button(action: {
                    startStopRecording()
                    withAnimation {
                    
                        isRecordingOverlayVisible.toggle()
                        if record {
                            recordingStartTime = Date()
                        } else {
                            recordingStartTime = nil
                        }
                    }
                }) {
//
                    Image(systemName: record ? "stop.circle.fill" : "circle.fill.record")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .foregroundColor(.red)
                        .background(record ? Color.clear : Color.red)
                        .clipShape(Circle())
                }
                .padding(.vertical, 25)
            }
            .navigationBarTitle("Memo Vocali", displayMode: .inline)
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                Task {
                    do {
                        session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playAndRecord)

                        if await AVAudioApplication.requestRecordPermission() {
                            self.getAudios()
                        } else {
                            self.alert.toggle()
                        }
                    } catch {
                        print("Audio session setup error: \(error.localizedDescription)")
                    }
                }
            }
            .alert(isPresented: $alert) {
                Alert(
                    title: Text("Microphone Access"),
                    message: Text("This app requires access to your microphone to record audio. Enable access in Settings."),
                    primaryButton: .default(Text("Settings")) {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    },
                    secondaryButton: .cancel()
                )
            }
//questo è il recording overlay
            // Recording overlay
            if isRecordingOverlayVisible {
                ZStack {
                    Color(UIColor.systemGray6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        Text("Recording...")
                            .font(.headline)
                            .padding()

                        if let startTime = recordingStartTime {
                            Text("\(formattedRecordingTime(from: startTime))")
                                .foregroundColor(.red)
                                .font(.title)
                        }

                        Button("Stop Recording") {
                            startStopRecording()
                            withAnimation {
                                isRecordingOverlayVisible.toggle()
                            }
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    func formattedRecordingTime(from startTime: Date) -> String {
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsedTime / 60)
        let seconds = Int(elapsedTime.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func getAudios() {
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let result = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .producesRelativePathURLs)

            audios.removeAll()
            for i in result {
                audios.append(i)
            }
        } catch {
            print("Error fetching audio files: \(error.localizedDescription)")
        }
    }

    func startStopRecording() {
        if record {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("myRcd\(audios.count + 1).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            record.toggle()
        } catch {
            print("Recording setup error: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        recorder.stop()
        record.toggle()
        getAudios()
    }

    func deleteAudio(at offsets: IndexSet) {
        do {
            for index in offsets {
                try FileManager.default.removeItem(at: audios[index])
            }
            getAudios()
        } catch {
            print("Error deleting audio: \(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Function to get a formatted date from the creation date of a file URL.
func getFormattedDate(for url: URL) -> String {
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let creationDate = attributes[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: creationDate)
        }
    } catch {
        print("Error getting file attributes: \(error.localizedDescription)")
    }
    return ""
}
