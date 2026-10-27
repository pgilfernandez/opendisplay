import Network
import SwiftUI

// MARK: - Receiver panel (issues #82/#17)
/// The receiver-mode sections of the panel: live status, the advertised
/// name, and how-to copy. Lives inside the shared grouped Form.
struct ReceiverSections: View {
    @ObservedObject var controller: ReceiverController
    @StateObject private var senders = AvailableSenders()
    @AppStorage("showAnalytics") private var showAnalytics = false

    var body: some View {
        // The receiver exists only while receiver mode is on; observed in a
        // subview because nested ObservableObjects don't republish.
        if let receiver = controller.receiver {
            ReceiverStatusSection(receiver: receiver, controller: controller)
        }
        Section("Available senders") {
            if senders.results.isEmpty {
                Text("Searching for senders on the local network…")
                    .foregroundStyle(.secondary)
            }
            ForEach(senders.results, id: \.endpoint) { result in
                HStack {
                    Label(AvailableSenders.name(result), systemImage: "desktopcomputer")
                    Spacer()
                    Button("Connect") { senders.connect(result) }
                        .disabled(senders.connecting)
                }
            }
            if let status = senders.status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { senders.start() }
        .onDisappear { senders.stop() }
        .onChange(of: controller.connected) { connected in
            if connected { senders.status = nil }
        }
        Section {
            ReceiverNameField { controller.setAdvertisedName($0) }
        } header: {
            Text("Name")
        } footer: {
            Text("How this Mac appears in the other Mac's Devices list.")
        }
        Section {
            Toggle("Performance overlay", isOn: $showAnalytics)
        } footer: {
            Text(
                "FPS, bitrate, frame timing, and latency graphs at the bottom of the video window while streaming — the same HUD the iPhone app has."
            )
        }
        Section("How to connect") {
            Label(
                "Install and open OpenDisplay on the Mac whose screen you want to extend.",
                systemImage: "macbook.and.macbook")
            Label(
                "With both Macs on the same network, choose a sender above and click Connect, or select this Mac in the sender’s Devices list.",
                systemImage: "wifi")
            Label(
                "The stream opens in a window here — use the green traffic light for full screen.",
                systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .font(.subheadline)
    }
}

/// Live state of the running receiver: connection, stream format, and any
/// compatibility signal from the connected Mac.
private struct ReceiverStatusSection: View {
    @ObservedObject var receiver: StreamReceiver
    let controller: ReceiverController

    var body: some View {
        Section("This Mac as a display") {
            HStack(alignment: .firstTextBaseline) {
                Circle()
                    .fill(receiver.connected ? Color.green : Color.orange)
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(receiver.connected ? "Connected" : "Waiting for a computer…")
                    // The port matters on a Mac (firewall prompts), so the
                    // idle caption names it instead of repeating the status.
                    Text(receiver.connected || receiver.status != "Ready to connect"
                         ? receiver.status : "Listening on port 9000")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if controller.streaming {
                    Button("Show Window") { controller.showWindow() }
                        .controlSize(.small)
                        .help("Bring the video window back if you closed it — the stream keeps running either way.")
                }
            }
            if receiver.videoSize != .zero {
                // Not LabeledContent: that is macOS 13, the app runs on 12.
                HStack {
                    Text("Stream")
                    Spacer()
                    Text("\(Int(receiver.videoSize.width))×\(Int(receiver.videoSize.height)) @ \(receiver.fps) fps")
                        .foregroundColor(.secondary)
                }
            }
            if let message = peerMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// Compatibility copy from the sender (issue #132) — surfaced inline;
    /// the Mac app has Sparkle, so there is no blocking gate like on iOS.
    private var peerMessage: String? {
        switch receiver.peerSignal {
        case let .updateReceiver(message, _): return message
        case let .updateMac(message): return message
        case nil: return nil
        }
    }
}

/// The advertised-name editor — kept out of any high-frequency observed
/// object so streaming updates can't rebuild it mid-edit (same reasoning as
/// the iOS DeviceNameField).
private struct ReceiverNameField: View {
    @AppStorage("receiverName") private var name = Host.current().localizedName ?? "Mac"
    let onChange: (String) -> Void

    var body: some View {
        TextField("Name", text: $name)
            // The single-value onChange: the two-value form is macOS 14.
            .onChange(of: name, perform: onChange)
    }
}

/// Discovery and the small request channel are separate from the video stream.
@MainActor
private final class AvailableSenders: ObservableObject {
    @Published var results: [NWBrowser.Result] = []
    @Published var status: String?
    @Published var connecting = false
    private var browsingEnabled = false
    private var browser: NWBrowser?
    private var request: NWConnection?

    static func name(_ result: NWBrowser.Result) -> String {
        if case .service(let name, _, _, _) = result.endpoint { return name }
        return "Mac"
    }

    func start() {
        browsingEnabled = true
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: "_od-sender._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.results = results.sorted {
                    Self.name($0).localizedStandardCompare(Self.name($1)) == .orderedAscending
                }
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                if case .failed(let error) = state {
                    self?.status = "Sender discovery failed: \(error.localizedDescription)"
                    self?.browser?.cancel()
                    self?.browser = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        if self?.browsingEnabled == true { self?.start() }
                    }
                }
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    func stop() {
        browsingEnabled = false
        browser?.cancel()
        browser = nil
        request?.cancel()
        request = nil
        connecting = false
        results = []
    }

    func connect(_ result: NWBrowser.Result) {
        guard !connecting else { return }
        connecting = true
        status = "Requesting connection to \(Self.name(result))…"
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        request = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self, self.request === connection else { return }
                switch state {
                case .ready:
                    connection.send(
                        content: Data(StreamReceiver.installID.utf8),
                        completion: .contentProcessed { [weak self] error in
                            DispatchQueue.main.async {
                                if error != nil {
                                    self?.finish(connection, "Could not send connection request.")
                                }
                            }
                        })
                    connection.receive(minimumIncompleteLength: 2, maximumLength: 2) {
                        [weak self] data, _, _, _ in
                        DispatchQueue.main.async {
                            let accepted = data == Data("OK".utf8)
                            self?.finish(
                                connection,
                                accepted
                                    ? "Request accepted — waiting for video…"
                                    : "Sender could not find this receiver. Wait a moment and try again.")
                        }
                    }
                case .failed:
                    self.finish(connection, "Could not reach sender. Check its firewall and try again.")
                default: break
                }
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
            self?.finish(connection, "Connection request timed out. Try again.")
        }
    }

    private func finish(_ connection: NWConnection, _ message: String) {
        guard request === connection else { return }
        request = nil
        connection.cancel()
        connecting = false
        status = message
    }
}
