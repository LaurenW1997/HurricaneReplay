import Foundation
import RealityKit
#if canImport(ARKit)
import ARKit
#endif

/// 基于平面检测的遮挡与碰撞，提供 floorY 供对齐用
@MainActor
final class SceneMeshOcclusion {
    private let root = Entity()

    // 平面数量给 HUD（可选）
    private(set) var planeCount: Int = 0
    // 兼容旧字段名
    var meshCount: Int { planeCount }

    // 检测到的地面高度（世界坐标 y）
    private(set) var floorY: Float?

    private var debugVisualize = false

    #if canImport(ARKit) && USE_ARKIT
    private var session: ARKitSession?
    private var world: WorldTrackingProvider?
    private var planes: PlaneDetectionProvider?
    #endif

    init(parent: Entity) { parent.addChild(root) }

    func start() {
        #if canImport(ARKit) && USE_ARKIT
        let session = ARKitSession()
        let world   = WorldTrackingProvider()
        let planes  = PlaneDetectionProvider()
        self.session = session
        self.world   = world
        self.planes  = planes

        Task.detached { [weak self] in
            do {
                try await session.run([world, planes])
                await self?.consumePlaneUpdates(from: planes)
            } catch {
                print("[PlaneOcc] run error:", error)
            }
        }
        #endif
    }

    func setDebugVisualize(_ on: Bool) {
        debugVisualize = on
        for child in root.children {
            guard let m = child as? ModelEntity else { continue }
            if on {
                var mat = UnlitMaterial()
                mat.color = .init(tint: .init(white: 0.6, alpha: 0.25))
                m.model?.materials = [mat]
            } else {
                m.model?.materials = [OcclusionMaterial()]
            }
        }
    }

    #if canImport(ARKit) && USE_ARKIT
    private func consumePlaneUpdates(from provider: PlaneDetectionProvider) async {
        for await up in provider.anchorUpdates {
            await MainActor.run {
                let plane: PlaneAnchor = up.anchor
                switch up.event {
                case .added, .updated:
                    self.upsert(plane: plane)
                case .removed:
                    self.remove(id: plane.id)
                }
                self.planeCount = self.root.children.count

                // 更新 floorY（优先 floor；否则取最低的水平面）
                let y = plane.originFromAnchorTransform.columns.3.y
                if plane.classification == .floor {
                    self.floorY = y
                } else {
                    if plane.classification != .wall && plane.classification != .ceiling {
                        if let old = self.floorY {
                            self.floorY = min(old, y)
                        } else {
                            self.floorY = y
                        }
                    }
                }
            }
        }
    }

    private func upsert(plane: PlaneAnchor) {
        remove(id: plane.id)

        let ext = plane.geometry.extent
        let sizeX = max(0.1, Float(ext.width))
        let sizeZ = max(0.1, Float(ext.height))

        let mesh: MeshResource = .generatePlane(width: sizeX, depth: sizeZ)

        let material: Material = debugVisualize ? {
            var m = UnlitMaterial()
            m.color = .init(tint: .init(white: 0.7, alpha: 0.25))
            return m
        }() : OcclusionMaterial()

        let e = ModelEntity(mesh: mesh, materials: [material])
        e.name = "plane-\(plane.id.uuidString)"
        e.transform.matrix = plane.originFromAnchorTransform

        // 碰撞供 raycast 命中
        e.generateCollisionShapes(recursive: false)

        root.addChild(e)
    }

    private func remove(id: UUID) {
        root.findEntity(named: "plane-\(id.uuidString)")?.removeFromParent()
    }
    #endif
}

// 无 ARKit 或未定义 USE_ARKIT 的占位实现，保持可编
#if !(canImport(ARKit)) || !(USE_ARKIT)
@MainActor
final class SceneMeshOcclusion {
    private let root = Entity()
    private(set) var planeCount: Int = 0
    var meshCount: Int { planeCount }
    private(set) var floorY: Float?

    init(parent: Entity) { parent.addChild(root) }
    func start() { }
    func setDebugVisualize(_ on: Bool) { }
}
#endif
