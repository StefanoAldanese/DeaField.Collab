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
        // Duration of the segment in seconds
        let segmentDuration = 1.0
        let segmentSamples = Int(sampleRate * segmentDuration)

        // Extract the current segment
        let segment = Array(samples.prefix(segmentSamples))

        // Calculate autocorrelation
        var autocorrelation = [Float](repeating: 0.0, count: segmentSamples)
        vDSP_conv(segment, 1, segment.reversed(), 1, &autocorrelation, 1, vDSP_Length(segmentSamples), vDSP_Length(segmentSamples))

        // Find the peak in the autocorrelation function
        var peakIndex: vDSP_Length = 0
        var peakValue: Float = 0.0
        vDSP_maxvi(autocorrelation, 1, &peakValue, &peakIndex, vDSP_Length(autocorrelation.count))

        // Check if peakIndex is within a valid range
        guard peakIndex > 0 && peakIndex < vDSP_Length(segmentSamples) else {
            print("Invalid peakIndex: \(peakIndex)")
            return nil
        }

        // Calculate the corresponding frequency
        let fundamentalFrequency = Double(sampleRate) / Double(peakIndex)

        // Check if the fundamental frequency is finite
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

            let segmentDuration: Double = 1 // Durata del segmento in secondi
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
    @State private var showWelcomeSheet = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

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
            .navigationBarTitle("Records")
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
                
                // Imposta il valore di hasLaunchedBefore a true dopo la prima apertura
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
            .sheet(isPresented: $showWelcomeSheet) {
                WelcomeView {
                    showWelcomeSheet = false
                }
                .background(Color(UIColor.systemBackground))
            }
        }
    }
}

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack {
            
            Spacer()
            
            // Icona di sistema
            Image("icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
                .padding(10)

            Text("DeaField welcomes you")
                .font(.title)
                .fontWeight(.bold)
                .padding()

            Text("Experience a new world of music perception, tailored to enhance your auditory journey even with hearing disabilities. Are you ready to embark on this discovery?")
                .font(.body)
                    .padding()
                    .multilineTextAlignment(.center) // Allineamento al centro
                    .lineSpacing(8)

            Spacer()

            Button(action: {
                onContinue()
            }) {
                Text("Continue                                                                       ")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)

            
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .padding(20)
        .transition(.move(edge: .bottom))
    }
}

class HapticEngineManager: ObservableObject {
    @Published var engine: CHHapticEngine?

    init() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Error initializing Core Haptics engine: \(error.localizedDescription)")
        }
    }
}



extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension UserDefaults {
    static var isFirstLaunch: Bool {
        get { !standard.bool(forKey: "hasLaunchedBefore") }
        set { standard.set(!newValue, forKey: "hasLaunchedBefore") }
    }
}

final class HapticManager: ObservableObject {
    internal var engine: CHHapticEngine?
    
    init() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Error initializing Core Haptics engine: \(error.localizedDescription)")
        }
    }

    func triggerCustomHapticFeedback(with vibrationIdentifier: String, sharpness: Float, intensity: Float) {
        guard let engine = engine else {
            print("Haptic engine is not available.")
            return
        }

        do {
            let event = try CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.start()

            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error triggering haptic feedback: \(error.localizedDescription)")
        }
    }
}

struct RecordingDetailView: View {
    var recordURL: URL
    var index: Int
    @ObservedObject var audioRecorderManager: AudioRecorderManager
    @ObservedObject var hapticManager = HapticManager()
    
    @State private var newName: String // Temporary variable for editing
    @State private var isEditing = false
    @State private var buttonColor: Color = .green
    @State private var buttonText: String = "Analyze Frequency"
    @State private var currentIndex: Int = 0
    @State private var enjoyState: EnjoyState = .analyzing
    
    // Haptic Engine & Player State:
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    enum EnjoyState {
        case analyzing
        case enjoying
    }
    
    init(recordURL: URL, index: Int, audioRecorderManager: AudioRecorderManager, newName: String) {
        self.recordURL = recordURL
        self.index = index
        self.audioRecorderManager = audioRecorderManager
        self._newName = State(initialValue: newName)
    }
    
    var body: some View {
        VStack {
            if isEditing {
                TextField("Enter a new name", text: $newName, onCommit: {
                    guard !self.newName.isEmpty else { return }
                    self.audioRecorderManager.recordings[self.index] = self.recordURL.deletingLastPathComponent().appendingPathComponent(self.newName)
                    self.audioRecorderManager.loadPreviousRecords()  // Update the record list
                    self.isEditing = false
                })
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                if let recordingURL = audioRecorderManager.recordings[safe: index] {
                    Text("Recording Detail: \(recordingURL.lastPathComponent)")
                        .navigationBarTitle("Recording Detail")
                    
                    Button(action: {
                        if let recordingURL = self.audioRecorderManager.recordings[safe: self.index], FileManager.default.fileExists(atPath: recordingURL.path) {
                            let sampleRate = 12000.0
                            
                            let dominantFrequencies = self.audioRecorderManager.findDominantFrequencyInAudioFile(at: recordingURL, sampleRate: sampleRate)
                            
                            if !dominantFrequencies.isEmpty {
                                for (index, frequency) in dominantFrequencies.enumerated() {
                                    Timer.scheduledTimer(withTimeInterval: 0.3 * Double(index), repeats: false) { _ in
                                        withAnimation {
                                            switch frequency {
                                            case 1.0000000000000000...1.0009396499429402:
                                                print("Case 1 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.0009396499429403...1.0037959596075241:
                                                print("Case 2 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.0037959596075242...1.0437959596075242:
                                                print("Case 3 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.0437959596075243...1.0875085789366918:
                                                print("Case 4 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.0875085789366919...1.248829222603808:
                                                print("Case 5 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.248829222603809...1.4570920549926319:
                                                print("Case 6 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 1)

                                            case 1.4580801944106927...1.7258737235725585:
                                                print("Case 7 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 0.5)

                                            case 1.7482517482517483...3.623473254759746:
                                                print("Case 8 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 0.5)

                                            case 3.626473254759747...50.42016806722689:
                                                print("Case 9 for frequency \(frequency)")
                                                self.updateEnjoyStateAndStartTimer(with: "Case1Vibration", sharpness: 0.5, intensity: 0.5)

                                            // Add more cases as needed...

                                            default:
                                                print("The frequency \(frequency) is NOT handled by any case")
                                                self.updateEnjoyStateAndStartTimer(with: "DefaultVibration", sharpness: 0.5, intensity: 0.5)
                                            }
                                        }
                                    }
                                }
                            } else {
                                print("No dominant frequencies found")
                            }
                        } else {
                            print("Recording does not exist")
                        }
                    }) {
                        Text(enjoyState == .analyzing ? "Analyze Frequency" : "Enjoy")
                            .padding()
                            .background(enjoyState == .analyzing ? buttonColor : .red)
                            .foregroundColor(.white)
                            .cornerRadius(40)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            do {
                try self.hapticManager.engine?.start()
            } catch {
                print("Error starting Core Haptics engine: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateEnjoyStateAndStartTimer(with vibrationIdentifier: String, sharpness: Float, intensity: Float) {
        withAnimation {
            enjoyState = .enjoying
        }

        hapticManager.triggerCustomHapticFeedback(with: vibrationIdentifier, sharpness: sharpness, intensity: intensity)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                self.enjoyState = .analyzing
            }
        }
    }
}
