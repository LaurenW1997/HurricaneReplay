import SwiftUI
import RealityKit

struct LastIndexComponent: Component { var value: Int = -1 }

struct ImmersiveView: View {
    @EnvironmentObject var storm: StormData

    @State private var rootAnchor: AnchorEntity?
    @State private var water: ModelEntity?
    @State private var rain: RainSystem?
    @State private var fog: FogSystem?
    @State private var splash: SplashSystem?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: .zero)
            content.add(anchor)
            self.rootAnchor = anchor

            // 水面: SimpleMaterial 半透明（仅用 alpha，不设置 blending）
            let water = WaterSurface.make(width: 4, depth: 4)
            water.position = [0, 0.01, 0]
            water.components.set(LastIndexComponent(value: -1))
            anchor.addChild(water)
            self.water = water

            // 水花
            let splash = SplashSystem(parent: anchor, floorY: 0.0)
            self.splash = splash

            // 雨
            let rain = RainSystem(parent: anchor,
                                  area: SIMD2<Float>(6, 6),
                                  topY: 3.0,
                                  floorY: 0.0) { hitX, hitZ in
                splash.spawn(at: SIMD3<Float>(hitX, 0.02, hitZ))
            }
            self.rain = rain

            // 雾
            let fog = FogSystem(parent: anchor)
            self.fog = fog
        } update: { _ in
            guard let water = self.water,
                  let rain = self.rain,
                  let fog = self.fog else { return }

            rain.tick()
            fog.tick()
            splash?.tick()

            // 仅索引变化时刷新数据驱动
            var c = water.components[LastIndexComponent.self] ?? LastIndexComponent(value: -1)
            let i = storm.timeIndex
            if i != c.value {
                let z = storm.zetaForSelectedSite(at: i)
                let zSafe = z.isFinite ? z : 0.0
                let clamped = max(-5.0, min(5.0, zSafe))
                water.position.y = Float(max(0.01, clamped))
                WaterSurface.updateLook(for: water, wetness: Float(min(1, abs(clamped) / 1.5)))

                let s = storm.sampleAtIndex(i)
                rain.configure(rainMMPerHour: max(0.0, s.rain),
                               windSpeed: max(0.0, s.windSpeed),
                               windDirFromDeg: s.windDirDeg,
                               worldYawDeg: storm.worldNorthYawDeg)
                fog.setIntensity(rainMMPerHour: s.rain)

                c.value = i
                water.components.set(c)
            }
        }
    }
}

// 简化版水面材质，兼容旧 SDK：只用 SimpleMaterial 的颜色 alpha
enum WaterSurface {
    static func make(width: Float, depth: Float) -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: width, depth: depth)
        var mat = SimpleMaterial()
        mat.color = .init(tint: .init(red: 0.2, green: 0.35, blue: 0.9, alpha: 0.42))
        let e = ModelEntity(mesh: mesh, materials: [mat])
        return e
    }

    static func updateLook(for entity: ModelEntity, wetness: Float) {
        guard var m = entity.model?.materials.first as? SimpleMaterial else { return }
        // 用 alpha 小幅体现湿润感
        let a = CGFloat(min(0.7, 0.42 + 0.10 * wetness))
        m.color = .init(tint: .init(red: 0.2, green: 0.35, blue: 0.9, alpha: a))
        entity.model?.materials = [m]
    }
}
