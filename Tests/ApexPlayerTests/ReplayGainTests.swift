import XCTest
@testable import ApexPlayer

final class ReplayGainTests: XCTestCase {
    func testLinearGainFromDb() {
        let gain = ReplayGain.linearGain(fromDb: -6)
        XCTAssertEqual(gain, 0.501, accuracy: 0.01)
    }

    func testEffectiveGainUsesTrackFirst() {
        let info = ReplayGainInfo(trackGainDb: -4, albumGainDb: -8, peak: nil)
        let gain = ReplayGain.effectiveGain(info: info)
        XCTAssertEqual(gain, ReplayGain.linearGain(fromDb: -4), accuracy: 0.0001)
    }

    func testEffectiveGainClamped() {
        let high = ReplayGainInfo(trackGainDb: 40, albumGainDb: nil, peak: nil)
        XCTAssertEqual(ReplayGain.effectiveGain(info: high), 3.0, accuracy: 0.0001)

        let low = ReplayGainInfo(trackGainDb: -80, albumGainDb: nil, peak: nil)
        XCTAssertEqual(ReplayGain.effectiveGain(info: low), 0.1, accuracy: 0.0001)
    }
}
