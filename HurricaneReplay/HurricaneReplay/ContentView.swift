import SwiftUI

struct ContentView: View {
    @EnvironmentObject var storm: StormData

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase

    @State private var isImmersiveOpen = false
    @State private var isBusy = false

    var body: some View {
        VStack(spacing: 16) {
            Text("HurricaneReplay")
                .font(.largeTitle.bold())

            Picker("Site", selection: $storm.selectedSiteID) {
                ForEach(storm.bundle.sites) { s in
                    Text(s.id.replacingOccurrences(of: "_", with: " ")).tag(s.id)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Use anomaly baseline", isOn: $storm.useAnomaly)

            HStack {
                Text("North yaw: \(Int(storm.worldNorthYawDeg))°")
                Slider(value: $storm.worldNorthYawDeg, in: -180...180, step: 1)
                    .frame(maxWidth: 220)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Time index: \(storm.timeIndex)")
                    .font(.headline)
                Slider(
                    value: Binding(
                        get: { Double(storm.timeIndex) },
                        set: { storm.timeIndex = Int($0.rounded()) }
                    ),
                    in: 0...Double(max(0, storm.bundle.time_utc.count - 1)),
                    step: 1
                )
                .animation(.none, value: storm.timeIndex)
            }

            let raw = storm.sampleAtIndex(storm.timeIndex)
            let anomaly = storm.zetaForSelectedSite(at: storm.timeIndex)
            HStack(spacing: 24) {
                Text(String(format: "Water(anom): %.2f m", anomaly))
                Text(String(format: "Rain: %.1f mm/h", raw.rain))
                Text(String(format: "Wind: %.1f m/s @ %.0f°", raw.windSpeed, raw.windDirDeg))
            }
            .font(.headline)
            .monospaced()
            .animation(.none, value: storm.timeIndex)

            Button(isImmersiveOpen ? "Exit Immersive" : "Enter Immersive") {
                guard !isBusy else { return }
                isBusy = true
                Task {
                    if isImmersiveOpen {
                        await dismissImmersiveSpace()
                        isImmersiveOpen = false
                        isBusy = false
                    } else {
                        let result = await openImmersiveSpace(id: "immersive")
                        if result == .opened { isImmersiveOpen = true }
                        isBusy = false
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        }
        .padding()
        .frame(minWidth: 680, minHeight: 400)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { isImmersiveOpen = false }
        }
    }
}
