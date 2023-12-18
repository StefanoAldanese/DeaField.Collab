//
//  ContentView.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    // Stati per gestire la registrazione e la visualizzazione degli alert
    @State private var isRecording = false
    @State private var numberOfRecords = 0
    @State private var recordings: [URL] = []
    @State private var showAlert = false
    @State private var showStopAlert = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var buttonColor: Color = .blue
    // Variabile di stato per gestire la modifica del nome del file
    @State private var newName = ""
    @State private var currentlyEditingIndex: Int?

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(0..<numberOfRecords, id: \.self) { index in
                        if index < recordings.count {
                            NavigationLink(
                                destination: RecordingDetailView(recordURL: recordings[index], index: index, recordings: $recordings, onRename: {
                                    loadPreviousRecords()  // Aggiorna la lista dei record
                                }),
                                label: {
                                    Text("\(newName(forIndex: index))")
                                }
                            )
                        }
                    }
                    .onDelete(perform: deleteRecording)
                }
                .padding(10)

                Button(action: {
                    toggleRecording()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .padding()
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(40)
                }
            }
            .padding(10)
            .navigationBarTitle("Voice Memos")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Microphone Access"),
                    message: Text("This app requires access to your microphone to record audio. Enable access in Settings."),
                    primaryButton: .default(Text("Settings")) {
                        openSettings()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showStopAlert) {
                Alert(
                    title: Text("Stop Recording"),
                    message: Text("Do you want to stop the recording?"),
                    primaryButton: .default(Text("Yes")) {
                        stopRecording()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                loadPreviousRecords()
                requestRecordPermission()
            }
        }
    }
    
    // RecordingDetailView per accettare il nuovo nome e il gestore di rinomina
    struct RecordingDetailView: View {
        var recordURL: URL
        var index: Int
        @Binding var recordings: [URL]
        var onRename: () -> Void

        @State private var newName: String // Variabile temporanea per la modifica
        @State private var isEditing = false

        init(recordURL: URL, index: Int, recordings: Binding<[URL]>, onRename: @escaping () -> Void) {
            self.recordURL = recordURL
            self.index = index
            self._recordings = recordings
            self.onRename = onRename
            self._newName = State(initialValue: recordURL.lastPathComponent)
        }

        var body: some View {
            VStack {
                if isEditing {
                    TextField("Enter a new name", text: $newName, onCommit: {
                        guard !newName.isEmpty else { return }
                        recordings[index] = recordURL.deletingLastPathComponent().appendingPathComponent(newName)
                        onRename()
                        isEditing = false
                    })
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text("Recording Detail: \(recordings[index].lastPathComponent)")
                        .navigationBarTitle("Recording Detail")
                }

                Button("Rename") {
                    isEditing.toggle()
                }
            }
            .padding()
        }
    }

    func newName(forIndex index: Int) -> String {
        if isEditingRecording(index: index) {
            return newName
        } else {
            return "Recording \(index + 1)"
        }
    }
    
    func isEditingRecording(index: Int) -> Bool {
        return index < recordings.count && index == currentlyEditingIndex
    }

    func renameRecording(at index: Int, to newName: String) {
        let recordingURL = recordings[index]
        let newURL = getDirectory().appendingPathComponent("\(newName).m4a")

        do {
            try FileManager.default.moveItem(at: recordingURL, to: newURL)
            recordings[index] = newURL
            loadPreviousRecords()  // Carica nuovamente i record per aggiornare la vista
        } catch {
            print("Error renaming recording: \(error.localizedDescription)")
        }
    }
    
    // Funzione per eliminare una registrazione
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

    func toggleRecording() {
        if isRecording {
            showStopAlert = true
        } else {
            // Assegna un nome predefinito quando inizi a registrare
            newName = "Recording \(numberOfRecords + 1)"
            startRecording()
            buttonColor = .red
        }
    }

    // Funzione per avviare la registrazione
    func startRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)

            // Incrementa il numero di record e imposta il nome del file
            numberOfRecords += 1
            let filename = getDirectory().appendingPathComponent("\(numberOfRecords).m4a")

            // Impostazioni per la registrazione audio
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // Crea e avvia l'AVAudioRecorder
            audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
            audioRecorder?.delegate = context
            audioRecorder?.record()
            isRecording = true
        } catch {
            // Gestisci l'errore di registrazione
            displayAlert(title: "Ups!", message: "Recording failed")
        }
    }

    // Funzione per interrompere la registrazione
    func stopRecording() {
        guard isRecording else {
            return
        }

        // Imposta lo stato di registrazione e il colore del bottone
        isRecording = false
        buttonColor = .blue

        // Interrompi l'AVAudioRecorder e dealloca le risorse
        audioRecorder?.stop()
        audioRecorder?.delegate = nil
        audioRecorder = nil

        // Salva il numero di record e carica i record precedenti
        UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")
        loadPreviousRecords()
    }

    // Funzione per caricare i record precedenti
    func loadPreviousRecords() {
        if let number = UserDefaults.standard.object(forKey: "myNumber") as? Int {
            numberOfRecords = number
            recordings = (1...number).map {
                getDirectory().appendingPathComponent("\($0).m4a")
            }
        }
    }

    // Funzione per richiedere il permesso di registrazione
    func requestRecordPermission() {
        AVAudioApplication.requestRecordPermission() { hasPermission in
            if !hasPermission {
                showAlert = true
            }
        }
    }

    // Funzione per ottenere il percorso della directory documenti
    func getDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Funzione per aprire le impostazioni dell'app
    func openSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }

    // Funzione per visualizzare un alert
    func displayAlert(title: String, message: String) {
        showAlert = true
    }
}

// Anteprima della vista
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Classe Coordinator per gestire gli eventi dell'AVAudioRecorderDelegate
class Coordinator: NSObject, AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Gestisce la registrazione terminata
        if !flag {
            // Implementa eventuali logiche aggiuntive per una registrazione non riuscita
        }
    }
}

// Estensione ContentView per ottenere un'istanza di Coordinator
extension ContentView {
    var context: Coordinator {
        Coordinator()
    }
}
