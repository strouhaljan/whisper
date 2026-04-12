import Accelerate
import AVFoundation

/// Runs a real-valued FFT on an audio buffer and returns logarithmically-
/// spaced frequency-band levels focused on the human voice range (80 Hz – 4 kHz).
final class SpectrumAnalyzer {
    let bandCount: Int

    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private let window: [Float]

    // Frequency range to analyse (Hz). Covers fundamental voice pitch
    // through upper formants/harmonics — everything outside is ignored.
    private let minFreq: Double = 80
    private let maxFreq: Double = 4000

    // Pre-allocated work buffers (reused every frame, audio-thread only).
    private var realp: [Float]
    private var imagp: [Float]
    private var smoothed: [Float]
    private let smoothing: Float = 0.35  // exponential moving average weight

    init(fftSize: Int = 1024, bandCount: Int = 16) {
        precondition(fftSize > 0 && (fftSize & (fftSize - 1)) == 0, "fftSize must be a power of 2")
        self.fftSize = fftSize
        self.bandCount = bandCount
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!

        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = w

        let halfN = fftSize / 2
        self.realp = [Float](repeating: 0, count: halfN)
        self.imagp = [Float](repeating: 0, count: halfN)
        self.smoothed = [Float](repeating: 0, count: bandCount)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Analyse a single buffer and return `bandCount` values in 0…1.
    /// Safe to call from the audio-render thread.
    func analyze(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0, count: bandCount)
        }

        let frameCount = Int(buffer.frameLength)
        let n = min(frameCount, fftSize)
        guard n > 0 else { return Array(repeating: 0, count: bandCount) }

        let sampleRate = buffer.format.sampleRate

        // 1. Apply Hann window (zero-pad if n < fftSize).
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // 2. Pack real signal into split-complex form for zrip.
        let halfN = fftSize / 2
        windowed.withUnsafeBufferPointer { src in
            src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cp in
                realp.withUnsafeMutableBufferPointer { rBuf in
                    imagp.withUnsafeMutableBufferPointer { iBuf in
                        var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                        vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
            }
        }

        // 3. In-place real-to-complex FFT.
        var magnitudes = [Float](repeating: 0, count: halfN)
        realp.withUnsafeMutableBufferPointer { rBuf in
            imagp.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }

        // 4. Square-root to get true magnitudes (zvmags returns squared).
        var count = Int32(halfN)
        vvsqrtf(&magnitudes, magnitudes, &count)

        // 5. Group into bands within the voice-frequency range, normalise, and smooth.
        let raw = groupIntoBands(magnitudes, sampleRate: sampleRate)
        for i in 0..<bandCount {
            smoothed[i] = smoothing * smoothed[i] + (1 - smoothing) * raw[i]
        }
        return smoothed
    }

    private func groupIntoBands(_ magnitudes: [Float], sampleRate: Double) -> [Float] {
        let binCount = magnitudes.count  // fftSize / 2
        let hzPerBin = sampleRate / Double(fftSize)
        var bands = [Float](repeating: 0, count: bandCount)

        // Logarithmic subdivision of minFreq…maxFreq.
        let logMin = log2(minFreq)
        let logMax = log2(maxFreq)

        for i in 0..<bandCount {
            let loHz = pow(2.0, logMin + (logMax - logMin) * Double(i) / Double(bandCount))
            let hiHz = pow(2.0, logMin + (logMax - logMin) * Double(i + 1) / Double(bandCount))

            let loBin = max(1, Int((loHz / hzPerBin).rounded()))
            let hiBin = min(binCount, Int((hiHz / hzPerBin).rounded()))
            guard loBin < hiBin else { continue }

            var sum: Float = 0
            for j in loBin..<hiBin { sum += magnitudes[j] }
            let avg = sum / Float(hiBin - loBin)

            // Map to 0…1 via dB scale: −45 dB → 0, −5 dB → 1.
            // This range is tuned for typical close-mic speech levels.
            let dB = 20 * log10(max(avg, 1e-8))
            bands[i] = max(0, min(1, (dB + 45) / 40))
        }
        return bands
    }
}
