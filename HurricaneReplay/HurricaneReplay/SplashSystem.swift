import Foundation
import RealityKit
import simd
import QuartzCore

final class SplashSystem {
    private let container = Entity()
    private var pool: [ModelEntity] = []
    private var lifetimes: [CFTimeInterval] = []
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    private let maxCount = 64
    private let life: CFTimeInterval = 0.6

    init(parent: Entity, floorY: Float) {
        parent.addChild(container)
        container.position = [0, floorY, 0]

        let mesh = MeshResource.generatePlane(width: 0.05, depth: 0.05)
        let material = SimpleMaterial(color: .white.withAlphaComponent(0.8), isMetallic: false)

        for _ in 0..<maxCount {
            let e = ModelEntity(mesh: mesh, materials: [material])
            e.isEnabled = false
            container.addChild(e)
            pool.append(e)
            lifetimes.append(0)
        }
    }

    func spawn(at pos: SIMD3<Float>) {
        if let idx = lifetimes.firstIndex(of: 0) {
            let e = pool[idx]
            e.position = pos
            e.scale = [0.2, 1, 0.2]
            e.isEnabled = true
            lifetimes[idx] = life
        }
    }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = max(0.0, min(Float(now - lastTime), 0.05))
        lastTime = now

        for i in pool.indices {
            if lifetimes[i] > 0 {
                lifetimes[i] -= Double(dt)
                let t = max(0.0, Float(lifetimes[i] / life))
                let e = pool[i]
                e.scale = [1.0 + (1 - t) * 1.2, 1, 1.0 + (1 - t) * 1.2]
                if var m = e.model?.materials.first as? SimpleMaterial {
                    m.color.tint = .white.withAlphaComponent(CGFloat(t) * 0.6)
                    e.model?.materials = [m]
                }
                if lifetimes[i] <= 0 {
                    e.isEnabled = false
                    lifetimes[i] = 0
                }
            }
        }
    }
}
