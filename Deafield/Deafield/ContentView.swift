//
//  ContentView.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//

import SwiftUI
import AVFoundation
import Accelerate
import CoreHaptics

class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var numberOfRecords = 0
    @Published var recordings: [URL] = []
    @Published var showAlert = false
    @Published var showStopAlert = false
    @Published var audioRecorder: AVAudioRecorder?
    @Published var buttonColor: Color = .blue
    @Published var dominantFrequencies: [Double] = []

    private var coordinator: Coordinator?
    private var frequencyAnalysisTimer: Timer?

    override init() {
        super.init()
        loadPreviousRecords()
        requestRecordPermission()

        
    }

    func findAverageFrequencyInSineWave(_ samples: [Float], sampleRate: Double, duration: Double) -> Double? {
        let segmentDuration = 0.5  // Durata del segmento in secondi
        let segmentSamples = Int(sampleRate * segmentDuration)

        // Estrai il segmento corrente
        let segment = Array(samples.prefix(segmentSamples))

        // Calcola l'autocorrelazione
        var autocorrelation = [Float](repeating: 0.0, count: segmentSamples)
        vDSP_conv(segment, 1, segment.reversed(), 1, &autocorrelation, 1, vDSP_Length(segmentSamples), vDSP_Length(segmentSamples))

        // Trova il picco nella funzione di autocorrelazione
        var peakIndex: vDSP_Length = 0
        var peakValue: Float = 0.0
        vDSP_maxvi(autocorrelation, 1, &peakValue, &peakIndex, vDSP_Length(autocorrelation.count))

        // Calcola la frequenza corrispondente
        let fundamentalFrequency = Double(sampleRate) / Double(peakIndex)

        return fundamentalFrequency.isFinite ? fundamentalFrequency : nil
    }


    func findDominantFrequencyInAudioFile(at url: URL, sampleRate: Double) -> [Double] {
        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            let audioFormat = audioFile.processingFormat
            let audioFrameCount = UInt32(audioFile.length)
            let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)!

            try audioFile.read(into: audioBuffer)

            let segmentDuration: Double = 0.5 // Durata del segmento in secondi
            let segmentSamples = Int(segmentDuration * sampleRate)

            var currentIndex = 0
            var dominantFrequencies: [Double] = [] // Local variable

            while currentIndex + segmentSamples <= Int(audioBuffer.frameLength) {
                // Estrai il segmento corrente
                let segment = Array(UnsafeBufferPointer(start: audioBuffer.floatChannelData?[0].advanced(by: currentIndex), count: segmentSamples))

                // Performi l'analisi della frequenza per il segmento
                if let averageFrequency = findAverageFrequencyInSineWave(segment, sampleRate: sampleRate, duration: segmentDuration) {
                    dominantFrequencies.append(averageFrequency)
                }

                // Muovi l'indice al prossimo segmento
                currentIndex += segmentSamples
            }

            // Print debug information
            print("Dominant Frequencies: \(dominantFrequencies)")

            // Restituisci l'array di frequenze dominanti trovate
            return dominantFrequencies

        } catch {
            print("Error loading audio file: \(error.localizedDescription)")
            return []
        }
    }

    
    // Function to delete a recording
    func deleteRecording(at offsets: IndexSet) {
        numberOfRecords -= offsets.count
        for index in offsets {
            let recordingURL = recordings[index]
            do {
                try FileManager.default.removeItem(at: recordingURL)
                recordings.remove(at: index)
            } catch {
                print("Error deleting recording: \(error.localizedDescription)")
            }
        }
        
        // Aggiorna l'array dopo la cancellazione
        UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")
        loadPreviousRecords()
    }

    // Function to toggle recording
    func toggleRecording() {
        if isRecording {
            showStopAlert = true
        } else {
            // Assign a default name when starting to record
            startRecording()
            buttonColor = .red
        }
    }

    // Function to start recording
    func startRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)

            // Increment the record number and set the file name
            numberOfRecords += 1
            let filename = getDirectory().appendingPathComponent("\(numberOfRecords).m4a")

            // Settings for audio recording
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Create an instance of Coordinator and assign it as the delegate
            coordinator = Coordinator()
            audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
            audioRecorder?.delegate = coordinator
            audioRecorder?.record()
            isRecording = true
        } catch {
            // Handle recording error
            displayAlert(title: "Ups!", message: "Recording failed")
            print("Error starting recording: \(error.localizedDescription)")
        }
    }


    // Function to stop recording
    func stopRecording() {
        guard isRecording else {
            return
        }

        // Save the record number and load previous records
        UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")
        loadPreviousRecords()

        // Set recording state and button color
        isRecording = false
        buttonColor = .blue

        // Stop AVAudioRecorder and deallocate resources
        audioRecorder?.stop()
        audioRecorder?.delegate = nil
        audioRecorder = nil
    }
    
    // Function to load previous records
    func loadPreviousRecords() {
        if let number = UserDefaults.standard.object(forKey: "myNumber") as? Int, number > 0 {
            numberOfRecords = number
            recordings = (1...number).map {
                getDirectory().appendingPathComponent("\($0).m4a")
            }
        }
    }

    // Function to request recording permission
    func requestRecordPermission() {
        AVAudioApplication.requestRecordPermission() { hasPermission in
            if !hasPermission {
                self.showAlert = true
            }
        }
    }

    // Function to get the document directory path
    func getDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Function to open app settings
    func openSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }

    // Function to display an alert
    func displayAlert(title: String, message: String) {
        showAlert = true
    }
}

