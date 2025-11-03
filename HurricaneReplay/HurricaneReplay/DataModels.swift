import Foundation
import SwiftUI

struct StormSite: Codable, Identifiable, Hashable {
    let id: String
    let lat: Double
    let lon: Double
    let zeta_m: [Double]
    let rain_mm_h: [Double]
    let wind_speed_mps: [Double]
    let wind_dir_deg: [Double]
    let grid_angle_deg: Double?
}

struct StormBundle: Codable {
    let time_utc: [Int]
    let sites: [StormSite]
}

@MainActor
final class StormData: ObservableObject {
    @Published var bundle: StormBundle
    @Published var selectedSiteID: String
    @Published var timeIndex: Int = 0

    @Published var useAnomaly: Bool = true
    @Published var baselineBySite: [String: Double] = [
        "new_orleans_french_quarter": 7.0
    ]

    @Published var worldNorthYawDeg: Double = 0

    var times: [TimeInterval] { bundle.time_utc.map { TimeInterval($0) } }

    var selectedSite: StormSite {
        bundle.sites.first(where: { $0.id == selectedSiteID }) ?? bundle.sites[0]
    }

    init(bundle: StormBundle) {
        self.bundle = bundle
        self.selectedSiteID = bundle.sites.first?.id ?? ""
    }

    static func loadFromBundle(filename: String = "ida_sites_all") -> StormData {
        let url = Bundle.main.url(forResource: filename, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let bundle = try! JSONDecoder().decode(StormBundle.self, from: data)
        return StormData(bundle: bundle)
    }

    struct Sample {
        let zeta: Double
        let rain: Double
        let windSpeed: Double
        let windDirDeg: Double
    }

    func sampleAtIndex(_ i: Int) -> Sample {
        let idx = max(0, min(i, times.count - 1))
        let s = selectedSite
        return Sample(
            zeta: s.zeta_m[idx],
            rain: s.rain_mm_h[idx],
            windSpeed: s.wind_speed_mps[idx],
            windDirDeg: s.wind_dir_deg[idx]
        )
    }

    func zetaForSelectedSite(at i: Int) -> Double {
        let idx = max(0, min(i, times.count - 1))
        let raw = selectedSite.zeta_m[idx]
        guard useAnomaly else { return raw }
        let base = baselineBySite[selectedSite.id] ?? 0.0
        return raw - base
    }
}
