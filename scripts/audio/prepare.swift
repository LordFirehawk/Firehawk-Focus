#!/usr/bin/env swift
// Usage: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift scripts/audio/prepare.swift input output.caf startSeconds durationSeconds [overlapSeconds] [audition.m4a] [peakKneeRMS]
// Lossless originals/masters belong outside the repository. Default output is stereo PCM16 CAF at 44.1 kHz.
// Bundled delivery encodes that PCM to FLAC level 8 (see encode_flac.py / verify-lossless.py).
import AVFoundation
import Foundation
let args = CommandLine.arguments
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
guard args.count >= 5, let start = Double(args[3]), let duration = Double(args[4]),
      start >= 0, duration > 3, duration <= 240 else { fail("Expected input output.caf startSeconds durationSeconds (3...240) [overlapSeconds]") }
let overlap = args.count > 5 ? Double(args[5]) ?? 2 : 2
// Zero overlap is reserved for event-grid montages with silent, verified seams.
guard overlap >= 0, overlap < duration / 2 else { fail("Invalid overlap") }
let file = try AVAudioFile(forReading: URL(fileURLWithPath: args[1]))
let inputFormat = file.processingFormat
let frames = AVAudioFrameCount(duration * inputFormat.sampleRate)
file.framePosition = AVAudioFramePosition(start * inputFormat.sampleRate)
guard let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frames) else { fail("Input allocation failed") }
try file.read(into: input, frameCount: frames)
guard input.frameLength == frames else { fail("Selected segment extends beyond the original recording") }
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
guard let converter = AVAudioConverter(from: inputFormat, to: format),
      let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(duration * 44100 + 4096)) else { fail("Conversion setup failed") }
var supplied = false
var conversionError: NSError?
converter.convert(to: converted, error: &conversionError) { _, status in
    if supplied { status.pointee = .endOfStream; return nil }
    supplied = true; status.pointee = .haveData; return input
}
if let conversionError { throw conversionError }
let n = Int(converted.frameLength), cross = Int(overlap * 44100), count = n - cross
guard count > cross, let pcm = converted.floatChannelData,
      let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { fail("Insufficient samples") }
output.frameLength = AVAudioFrameCount(count)
let out = output.floatChannelData!
// Rotate away the original head. The final overlap blends original tail into original head,
// which is immediately followed by the original head's next sample at the loop boundary.
for channel in 0..<2 {
    for i in 0..<count {
        if i < count - cross { out[channel][i] = pcm[channel][i + cross] }
        else {
            let j = i - (count - cross), phase = Double(j) / Double(cross - 1) * .pi / 2
            out[channel][i] = pcm[channel][i + cross] * Float(cos(phase)) + pcm[channel][j] * Float(sin(phase))
        }
    }
}
var energy = 0.0, peak = 0.0
for c in 0..<2 { for i in 0..<count { let v = Double(out[c][i]); energy += v*v; peak = max(peak, abs(v)) } }
let inputRMS = sqrt(energy / Double(count * 2))
guard inputRMS > 1e-6 else { fail("Selected segment is effectively silent") }
// Gently reduce isolated peaks when they would prevent consistent RMS matching.
let kneeMultiple = args.count > 7 ? Double(args[7]) ?? 6 : 6
guard kneeMultiple > 0 else { fail("Invalid peak knee") }
let compressed = peak / inputRMS > pow(10, 17.0 / 20)
if compressed {
    let knee = kneeMultiple * inputRMS
    energy = 0; peak = 0
    for c in 0..<2 { for i in 0..<count {
        let v = knee * tanh(Double(out[c][i]) / knee)
        out[c][i] = Float(v); energy += v*v; peak = max(peak, abs(v))
    } }
}
let rms = sqrt(energy / Double(count * 2))
// RMS matching is reproducible; this is not an integrated LUFS measurement.
let gain = min(pow(10, -23.0 / 20) / max(rms, 1e-9), pow(10, -6.0 / 20) / max(peak, 1e-9))
for c in 0..<2 { for i in 0..<count { out[c][i] *= Float(gain) } }
let pcmSettings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
// AAC's container stores valid-frame and priming metadata; AVAudioFile reads only
// those valid frames. Asset tests verify the decoded length and seam.
let settings: [String: Any] = URL(fileURLWithPath: args[2]).pathExtension == "m4a"
    ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
       AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256000] : pcmSettings
var destination: AVAudioFile? = try AVAudioFile(forWriting: URL(fileURLWithPath: args[2]), settings: settings)
try destination!.write(from: output)
destination = nil // Flush the final PCM packets before reporting completion.
print(String(format: "frames=%d seconds=%.3f input_rms_dbfs=%.2f output_rms_dbfs=%.2f output_peak_dbfs=%.2f gain_db=%.2f soft_peak_reduction=%d", count, Double(count)/44100, 20*log10(max(inputRMS,1e-9)),20*log10(max(rms*gain,1e-9)),20*log10(max(peak*gain,1e-9)),20*log10(gain), compressed ? 1 : 0))

// Optional un-looped, level-matched selection for Finder auditioning.
if args.count > 6 {
    for c in 0..<2 { for i in 0..<n {
        let v = Double(pcm[c][i])
        pcm[c][i] = Float((compressed ? kneeMultiple * inputRMS * tanh(v / (kneeMultiple * inputRMS)) : v) * gain)
    } }
    let auditionSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000]
    let audition = try AVAudioFile(forWriting: URL(fileURLWithPath: args[6]), settings: auditionSettings)
    try audition.write(from: converted)
}
