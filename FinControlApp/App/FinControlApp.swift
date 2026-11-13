import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct FinControlApp: App {
    let modelContainer: ModelContainer

    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked: Bool = false
    @State private var authError: String?

    init() {
        let schema = Schema([
            Account.self,
            Category.self,
            CreditCard.self,
            Borrower.self,
            Invoice.self,
            Transaction.self,
            ThirdPartySettlement.self,
            Investment.self
        ])

        // Flip to `.automatic` once the iCloud/CloudKit capability & team container are configured in Xcode.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
        } catch {
            fatalError("Falha ao inicializar ModelContainer do SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .blur(radius: isUnlocked ? 0 : 18)
                    .disabled(!isUnlocked)

                if !isUnlocked {
                    LockScreenView(authError: authError) {
                        Task { await authenticateUser() }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isUnlocked)
            .task {
                SeedDataService.seedIfNeeded(context: modelContainer.mainContext)
                await NotificationService.shared.requestAuthorizationIfNeeded()
                await authenticateUser()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    isUnlocked = false
                } else if newPhase == .active && !isUnlocked {
                    Task { await authenticateUser() }
                }
            }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func authenticateUser() async {
        let context = LAContext()
        var error: NSError?
        let reason = "Desbloqueie o FinControl Pro para visualizar seus dados financeiros."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                if success {
                    isUnlocked = true
                    authError = nil
                }
            } catch {
                authError = error.localizedDescription
            }
        } else {
            // Simulator or device without passcode/biometrics enrolled
            isUnlocked = true
        }
    }
}

private struct LockScreenView: View {
    let authError: String?
    let onUnlockTapped: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            GlassCardView(cornerRadius: 24, padding: 28) {
                VStack(spacing: 16) {
                    Image(systemName: "faceid")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("FinControl Pro")
                        .font(.title2.weight(.bold))

                    Text("Seus dados financeiros estão protegidos por biometria.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let authError {
                        Text(authError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: onUnlockTapped) {
                        Label("Desbloquear", systemImage: "lock.open.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 280)
            }
            .padding(24)
        }
    }
}
