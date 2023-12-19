//
//  ContentView.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//

import SwiftUI
import AVFoundation
import Accelerate

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

        // Inizializza il timer per il campionamento periodico
        frequencyAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Esegui l'analisi della frequenza sul file audio corrente
            if let lastRecordingURL = self?.recordings.last {
                self?.findDominantFrequencyInAudioFile(at: lastRecordingURL, sampleRate: 44100.0)
            }
        }
    }

    deinit {
        // Ferma il timer quando l'istanza viene deallocata
        frequencyAnalysisTimer?.invalidate()
    }
    
    
    private func findAverageFrequencyInSineWave(_ signal: [Float], sampleRate: Double, duration: Double) -> Double? {
        guard !signal.isEmpty else {
            return nil // Non ci sono dati nel segnale
        }

        let bufferSize = signal.count
        let audioData = signal

        var real = [Float](repeating: 0.0, count: bufferSize)
        var imag = [Float](repeating: 0.0, count: bufferSize)
        var tempComplex = [DSPComplex](repeating: DSPComplex(), count: bufferSize / 2)

        for i in 0..<bufferSize / 2 {
            tempComplex[i].real = audioData[i * 2]
            tempComplex[i].imag = audioData[i * 2 + 1]
        }

        var output = DSPSplitComplex(realp: &real, imagp: &imag)
        vDSP_ctoz(tempComplex, 2, &output, 1, vDSP_Length(bufferSize / 2))

        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(bufferSize))), FFTRadix(kFFTRadix2))
        vDSP_fft_zrip(fftSetup!, &output, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_FORWARD))

        var magnitude = [Float](repeating: 0.0, count: bufferSize / 2)
        vDSP_zvmags(&output, 1, &magnitude, 1, vDSP_Length(bufferSize / 2))

        let mainHarmonicFrequency = findMainHarmonicFrequency(magnitude, sampleRate: sampleRate, bufferSize: bufferSize)
        print("Main harmonic frequency: \(mainHarmonicFrequency) Hz")

        vDSP_destroy_fftsetup(fftSetup)

        return Double(mainHarmonicFrequency)
    }

    // Function to find dominant frequency in an audio file
    func findDominantFrequencyInAudioFile(at url: URL, sampleRate: Double) {
        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            let audioFormat = audioFile.processingFormat
            let audioFrameCount = UInt32(audioFile.length)
            let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)!

            try audioFile.read(into: audioBuffer)

            // Convert audio buffer to an array of Float
            let samples = Array(UnsafeBufferPointer(start: audioBuffer.floatChannelData?[0], count: Int(audioBuffer.frameLength)))

            // Perform frequency analysis
            if let averageFrequency = findAverageFrequencyInSineWave(samples, sampleRate: sampleRate, duration: 1.0) {
                let threshold: Double = 1000 // Imposta la tua soglia desiderata

                if averageFrequency > threshold {
                    // Fornisci feedback aptico per il cambio di frequenza
                    provideHapticFeedback()
                }

                // Aggiorna la proprietà pubblicata
                self.dominantFrequencies = [averageFrequency]
            }
        } catch {
            print("Error loading audio file: \(error.localizedDescription)")
        }
    }

    
    // Funzione di esempio per fornire il feedback aptico
    func provideHapticFeedback() {
        // Implementa la logica per fornire il feedback aptico qui
        // Ad esempio, utilizza Core Haptics, UIKit, o un'altra libreria appropriata
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
        UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")
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
        }
    }


    // Function to stop recording
    func stopRecording() {
        guard isRecording else {
            return
        }

        // Set recording state and button color
        isRecording = false
        buttonColor = .blue

        // Stop AVAudioRecorder and deallocate resources
        audioRecorder?.stop()
        audioRecorder?.delegate = nil
        audioRecorder = nil

        // Save the record number and load previous records
        UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")
        loadPreviousRecords()
    }

    // Function to load previous records
    func loadPreviousRecords() {
        if let number = UserDefaults.standard.object(forKey: "myNumber") as? Int {
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
                    ForEach(0..<audioRecorderManager.numberOfRecords, id: \.self) { index in
                        if !audioRecorderManager.recordings.isEmpty, audioRecorderManager.recordings.indices.contains(index) {
                            let recordingURL = audioRecorderManager.recordings[index]

                            NavigationLink(
                                destination: RecordingDetailView(recordURL: recordingURL, index: index, audioRecorderManager: audioRecorderManager, newName: ""),
                                label: {
                                    Text("Recording \(index + 1)")
                                }
                            )
                        }
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

                // Display dominant frequencies
                Text("Dominant Frequencies: \(audioRecorderManager.dominantFrequencies.map { String($0) }.joined(separator: ", "))")
                    .padding()
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

private func findMainHarmonicFrequency(_ magnitude: [Float], sampleRate: Double, bufferSize: Int) -> Float {
    guard let maxIndex = magnitude.indices.max(by: { magnitude[$0] < magnitude[$1] }) else {
        return 0.0
    }

    let mainHarmonicFrequency = Float(maxIndex) * Float(sampleRate) / Float(bufferSize)
    return mainHarmonicFrequency
}

// RecordingDetailView to accept the new name and rename handler
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
                Text("Recording Detail: \(audioRecorderManager.recordings[index].lastPathComponent)")
                    .navigationBarTitle("Recording Detail")
            }

            // Button to analyze frequency for the current recording
            Button(action: {
                audioRecorderManager.findDominantFrequencyInAudioFile(at: recordURL, sampleRate: 44100.0)
            }) {
                Text("Analyze Frequency")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(40)
            }
        }
        .padding()
    }
}

