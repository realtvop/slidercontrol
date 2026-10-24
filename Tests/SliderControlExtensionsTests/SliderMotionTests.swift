import XCTest
@testable import SliderControl

final class SliderMotionTests: XCTestCase {
    func testProgressClampsAndReversesImmediately() {
        var motion = SliderMotion()
        motion.drag(by: 2, allowsOvershoot: false)
        XCTAssertEqual(motion.position, 1)
        XCTAssertEqual(motion.stretch(trackWidth: 300).amount, 0)
        motion.drag(by: -0.1, allowsOvershoot: false)
        XCTAssertEqual(motion.progress, 0.9, accuracy: 0.0001)
        motion.drag(by: -2, allowsOvershoot: false)
        XCTAssertEqual(motion.position, 0)
        motion.drag(by: 0.1, allowsOvershoot: false)
        XCTAssertEqual(motion.progress, 0.1, accuracy: 0.0001)
    }

    func testVolumeCoastsAndSettlesAtEitherRefreshRate() {
        func settledProgress(fps: Double) -> CGFloat {
            var motion = SliderMotion()
            XCTAssertTrue(motion.release(velocity: 1))
            for _ in 0..<240 {
                if !motion.advance(by: 1 / fps) { break }
            }
            XCTAssertEqual(motion.velocity, 0)
            return motion.progress
        }
        let at60Hz = settledProgress(fps: 60)
        XCTAssertGreaterThan(at60Hz, 0.6)
        XCTAssertEqual(at60Hz, settledProgress(fps: 120), accuracy: 0.001)
    }

    func testBothVolumeBoundariesBounceWithoutChangingValue() {
        for boundary in [CGFloat(0), 1] {
            let direction: CGFloat = boundary == 0 ? -1 : 1
            var motion = SliderMotion()
            motion.reset(to: boundary)
            motion.drag(by: direction * 0.3, allowsOvershoot: true)
            let stretch = motion.stretch(trackWidth: 300)
            XCTAssertGreaterThan(stretch.amount, 0)
            XCTAssertLessThan(stretch.amount, 12)
            XCTAssertEqual(stretch.edge, direction)
            XCTAssertTrue(motion.release(velocity: direction * 2))
            var settled = false
            for _ in 0..<240 {
                let moving = motion.advance(by: 1.0 / 120)
                XCTAssertEqual(motion.progress, boundary)
                if !moving {
                    settled = true
                    break
                }
            }
            XCTAssertTrue(settled)
            XCTAssertEqual(motion.position, boundary)
            XCTAssertEqual(motion.stretch(trackWidth: 300).amount, 0)
        }
    }

    func testInertiaReachesBoundaryAndCanBeInterrupted() {
        var motion = SliderMotion()
        motion.reset(to: 0.95)
        XCTAssertTrue(motion.release(velocity: 3))
        _ = motion.advance(by: 1.0 / 30)
        XCTAssertEqual(motion.progress, 1)
        XCTAssertNotNil(motion.springBoundary)
        motion.reset(to: 0.4)
        XCTAssertEqual(motion.progress, 0.4)
        XCTAssertNil(motion.springBoundary)
        XCTAssertFalse(motion.release(velocity: 0))
    }
}
