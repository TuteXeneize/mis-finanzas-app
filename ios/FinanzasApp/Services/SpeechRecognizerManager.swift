import Foundation
import Speech
import AVFoundation

final class SpeechRecognizerManager: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String? = nil
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-AR")) ?? SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    
    func startRecording(onTextUpdate: @escaping (String) -> Void) {
        // 1. Solicitar permisos de reconocimiento de voz
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard status == .authorized else {
                    self.errorMessage = "Se requiere autorización para reconocimiento de voz."
                    return
                }
                
                // 2. Solicitar permiso de micrófono
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        guard granted else {
                            self.errorMessage = "Se requiere permiso de acceso al micrófono."
                            return
                        }
                        self.beginAudioSession(onTextUpdate: onTextUpdate)
                    }
                }
            }
        }
    }
    
    private func beginAudioSession(onTextUpdate: @escaping (String) -> Void) {
        stopRecording()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "No se pudo iniciar la sesión de audio."
            return
        }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            self.isRecording = true
        } catch {
            self.errorMessage = "No se pudo iniciar el motor de audio."
            return
        }
        
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    let transcript = result.bestTranscription.formattedString
                    self.recognizedText = transcript
                    onTextUpdate(transcript)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        
        audioEngine = nil
        request = nil
        task = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
