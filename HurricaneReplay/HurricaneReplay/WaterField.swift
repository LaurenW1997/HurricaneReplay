import RealityKit
import simd

@MainActor
final class WaterField {
    let root = Entity()
    private var tiles: [ModelEntity] = []

    private let cols: Int
    private let rows: Int
    private let tileSize: Float

    private var currentY: Float = 0
    private var targetY:  Float = 0
    private var vel: Float = 0
    private let smoothTime: Float = 0.35

    init(parent: Entity, fieldSize: Float = 8, tileSize: Float = 0.35) {
        self.tileSize = tileSize
        self.cols = Int(ceil(fieldSize / tileSize))
        self.rows = Int(ceil(fieldSize / tileSize))

        parent.addChild(root)

        var mat = SimpleMaterial()
        mat.color = .init(tint: .init(red: 0.20, green: 0.35, blue: 0.90, alpha: 0.42))

        let ox = -Float(cols) * tileSize * 0.5
        let oz = -Float(rows) * tileSize * 0.5

        for r in 0..<rows {
            for c in 0..<cols {
                let mesh = MeshResource.generatePlane(width: tileSize, depth: tileSize)
                let e = ModelEntity(mesh: mesh, materials: [mat])

                // 如你的 SDK 平面默认竖直，解注下面旋转
                // e.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0])

                e.position = [
                    ox + Float(c) * tileSize + tileSize * 0.5,
                    0.01,
                    oz + Float(r) * tileSize + tileSize * 0.5
                ]
                e.generateCollisionShapes(recursive: false)
                root.addChild(e)
                tiles.append(e)
            }
        }
    }

    func setTarget(height worldY: Float) { targetY = worldY }

    func tick(dt: Float) {
        let omega = 2.0 / max(0.001, smoothTime)
        let x = currentY - targetY
        let acc = -omega * omega * x - 2.0 * omega * vel
        vel += acc * dt
        currentY += vel * dt

        let y = currentY
        for t in tiles { t.position.y = y }
    }
}
