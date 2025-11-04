import RealityKit
import simd

@MainActor
final class SplashSystem {
    struct Config {
        var maxCount: Int  = 180
        var minRadius: Float = 0.05
        var maxRadius: Float = 0.12
        var lifetime: Float  = 0.9
        var fadeIn: Float    = 0.06
        var fadeOut: Float   = 0.35
        var baseAlpha: Float = 0.85
    }

    private let parent: Entity
    private let cfg: Config
    private var pool: [ModelEntity] = []
    private var alive: [Int: Float] = [:]
    private var mat: UnlitMaterial

    init(parent: Entity, config: Config = Config()) {
        self.parent = parent
        self.cfg = config
        self.mat = SplashSystem.makeMaterial()

        let mesh = MeshResource.generatePlane(width: 0.1, depth: 0.1)
        for _ in 0..<config.maxCount {
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.isEnabled = false
            // e.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0]) // 如需水平旋转
            e.components.set(OpacityComponent(opacity: 0))
            parent.addChild(e)
            pool.append(e)
        }
    }

    func spawn(at p: SIMD3<Float>) {
        guard let idx = pool.firstIndex(where: { !$0.isEnabled }) ?? pool.indices.randomElement() else { return }
        let e = pool[idx]
        e.position = p
        e.isEnabled = true
        alive[idx] = 0

        let r = Float.random(in: cfg.minRadius...cfg.maxRadius)
        e.scale = SIMD3<Float>(repeating: r)
    }

    func tick(dt: Float) {
        guard !alive.isEmpty else { return }
        var toDisable: [Int] = []

        for (idx, age) in alive {
            var t = age + dt
            if t >= cfg.lifetime {
                toDisable.append(idx)
                continue
            }

            let a: Float = {
                if t < cfg.fadeIn {
                    return cfg.baseAlpha * (t / max(0.0001, cfg.fadeIn))
                } else if t > (cfg.lifetime - cfg.fadeOut) {
                    let k = (cfg.lifetime - t) / max(0.0001, cfg.fadeOut)
                    return cfg.baseAlpha * max(0, k)
                } else {
                    return cfg.baseAlpha
                }
            }()

            let spread: Float = 1.0 + 0.25 * min(1, t / cfg.lifetime)
            let e = pool[idx]
            let baseR = max(cfg.minRadius, min(cfg.maxRadius, e.scale.x))
            e.scale = SIMD3<Float>(repeating: baseR * spread)

            e.components.set(OpacityComponent(opacity: a))
            alive[idx] = t
        }

        for idx in toDisable {
            let e = pool[idx]
            e.isEnabled = false
            e.components.set(OpacityComponent(opacity: 0))
            alive.removeValue(forKey: idx)
        }
    }

    private static func makeMaterial() -> UnlitMaterial {
        var m = UnlitMaterial()
        if let tex = try? TextureResource.load(named: "splash_gauss") {
            m.color = .init(tint: .init(white: 1, alpha: 1), texture: .init(tex))
        } else {
            m.color = .init(tint: .init(white: 1, alpha: 0.7))
        }
        return m
    }
}
