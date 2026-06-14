import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var connectionStatus: String? = nil
    @State private var testing = false
    @State private var showSecret = false
    @State private var showGeminiKey = false

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
                    HStack {
                        TextField("Tailscale IP (e.g. 100.x.x.x)", text: $settings.macTailscaleIP)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !settings.macTailscaleIP.isEmpty {
                            Button { settings.macTailscaleIP = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    RevealableField("共用密鑰 (Shared Secret)", text: binding(\.sharedSecret), revealed: $showSecret)
                    Button(testing ? "測試中..." : "測試連線") { testConnection() }
                        .disabled(settings.macTailscaleIP.isEmpty || testing)
                    if let status = connectionStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("成功") ? .green : .red)
                    }
                }

                Section("備援 AI (Gemini Flash)") {
                    RevealableField("Gemini API Key", text: binding(\.geminiAPIKey), revealed: $showGeminiKey)
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
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("設定")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { hideKeyboard() }
                }
            }
        }
    }

    private func binding(_ kp: ReferenceWritableKeyPath<SettingsStore, String>) -> Binding<String> {
        Binding(get: { settings[keyPath: kp] }, set: { settings[keyPath: kp] = $0 })
    }

    private func testConnection() {
        guard let url = settings.macServerURL else { return }
        testing = true
        connectionStatus = nil
        Task {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(settings.sharedSecret, forHTTPHeaderField: "X-Secret")
            request.httpBody = try? JSONEncoder().encode(["url": "", "cleanText": "", "language": ""])
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    connectionStatus = http.statusCode == 401
                        ? "✗ 伺服器可達，但密鑰錯誤"
                        : "✓ 連線成功"
                }
            } catch {
                connectionStatus = "✗ 無法連線: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}

private struct RevealableField: View {
    let label: String
    @Binding var text: String
    @Binding var revealed: Bool

    init(_ label: String, text: Binding<String>, revealed: Binding<Bool>) {
        self.label = label
        self._text = text
        self._revealed = revealed
    }

    var body: some View {
        HStack {
            if revealed {
                TextField(label, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(label, text: $text)
            }
            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
