import RealityKit
import simd

@MainActor
final class RainSystem {
    struct Config {
        var maxDrops: Int = 900
        var areaRadius: Float = 2.2     // 雨覆盖半径（世界原点为中心）
        var topY: Float = 2.5           // 生成为起高度（相对 floorY）
        var minStreak: Float = 0.28     // 视觉长度
        var maxStreak: Float = 0.55
        var width: Float = 0.012
        var baseAlpha: Float = 0.38
        var gravity: Float = 9.0        // m/s^2，稍弱于真实值以拉长停留
    }

    private let parent: Entity
    private let cfg: Config
    private var pool: [ModelEntity] = []
    private var active: [Int: Drop] = [:]

    private var windYawRad: Float = 0
    private var windSpeed: Float = 0
    private var rainRate: Float = 0 // mm/h

    private struct Drop {
        var pos: SIMD3<Float>
        var vel: SIMD3<Float>
        var length: Float
    }

    private var mat: UnlitMaterial

    init(parent: Entity, config: Config = Config()) {
        self.parent = parent
        self.cfg = config

        var m = UnlitMaterial()
        m.color = .init(tint: .init(white: 1, alpha: Double(config.baseAlpha)))
        self.mat = m

        // 用细长 box 做雨条（稳定、无需 billboard）
        let mesh = MeshResource.generateBox(size: [config.width, config.width, 1.0])

        for _ in 0..<config.maxDrops {
            let e = ModelEntity(mesh: mesh, materials: [m])
            e.isEnabled = false
            parent.addChild(e)
            pool.append(e)
        }
    }

    /// 每帧设置外部驱动的风雨
    func configure(rainMMPerHour: Double, windSpeed: Double, windDirFromDeg: Double, worldYawDeg: Double) {
        // 风向是“从...来”，转为朝向向量
        let dirFrom = Float(windDirFromDeg)
        let worldYaw = Float(worldYawDeg)
        // 世界坐标中，Z 轴为前，X 为右，取北向 yaw 修正
        let dirToDeg = fmodf(dirFrom + 180.0 + worldYaw, 360.0)
        windYawRad = dirToDeg * .pi / 180.0
        self.windSpeed = Float(max(0.0, windSpeed))
        self.rainRate = Float(max(0.0, rainMMPerHour))
    }

    /// 每帧推进：传入 floorY 和 scene 用于射线检测命中地面
    func tick(dt: Float, floorY: Float, scene: Scene?, onHit: (SIMD3<Float>) -> Void) {
        spawnIfNeeded(dt: dt, floorY: floorY)

        // 推进行为
        var toDisable: [Int] = []
        for (idx, d) in active {
            var drop = d
            // 简单重力和风
            drop.vel.y -= cfg.gravity * dt
            drop.pos += drop.vel * dt

            // 与地面的线段相交检测（上一位置到新位置）
            let prev = d.pos
            let curr = drop.pos
            if let hit = scene?.raycast(from: prev, to: curr).first {
                // 命中地面或平面
                onHit(SIMD3<Float>(hit.position.x, hit.position.y + 0.01, hit.position.z))
                toDisable.append(idx)
            } else if curr.y <= floorY - 0.02 {
                // 穿过地面兜底
                onHit(SIMD3<Float>(curr.x, floorY + 0.01, curr.z))
                toDisable.append(idx)
            } else {
                // 更新可视化：雨条长度沿速度方向摆放
                let dir = normalize(drop.vel)
                let mid = curr - 0.5 * dir * drop.length
                let e = pool[idx]
                e.isEnabled = true
                e.position = mid
                // 让盒子的 z 轴对齐 dir
                e.orientation = simd_quatf(from: [0,0,1], to: dir)
                e.scale = [1, 1, drop.length]
                active[idx] = drop
            }
        }

        // 回收
        for idx in toDisable {
            let e = pool[idx]
            e.isEnabled = false
            active.removeValue(forKey: idx)
        }
    }

    private func spawnIfNeeded(dt: Float, floorY: Float) {
        // 期望生成率：基础密度 + 按雨量线性增加
        let basePerSec: Float = 60
        let scale: Float = 2.0
        let desiredPerSec = basePerSec + rainRate * scale
        let lambda = max(0, desiredPerSec) * dt

        var count = Int(lambda.rounded())
        if count == 0 && Float.random(in: 0...1) < lambda { count = 1 }

        guard count > 0 else { return }
        let R = cfg.areaRadius

        // 风向向量（朝向风去的方向）
        let vx = sinf(windYawRad) * windSpeed
        let vz = cosf(windYawRad) * windSpeed

        for _ in 0..<count {
            guard let idx = pool.firstIndex(where: { !$0.isEnabled }) ?? pool.indices.randomElement() else { continue }

            // 在世界原点附近的矩形区域上方生成（以 floorY 为基准）
            let x = Float.random(in: -R...R)
            let z = Float.random(in: -R...R)
            let y = floorY + cfg.topY + Float.random(in: 0...0.6)

            var vel = SIMD3<Float>(vx, -4.5, vz) // 下落初速向下，叠加风
            // 轻微扰动
            vel.x += Float.random(in: -0.6...0.6)
            vel.z += Float.random(in: -0.6...0.6)

            let L = Float.random(in: cfg.minStreak...cfg.maxStreak)
            active[idx] = Drop(pos: [x,y,z], vel: vel, length: L)

            // 先把实体启用，tick 会更新姿态
            pool[idx].isEnabled = true
        }
    }
}
