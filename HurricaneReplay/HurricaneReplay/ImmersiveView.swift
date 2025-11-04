import SwiftUI
import RealityKit
import QuartzCore
import simd

struct ImmersiveView: View {
    @EnvironmentObject var storm: StormData

    @State private var rootAnchor: AnchorEntity?
    @State private var occluder: SceneMeshOcclusion?
    @State private var waterField: WaterField?
    @State private var splash: SplashSystem?
    @State private var rain: RainSystem?

    final class Runtime {
        var lastTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    }
    @State private var rt = Runtime()

    var body: some View {
        RealityView { content in
            // 根锚点
            let anchor = AnchorEntity(world: .zero)
            content.add(anchor)
            self.rootAnchor = anchor

            // 平面遮挡与碰撞（先启动，尽快拿到 floorY）
            let occ = SceneMeshOcclusion(parent: anchor)
            occ.start()
            self.occluder = occ

            // 水面（多 tile 平滑）
            let wf = WaterField(parent: anchor, fieldSize: 8, tileSize: 0.35)
            self.waterField = wf

            // 高斯溅斑
            let sp = SplashSystem(parent: anchor)
            self.splash = sp

            // 雨条
            let rainSys = RainSystem(parent: anchor)
            self.rain = rainSys

            rt.lastTime = CFAbsoluteTimeGetCurrent()

        } update: { _ in
            let now = CFAbsoluteTimeGetCurrent()
            let dt = Float(max(0, now - rt.lastTime))
            rt.lastTime = now

            guard let anchor = self.rootAnchor,
                  let wf = self.waterField,
                  let occ = self.occluder else { return }

            // 基准地面高度
            let yFloor: Float = occ.floorY ?? 0.0

            // 目标水深（米）
            let i = storm.timeIndex
            var z = storm.zetaForSelectedSite(at: i)
            if !z.isFinite { z = 0 }
            let depthMeters = max(0, min(5, z))

            // 把水面平滑到 worldY（地面上抬起 depth）
            wf.setTarget(height: Float(yFloor) + Float(depthMeters) + 0.01)
            wf.tick(dt: dt)

            // 推进溅斑寿命
            self.splash?.tick(dt: dt)

            // 配置并推进雨条（含命中地面的触发回调）
            if let rain = self.rain {
                let s = storm.sampleAtIndex(i)
                rain.configure(
                    rainMMPerHour: max(0.0, s.rain),
                    windSpeed: max(0.0, s.windSpeed),
                    windDirFromDeg: s.windDirDeg,
                    worldYawDeg: storm.worldNorthYawDeg
                )
                rain.tick(dt: dt, floorY: yFloor, scene: anchor.scene) { p in
                    self.splash?.spawn(at: p)
                }
            }
        }
    }
}
