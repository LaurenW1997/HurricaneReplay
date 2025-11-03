import Foundation
import RealityKit
import simd
import QuartzCore

/// 轻量雨滴系统: 细长盒子阵列模拟雨
final class RainSystem {
    private let container = Entity()

    private let dropMesh: MeshResource
    private let dropMaterial: SimpleMaterial

    private struct Drop { let entity: ModelEntity }
    private var drops: [Drop] = []

    private let area: SIMD2<Float>
    private let topY: Float
    private let floorY: Float

    private var targetCount: Int = 0
    private var horizVel: SIMD3<Float> = .zero
    private let fallSpeed: Float = -4.5

    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    init(parent: Entity, area: SIMD2<Float>, topY: Float, floorY: Float) {
        self.area = area
        self.topY = topY
        self.floorY = floorY

        // y 轴是竖直方向, 所以把长度放在 y 上, 不要再旋转
        self.dropMesh = .generateBox(size: [0.004, 0.12, 0.004])
        self.dropMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.85), isMetallic: false)

        parent.addChild(container)
        container.position = .zero
    }

    func configure(rainMMPerHour: Double, windSpeed: Double, windDirFromDeg: Double, worldYawDeg: Double) {
        targetCount = Int(min(400.0, max(0.0, rainMMPerHour * 15.0)))

        // 来向 -> 去向, 再加世界北向校准
        let toDeg = (windDirFromDeg + 180.0 + worldYawDeg).truncatingRemainder(dividingBy: 360.0)
        let rad = Float(toDeg * .pi / 180.0)
        let vx = sin(rad) * Float(windSpeed) * 0.6
        let vz = cos(rad) * Float(windSpeed) * 0.6
        horizVel = SIMD3<Float>(vx, 0, vz)
    }

    func tick() {
        let now = CACurrentMediaTime()
        var dt = Float(now - lastTime)
        lastTime = now
        dt = max(0.0, min(dt, 0.05))

        // 数量管理
        if drops.count < targetCount {
            spawn(count: targetCount - drops.count)
        } else if drops.count > targetCount {
            let remove = drops.count - targetCount
            for _ in 0..<remove {
                if let d = drops.popLast() { d.entity.removeFromParent() }
            }
        }
        guard dt > 0, !drops.isEmpty else { return }

        // 位置推进
        for d in drops {
            var p = d.entity.position
            p.x += horizVel.x * dt
            p.y += fallSpeed * dt
            p.z += horizVel.z * dt

            if p.y < floorY {
                p.y = topY
                p.x = (Float.random(in: -0.5...0.5)) * area.x
                p.z = (Float.random(in: -0.5...0.5)) * area.y
            }
            d.entity.position = p

            // 可选: 让雨滴略微朝速度方向倾斜, 看起来更有速度感
            let dir = simd_normalize(SIMD3<Float>(horizVel.x, fallSpeed, horizVel.z))
            let q = simd_quatf(from: [0, 1, 0], to: dir)  // 本地 y 对齐到合速度
            d.entity.orientation = q
        }
    }

    private func spawn(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            let e = ModelEntity(mesh: dropMesh, materials: [dropMaterial])
            e.position = SIMD3<Float>(
                (Float.random(in: -0.5...0.5)) * area.x,
                Float.random(in: floorY...topY),
                (Float.random(in: -0.5...0.5)) * area.y
            )
            // 默认竖直即可, orientation 初始为单位四元数
            container.addChild(e)
            drops.append(Drop(entity: e))
        }
    }
}
