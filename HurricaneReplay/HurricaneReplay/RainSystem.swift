import Foundation
import RealityKit
import simd
import QuartzCore

final class RainSystem {
    private let container = Entity()

    private let dropMesh: MeshResource
    private let baseMaterial: SimpleMaterial

    private struct Drop { let entity: ModelEntity }
    private var drops: [Drop] = []

    private let area: SIMD2<Float>
    private let topY: Float
    private let floorY: Float

    private var targetCount: Int = 0
    private var horizVel: SIMD3<Float> = .zero
    private let fallSpeed: Float = -4.8

    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    private let onHit: ((Float, Float) -> Void)?

    init(parent: Entity, area: SIMD2<Float>, topY: Float, floorY: Float, onHit: ((Float, Float) -> Void)? = nil) {
        self.area = area
        self.topY = topY
        self.floorY = floorY
        self.onHit = onHit

        self.dropMesh = .generateBox(size: [0.004, 0.10, 0.004]) // y 为竖直
        self.baseMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.9), isMetallic: false)

        parent.addChild(container)
        container.position = .zero
    }

    func configure(rainMMPerHour: Double, windSpeed: Double, windDirFromDeg: Double, worldYawDeg: Double) {
        targetCount = Int(min(600.0, max(0.0, rainMMPerHour * 18.0)))

        let toDeg = (windDirFromDeg + 180.0 + worldYawDeg).truncatingRemainder(dividingBy: 360.0)
        let rad = Float(toDeg * .pi / 180.0)
        let vx = sin(rad) * Float(windSpeed) * 0.7
        let vz = cos(rad) * Float(windSpeed) * 0.7
        horizVel = SIMD3<Float>(vx, 0, vz)
    }

    func tick() {
        let now = CACurrentMediaTime()
        var dt = Float(now - lastTime)
        lastTime = now
        dt = max(0.0, min(dt, 0.05))

        if drops.count < targetCount {
            spawn(count: targetCount - drops.count)
        } else if drops.count > targetCount {
            let remove = drops.count - targetCount
            for _ in 0..<remove {
                if let d = drops.popLast() { d.entity.removeFromParent() }
            }
        }
        guard dt > 0, !drops.isEmpty else { return }

        let v = SIMD3<Float>(horizVel.x, fallSpeed, horizVel.z)
        let dir = simd_normalize(v)

        for d in drops {
            var p = d.entity.position
            p += v * dt
            if p.y < floorY {
                onHit?(p.x, p.z)
                p.y = topY
                p.x = (Float.random(in: -0.5...0.5)) * area.x
                p.z = (Float.random(in: -0.5...0.5)) * area.y
            }
            d.entity.position = p

            // 对齐方向并适度拉长
            let q = simd_quatf(from: [0, 1, 0], to: dir)
            d.entity.orientation = q
            let stretch = 1.0 + simd_length(horizVel) * 0.05 + Float.random(in: -0.1...0.1)
            d.entity.scale = SIMD3<Float>(x: 1, y: max(0.9, min(2.0, stretch)), z: 1)

            var m = baseMaterial
            m.color.tint = .white.withAlphaComponent(0.75 + CGFloat.random(in: -0.1...0.1))
            d.entity.model?.materials = [m]
        }
    }

    private func spawn(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            let e = ModelEntity(mesh: dropMesh, materials: [baseMaterial])
            e.position = SIMD3<Float>(
                (Float.random(in: -0.5...0.5)) * area.x,
                Float.random(in: floorY...topY),
                (Float.random(in: -0.5...0.5)) * area.y
            )
            container.addChild(e)
            drops.append(Drop(entity: e))
        }
    }
}
