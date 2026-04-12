import AVFoundation

/// Records microphone input to a temporary .wav file via AVAudioEngine
/// while simultaneously feeding an FFT spectrum analyser.
final class AudioRecorder {
    /// Called on the main queue with per-band spectrum levels (0…1) while recording.
    var onSpectrum: (([Float]) -> Void)?

    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var currentURL: URL?

    private let analyzer = SpectrumAnalyzer(fftSize: 1024, bandCount: 16)

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                cont.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    cont.resume(returning: granted)
                }
            default:
                cont.resume(returning: false)
            }
        }
    }

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-\(UUID().uuidString).wav")

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        let audioFile = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: hwFormat.sampleRate,
            AVNumberOfChannelsKey: hwFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ])

        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(1024),
            format: hwFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }
            try? audioFile.write(from: buffer)
            let spectrum = self.analyzer.analyze(buffer: buffer)
            DispatchQueue.main.async {
                self.onSpectrum?(spectrum)
            }
        }

        self.engine = engine
        self.audioFile = audioFile
        self.currentURL = url

        try engine.start()
    }

    /// Stops recording and returns the file URL of the recorded audio.
    func stop() -> URL? {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        audioFile = nil
        let url = currentURL
        currentURL = nil
        let zeroes = Array(repeating: Float(0), count: analyzer.bandCount)
        DispatchQueue.main.async { [weak self] in
            self?.onSpectrum?(zeroes)
        }
        return url
    }
}
