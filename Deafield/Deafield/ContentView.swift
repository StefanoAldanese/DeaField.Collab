//
//  ContentView.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//


import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    // State variable to manage the recording state
    @State private var record = false

    // Audio session object to manage audio settings and authorization -- using optional
    @State private var session: AVAudioSession!

    // Audio recording object to record audio from the microphone
    @State private var recorder: AVAudioRecorder!

    // Audio playback object to play the recorded audio
    @State private var audioPlayer: AVAudioPlayer?

    // State variable to manage the appearance of an alert
    @State private var alert = false

    // Array to store the URLs of recorded audio
    @State private var audios: [URL] = []

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
//                Button for registration
                Button(action: startStopRecording) {
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
        }
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
        // Retrieve file attributes, including the creation date, for the given URL.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        // Check if the creation date is available.
        if let creationDate = attributes[.creationDate] as? Date {
            // Create a date formatter for a short date and time style.
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            // Format the creation date using the formatter and return the result.
            return formatter.string(from: creationDate)
        }
    } catch {
        // Handle any errors that occur during the process and print an error message.
        print("Error getting file attributes: \(error.localizedDescription)")
    }

    // Return an empty string if the creation date is not available or an error occurs.
    return ""
}

