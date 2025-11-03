import SwiftUI
import RealityKit

struct LastIndexComponent: Component { var value: Int = -1 }

struct ImmersiveView: View {
    @EnvironmentObject var storm: StormData

    @State private var rootAnchor: AnchorEntity?
    @State private var water: ModelEntity?
    @State private var rain: RainSystem?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: .zero)
            content.add(anchor)
            self.rootAnchor = anchor

            let mesh = MeshResource.generatePlane(width: 4, depth: 4)
            let material = SimpleMaterial(color: .init(red: 0, green: 0, blue: 1, alpha: 0.35),
                                          isMetallic: false)
            let water = ModelEntity(mesh: mesh, materials: [material])
            water.position = [0, 0.01, 0]
            water.components.set(LastIndexComponent(value: -1))
            anchor.addChild(water)
            self.water = water

            let rainSystem = RainSystem(parent: anchor,
                                        area: SIMD2<Float>(6, 6),
                                        topY: 3.0,
                                        floorY: 0.0)
            self.rain = rainSystem
        } update: { _ in
            guard let water = self.water, let rain = self.rain else { return }

            // 推进雨滴
            rain.tick()

            // 索引变化才更新
            var c = water.components[LastIndexComponent.self] ?? LastIndexComponent(value: -1)
            let i = storm.timeIndex
            if i != c.value {
                let z = storm.zetaForSelectedSite(at: i)
                let zSafe = z.isFinite ? z : 0.0
                let clamped = max(-5.0, min(5.0, zSafe))
                water.position.y = Float(max(0.01, clamped))

                let s = storm.sampleAtIndex(i)
                rain.configure(rainMMPerHour: max(0.0, s.rain),
                               windSpeed: max(0.0, s.windSpeed),
                               windDirFromDeg: s.windDirDeg,
                               worldYawDeg: storm.worldNorthYawDeg)

                c.value = i
                water.components.set(c)
            }
        }
    }
}
