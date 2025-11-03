import Foundation
import RealityKit
import QuartzCore

final class FogSystem {
    private let entity = ModelEntity()
    private var targetAlpha: Float = 0
    private var currentAlpha: Float = 0
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    init(parent: Entity) {
        let mesh = MeshResource.generateBox(size: 20)
        var mat = UnlitMaterial()
        mat.color = .init(tint: .init(red: 0.75, green: 0.85, blue: 0.95, alpha: 0.0))
        entity.model = .init(mesh: mesh, materials: [mat])
        entity.position = [0, 2.5, 0]
        parent.addChild(entity)
    }

    func setIntensity(rainMMPerHour: Double) {
        targetAlpha = min(0.25, Float(rainMMPerHour) * 0.006)
    }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = Float(now - lastTime)
        lastTime = now

        currentAlpha += (targetAlpha - currentAlpha) * min(1, dt * 3)

        guard var m = entity.model?.materials.first as? UnlitMaterial else { return }
        m.color = .init(tint: .init(red: 0.75, green: 0.85, blue: 0.95, alpha: CGFloat(currentAlpha)))
        entity.model?.materials = [m]
    }
}
