import SiteThreadCore
import SwiftUI

/// Sign-in. The UI Account path never touches a password: the operator signs
/// in with their normal browser and pastes an API key back here.
struct ConnectView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                text: state.localSetup
                    ? "CONNECT TO A LOCAL UNIFI CONSOLE"
                    : "SIGN IN TO UNIFI SITE MANAGER"
            )

            Text(explanation)
                .font(.system(size: 12))
                .foregroundColor(Palette.dim)
                .fixedSize(horizontal: false, vertical: true)

            if state.localSetup { localForm } else { cloudForm }
        }
    }

    private var explanation: String {
        state.localSetup
            ? "Use this only for a console that is not available through your UI Account. The key stays in your macOS keychain."
            : "Sign in safely in your browser, create a UI Account API key, and UniFi SiteThread will combine every site you own or administer into one view. Your password never enters this app."
    }

    // MARK: UI Account

    private var cloudForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { state.openAccount() } label: {
                    Text("Sign in at unifi.ui.com").font(.system(size: 12, weight: .semibold))
                }
                Text("Then open Settings → API Keys")
                    .font(.caption2)
                    .foregroundColor(Palette.dim)
            }

            SecureField("UI Account API key", text: $state.cloudKey)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await state.connectCloud() } }

            HStack {
                Spacer()
                Button { state.pasteAPIKey(intoLocalField: false) } label: {
                    Text("Paste API key from clipboard").font(.caption2)
                }
                .buttonStyle(.link)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await state.connectCloud() }
                } label: {
                    Text(state.connecting ? "Connecting…" : "Connect all sites")
                        .font(.system(size: 12, weight: .semibold))
                }
                .disabled(state.cloudKey.isEmpty || state.connecting)
                .keyboardShortcut(.defaultAction)

                Text("Includes sites shared with your UI Account")
                    .font(.caption2)
                    .foregroundColor(Palette.dim)
            }

            HStack {
                Spacer()
                Button { state.localSetup = true } label: {
                    Text("Use a local console connection instead").font(.caption2)
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: Local console

    private var localForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Console address · 192.168.1.1 or unifi.local", text: $state.hostField)
                .textFieldStyle(.roundedBorder)
                .onChange(of: state.hostField) { _ in
                    state.probeFingerprint = ""
                    state.certificateAccepted = false
                }
                .onSubmit { Task { await state.inspectCertificate() } }

            HStack(spacing: 10) {
                Button {
                    Task { await state.inspectCertificate() }
                } label: {
                    Text("Inspect certificate").font(.system(size: 12))
                }
                .disabled(state.hostField.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("No credential is sent during this check")
                    .font(.caption2)
                    .foregroundColor(Palette.dim)
            }

            if !state.probeFingerprint.isEmpty {
                fingerprintCard
                SecureField("UniFi API key", text: $state.localKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await state.connectLocal() } }

                HStack {
                    Spacer()
                    Button { state.pasteAPIKey(intoLocalField: true) } label: {
                        Text("Paste API key from clipboard").font(.caption2)
                    }
                    .buttonStyle(.link)
                }

                Button {
                    Task { await state.connectLocal() }
                } label: {
                    Text(state.connecting ? "Connecting…" : "Connect securely")
                        .font(.system(size: 12, weight: .semibold))
                }
                .disabled(!state.certificateAccepted || state.localKey.isEmpty || state.connecting)
            }

            HStack {
                Spacer()
                Button { state.localSetup = false } label: {
                    Text("Use UI Account to show all sites").font(.caption2)
                }
                .buttonStyle(.link)
            }
        }
    }

    private var fingerprintCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("CONSOLE CERTIFICATE · SHA-256")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.dim)

                Text(state.probeFingerprint)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $state.certificateAccepted) {
                    Text("I verified this fingerprint in UniFi Console → Settings → System")
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
            }
        }
    }
}
