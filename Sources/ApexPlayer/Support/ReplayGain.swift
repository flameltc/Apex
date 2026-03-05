import Foundation

enum ReplayGain {
    static func linearGain(fromDb db: Double) -> Double {
        pow(10, db / 20)
    }

    static func effectiveGain(info: ReplayGainInfo, useAlbum: Bool = false) -> Double {
        let db = useAlbum ? (info.albumGainDb ?? info.trackGainDb ?? 0) : (info.trackGainDb ?? info.albumGainDb ?? 0)
        return clamp(linearGain(fromDb: db), min: 0.1, max: 3.0)
    }

    static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}