// ContentView preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Coordinator class to handle AVAudioRecorderDelegate events
class Coordinator: NSObject, AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Handle recording finished
        if !flag {
            // Implement any additional logic for unsuccessful recording
        }
    }
}
struct ContentView: View {
    @StateObject private var audioRecorderManager = AudioRecorderManager()

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(audioRecorderManager.recordings.indices, id: \.self) { index in
                        let recordingURL = audioRecorderManager.recordings[index]

                        NavigationLink(
                            destination: RecordingDetailView(recordURL: recordingURL, index: index, audioRecorderManager: audioRecorderManager, newName: ""),
                            label: {
                                Text("Recording \(index + 1)")
                            }
                        )
                    }

                    .onDelete { indices in
                        indices.forEach { index in
                            audioRecorderManager.deleteRecording(at: IndexSet(integer: index))
                        }
                    }
                }
                .padding(10)

                Button(action: {
                    audioRecorderManager.toggleRecording()
                }) {
                    Text(audioRecorderManager.isRecording ? "Stop Recording" : "Start Recording")
                        .padding()
                        .background(audioRecorderManager.buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(40)
                }
            }
            .padding(10)
            .navigationBarTitle("Voice Memos")
            .alert(isPresented: $audioRecorderManager.showAlert) {
                Alert(
                    title: Text("Microphone Access"),
                    message: Text("This app requires access to your microphone to record audio. Enable access in Settings."),
                    primaryButton: .default(Text("Settings")) {
                        audioRecorderManager.openSettings()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $audioRecorderManager.showStopAlert) {
                Alert(
                    title: Text("Stop Recording"),
                    message: Text("Do you want to stop the recording?"),
                    primaryButton: .default(Text("Yes")) {
                        audioRecorderManager.stopRecording()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                audioRecorderManager.loadPreviousRecords()
                audioRecorderManager.requestRecordPermission()
            }
        }
    }
}

struct RecordingDetailView: View {
    var recordURL: URL
    var index: Int
    @ObservedObject var audioRecorderManager: AudioRecorderManager
    @State private var newName: String // Temporary variable for editing

    @State private var isEditing = false
    
    public init(recordURL: URL, index: Int, audioRecorderManager: AudioRecorderManager, newName: String) {
        self.recordURL = recordURL
        self.index = index
        self.audioRecorderManager = audioRecorderManager
        self._newName = State(initialValue: newName)
    }

    var body: some View {
        VStack {
            if isEditing {
                TextField("Enter a new name", text: $newName, onCommit: {
                    guard !newName.isEmpty else { return }
                    audioRecorderManager.recordings[index] = recordURL.deletingLastPathComponent().appendingPathComponent(newName)
                    audioRecorderManager.loadPreviousRecords()  // Update the record list
                    isEditing = false
                })
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                if let recordingURL = audioRecorderManager.recordings[safe: index] {
                    Text("Recording Detail: \(recordingURL.lastPathComponent)")
                        .navigationBarTitle("Recording Detail")
                }

                Button(action: {
                    if let recordingURL = audioRecorderManager.recordings[safe: index], FileManager.default.fileExists(atPath: recordingURL.path) {
                        let sampleRate = 12000.0

                        // Use a local variable for dominant frequencies
                        let dominantFrequencies = audioRecorderManager.findDominantFrequencyInAudioFile(at: recordingURL, sampleRate: sampleRate)

                        // Stampa l'array di frequenze dominanti
                        print("Dominant Frequencies: \(dominantFrequencies)")
                    } else {
                        print("Recording does not exist")
                    }
                }) {
                    Text("Analyze Frequency")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(40)
                }
            }
        }
        .padding()
    }
}
// Estendi Collection per aggiungere l'accesso sicuro all'array
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
