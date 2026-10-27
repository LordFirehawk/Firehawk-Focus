#!/usr/bin/env swift
// Print candidate 40-second windows with the lowest peak/RMS ratio. This does not detect speech or approve quality.
import AVFoundation
import Foundation
for path in CommandLine.arguments.dropFirst() {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let block = AVAudioFrameCount(file.processingFormat.sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
    var stats: [(Double, Double)] = []
    while file.framePosition + Int64(block) <= file.length {
        try file.read(into: buffer, frameCount: block)
        let pcm = buffer.floatChannelData!
        var energy = 0.0, peak = 0.0
        for c in 0..<Int(file.processingFormat.channelCount) {
            for i in 0..<Int(buffer.frameLength) { let v = Double(pcm[c][i]); energy += v*v; peak = max(peak, abs(v)) }
        }
        stats.append((energy / Double(buffer.frameLength * file.processingFormat.channelCount), peak))
    }
    guard stats.count > 40 else { continue }
    let candidates = (0...(stats.count-40)).map { start -> (Int, Double) in
        let window = stats[start..<(start+40)]
        let rms = sqrt(window.reduce(0) { $0 + $1.0 } / 40)
        return (start, 20 * log10(max(window.map(\.1).max()!,1e-10) / max(rms,1e-10)))
    }.sorted { $0.1 < $1.1 }
    print(path, candidates.prefix(3))
}
