//
//  RecordingViewModel.swift
//  Deafield
//
//  Created by Davide Perrotta on 16/12/23.
//

import Foundation
import AudioKit
import SwiftUI

class RecordingViewModel: ObservableObject {
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var silence: AKBooster!

    @Published var amplitude: Double = 0.0

    init() {
        AKSettings.audioInputEnabled = true
        mic = AKMicrophone()
        tracker = AKFrequencyTracker(mic)
        silence = AKBooster(tracker, gain: 0)

        do {
            try AKSettings.setSession(category: .playAndRecord, with: .defaultToSpeaker)
        } catch {
            AKLog("Errore durante la configurazione della sessione di AudioKit.")
        }
    }

    func start() {
        do {
            try AudioKit.start()
            try mic.start()
        } catch {
            AKLog("Errore durante l'avvio di AudioKit.")
        }
    }

    func stop() {
        do {
            try AudioKit.stop()
            try mic.stop()
        } catch {
            AKLog("Errore durante l'arresto di AudioKit.")
        }
    }

    func updateAmplitude() {
        amplitude = tracker.amplitude
    }
}
