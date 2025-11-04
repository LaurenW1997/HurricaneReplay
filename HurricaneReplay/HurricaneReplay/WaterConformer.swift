import Foundation
import RealityKit
import simd

@MainActor
final class WaterConformer {
    private let parent: Entity
    private let gridN: Int
    private let halfW: Float
    private let halfD: Float
    private var tiles: [[ModelEntity]] = []
    private var frame = 0

    init(parent: Entity, width: Float, depth: Float, gridN: Int = 8, baseMaterial: SimpleMaterial) {
        self.parent = parent
        self.gridN = max(2, gridN)
        self.halfW = width * 0.5
        self.halfD = depth * 0.5

        let w = width / Float(gridN)
        let d = depth / Float(gridN)
        let mesh = MeshResource.generatePlane(width: w, depth: d)

        for gx in 0..<gridN {
            var row: [ModelEntity] = []
            for gz in 0..<gridN {
                let e = ModelEntity(mesh: mesh, materials: [baseMaterial])
                let x = -halfW + (Float(gx) + 0.5) * w
                let z = -halfD + (Float(gz) + 0.5) * d
                e.position = [x, 0, z]
                parent.addChild(e)
                row.append(e)
            }
            tiles.append(row)
        }
    }

    func setBaseHeight(_ y: Float) {
        for r in tiles { for t in r { var p = t.position; p.y = y; t.position = p } }
    }

    /// 每 4 帧做一次向下射线，命中网格就把 tile 高度缓动到命中位置
    func tick(anchor: AnchorEntity) {
        frame += 1
        guard frame % 4 == 0, let scene = anchor.scene else { return }

        for r in tiles {
            for t in r {
                let world = t.transformMatrix(relativeTo: nil)
                let origin = SIMD3<Float>(world.columns.3.x, world.columns.3.y + 1.5, world.columns.3.z)
                let to = origin + SIMD3<Float>(0, -3.0, 0)   // 1.5m 上方向下 3m

                let hits = scene.raycast(from: origin, to: to)
                if let hit = hits.first {
                    var p = t.position(relativeTo: parent)
                    let targetY = hit.position.y + 0.01
                    p.y = p.y + (targetY - p.y) * 0.6
                    t.setPosition(p, relativeTo: parent)
                }
            }
        }
    }
}
