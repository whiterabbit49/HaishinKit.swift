// Audio-only Opus SRT probe: feeds synthetic PCM directly into an SRTStream
// (no mixer, no mic) to exercise the fork's encode+MPEG-TS mux path against a
// local MediaMTX. Run: swift run TcOpusProbe
import AVFoundation
import Foundation
import HaishinKit
import SRTHaishinKit
import Foundation

@main
struct TcOpusProbe {
    static func main() async throws {
        let connection = SRTConnection()
        let stream = SRTStream(connection: connection)
        try await stream.setAudioSettings(
            AudioCodecSettings(bitRate: 128_000, downmix: true, sampleRate: 48_000, format: .opus)
        )
        await stream.setExpectedMedias([.audio])

        FileManager.default.createFile(atPath: "/tmp/tsdump.ts", contents: nil)
        TCTSDump.url = URL(fileURLWithPath: "/tmp/tsdump.ts")
        try await connection.connect(URL(string: "srt://127.0.0.1:8890?streamid=publish:macprobe"))
        try await stream.publish()

        let pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false
        )!
        let pcm = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 1024)!
        pcm.frameLength = 1024
        // 440 Hz sine — digital silence triggers Opus DTX (zero-length frames).
        if let ch0 = pcm.floatChannelData?[0], let ch1 = pcm.floatChannelData?[1] {
            for n in 0..<1024 {
                let v = sin(2 * .pi * 440 * Float(n) / 48_000) * 0.3
                ch0[n] = v
                ch1[n] = v
            }
        }

        print("[TCDBG-PROBE] appending synthetic PCM as opus for 15s...")
        let start = AVAudioTime(hostTime: mach_absolute_time())
        for i in 0..<690 {
            let when = AVAudioTime(hostTime: mach_absolute_time())
            await stream.append(pcm, when: when)
            if i % 92 == 0 {
                print("[TCDBG-PROBE] t=\(i / 46)s appended=\(i + 1)")
            }
            // 1024 frames @48kHz ≈ 21.3ms
            try await Task.sleep(nanoseconds: 21_333_333)
        }
        _ = start
        await connection.close()
        print("[TCDBG-PROBE] done")
    }
}
