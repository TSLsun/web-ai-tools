import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var connectionStatus: String? = nil
    @State private var testing = false

    var body: some View {
        NavigationView {
            Form {
                Section("語言 / Language") {
                    Picker("語言", selection: $settings.language) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mac 伺服器 (Tailscale)") {
                    TextField("Tailscale IP (e.g. 100.x.x.x)", text: $settings.macTailscaleIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    SecureField("共用密鑰 (Shared Secret)", text: secureBinding(\.sharedSecret))
                    Button(testing ? "測試中..." : "測試連線") { testConnection() }
                        .disabled(settings.macTailscaleIP.isEmpty || testing)
                    if let status = connectionStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("成功") ? .green : .red)
                    }
                }

                Section("備援 AI (Gemini Flash)") {
                    SecureField("Gemini API Key", text: secureBinding(\.geminiAPIKey))
                    Link("取得免費 API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.footnote)
                }

                Section("說明") {
                    Text("1. 安裝 Tailscale 在 Mac 和 iPhone")
                    Text("2. 執行 Mac 伺服器：cd mac-server && python3 server.py")
                    Text("3. 填入 Mac 的 Tailscale IP（執行 tailscale ip -4）")
                    Text("4. 在 LINE 或瀏覽器分享連結時選擇此 App")
                }
            }
            .navigationTitle("NewsSummarizer")
        }
    }

    private func secureBinding(_ kp: ReferenceWritableKeyPath<SettingsStore, String>) -> Binding<String> {
        Binding(get: { settings[keyPath: kp] }, set: { settings[keyPath: kp] = $0 })
    }

    private func testConnection() {
        guard let url = settings.macServerURL else { return }
        testing = true
        connectionStatus = nil
        Task {
            let client = MacClient(serverURL: url, sharedSecret: settings.sharedSecret)
            do {
                _ = try await client.summarize(
                    url: URL(string: "https://example.com")!,
                    cleanText: "ping",
                    language: settings.language
                )
                connectionStatus = "✓ 連線成功"
            } catch {
                connectionStatus = "✗ 連線失敗: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
