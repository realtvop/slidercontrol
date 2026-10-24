import Foundation

/// Normalized motion, independent of layout and the public value range.
struct SliderMotion {
    private(set) var position: CGFloat = 0.5
    private(set) var velocity: CGFloat = 0
    private(set) var springBoundary: CGFloat?

    var progress: CGFloat {
        // A boundary bounce is visual only; it must not turn volume back down/up.
        springBoundary ?? min(1, max(0, position))
    }

    mutating func reset(to progress: CGFloat) {
        position = min(1, max(0, progress))
        velocity = 0
        springBoundary = nil
    }

    mutating func drag(by translation: CGFloat, allowsOvershoot: Bool) {
        position += translation
        if !allowsOvershoot {
            position = progress
        }
    }

    mutating func release(velocity: CGFloat) -> Bool {
        self.velocity = min(5, max(-5, velocity))
        if position < 0 || position > 1 {
            springBoundary = progress
        }
        return springBoundary != nil || abs(self.velocity) > 0.02
    }

    /// Returns whether another display frame is needed.
    mutating func advance(by elapsed: TimeInterval) -> Bool {
        let dt = CGFloat(min(max(elapsed, 0), 1.0 / 30))
        if let boundary = springBoundary {
            // Exact damped spring integration keeps 60 Hz and 120 Hz consistent.
            let damping: CGFloat = 12
            let stiffness: CGFloat = 240
            let frequency = sqrt(stiffness - damping * damping)
            let displacement = position - boundary
            let decay = exp(-damping * dt)
            let sine = sin(frequency * dt)
            let cosine = cos(frequency * dt)
            position = boundary + decay * (displacement * cosine + (velocity + damping * displacement) / frequency * sine)
            velocity = decay * (velocity * cosine - (damping * velocity + stiffness * displacement) / frequency * sine)

            if abs(position - boundary) < 0.0001 && abs(velocity) < 0.002 {
                reset(to: boundary)
                return false
            }
        } else {
            let friction: CGFloat = 8
            let decay = exp(-friction * dt)
            position += velocity * (1 - decay) / friction
            velocity *= decay
            if position < 0 || position > 1 {
                springBoundary = progress
            } else if abs(velocity) < 0.02 {
                velocity = 0
                return false
            }
        }
        return true
    }

    /// Bounded, increasingly resistant stretch in points, anchored to one end.
    func stretch(trackWidth: CGFloat) -> (amount: CGFloat, edge: CGFloat) {
        let edge: CGFloat
        if let boundary = springBoundary {
            edge = boundary == 0 ? -1 : 1
        } else if position < 0 {
            edge = -1
        } else if position > 1 {
            edge = 1
        } else {
            return (0, 0)
        }
        let distance = (position - progress) * edge * trackWidth
        let limit: CGFloat = 12
        let resistedDistance = abs(distance) * 0.55
        let amount = limit * resistedDistance / (limit + resistedDistance)
        return (distance < 0 ? -amount : amount, edge)
    }
}
