// Build and run from repository root:
// clang -O2 -I platforms/macos/Sources/FirehawkDSP/include -c platforms/macos/Sources/FirehawkDSP/FirehawkDSP.c -o /tmp/firehawk-dsp.o
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftc -O -import-objc-header platforms/macos/Sources/FirehawkDSP/include/FirehawkDSP.h scripts/audio/benchmark-library.swift /tmp/firehawk-dsp.o -o /tmp/firehawk-library-benchmark
// /tmp/firehawk-library-benchmark
import AVFoundation
import Darwin
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("platforms/macos/Sources/FirehawkFocus/Resources/Ambience")
let dsp = fh_create(44100, 8)!
let names = ["wind", "forest", "birds", "fan", "night-insects", "stream"]
func install(_ name: String, index: Int) throws {
    let file = try AVAudioFile(forReading: root.appendingPathComponent(name + ".flac"))
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    precondition(fh_set_buffer(dsp, Int32(index), buffer.floatChannelData![0], buffer.floatChannelData![1], buffer.frameLength) == 1)
}
for (i, name) in names.enumerated() { try install(name, index: i); fh_layer(dsp, Int32(i), 0, 1, 0.5, 60, 0.04) }
fh_layer(dsp, 6, 2, 1, 0.5, 60, 0.04); fh_layer(dsp, 7, 3, 1, 0.5, 60, 0.04)
fh_master(dsp, 1, 0.3); fh_tone(dsp, 0, 220, 10, 0.8, 0.3, 0.3)
var l = [Float](repeating: 0, count: 512), r = l
var start = timespec(), end = timespec()
clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &start)
for _ in 0..<Int(44100*60/512) { fh_render(dsp, &l, &r, 512) }
clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &end)
let cpu = Double(end.tv_sec-start.tv_sec) + Double(end.tv_nsec-start.tv_nsec) / 1e9
var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
print(String(format: "Six recordings + pink + brown + tone: DSP %.2f MiB; process peak RSS %.2f MiB; CPU %.3fs per 60s audio = %.2f%% one core", Double(fh_memory(dsp))/1048576, Double(usage.ru_maxrss)/1048576, cpu, 100*cpu/60))
fh_destroy(dsp)
