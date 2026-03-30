import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // Paywall State
    @State private var showPaywall = false
    
    // App Preferences
    @State private var isLocationSharingEnabled = true
    @State private var receiveLessonReminders = true
    @State private var receiveCommunityAlerts = true
    @State private var isPrivacyConsentShowing = false
    
    // Profile Privacy Settings
    @State private var isProfilePrivate = false
    @State private var hideFollowers = false
    @State private var hideEmail = false
    
    // Danger Zone State
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var password = ""
    
    // Export/Import State
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    var isInstructor: Bool {
        authManager.role == .instructor
    }

    var body: some View {
        NavigationView {
            Form {
                proStatusSection
                
                preferencesSection
                
                privacySection
                
                dataManagementSection
                
                accountActionsSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $isPrivacyConsentShowing) {
                PrivacyConsentPopup(isLocationSharingEnabled: $isLocationSharingEnabled)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(alertMessage ?? "Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                if let user = authManager.user {
                    self.isProfilePrivate = user.isPrivate ?? false
                    self.hideFollowers = user.hideFollowers ?? false
                    self.hideEmail = user.hideEmail ?? false
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                SecureField("Enter Password", text: $password)
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performAccountDeletion()
                }
            } message: {
                Text("Please enter your password to confirm. This action will permanently delete your profile and community posts.")
            }
        }
    }
    
    // MARK: - Sub-Views (To prevent compiler complexity errors)
    
    private var proStatusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.user?.name ?? "Instructor")
                        .font(.headline)
                    Text(authManager.user?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if subscriptionManager.isPro {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("PRO")
                            .fontWeight(.black)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primaryBlue.opacity(0.1))
                    .cornerRadius(8)
                } else if isInstructor {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Upgrade")
                            .font(.caption).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Enable Live Location", isOn: $isLocationSharingEnabled)
                .tint(.primaryBlue)
                .onChange(of: isLocationSharingEnabled) { newValue in
                    if newValue { isPrivacyConsentShowing = true }
                }
            
            Toggle("Lesson Reminders", isOn: $receiveLessonReminders).tint(.primaryBlue)
            Toggle("Community Alerts", isOn: $receiveCommunityAlerts).tint(.primaryBlue)
        }
    }
    
    private var privacySection: some View {
        Section("Profile Privacy") {
            Toggle("Private Profile", isOn: $isProfilePrivate)
                .tint(.primaryBlue)
                .onChange(of: isProfilePrivate) { _ in savePrivacySettings() }
            
            if isProfilePrivate {
                Text("Only approved followers can see your posts and details.")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Toggle("Hide Follower & Following Counts", isOn: $hideFollowers)
                .tint(.primaryBlue)
                .onChange(of: hideFollowers) { _ in savePrivacySettings() }
            
            Toggle("Hide Email Address", isOn: $hideEmail)
                .tint(.primaryBlue)
                .onChange(of: hideEmail) { _ in savePrivacySettings() }
        }
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button {
                performExport()
            } label: {
                HStack {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if isExporting { ProgressView() }
                }
            }
            .foregroundColor(.primary)
            .disabled(isExporting)
            
            Button {
                showImportPicker = true
            } label: {
                HStack {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                    Spacer()
                    if isImporting { ProgressView() }
                }
            }
            .foregroundColor(.primary)
            .disabled(isImporting)
        }
    }
    
    private var accountActionsSection: some View {
        Section {
            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                    alertMessage = "Purchase restoration complete."
                    showAlert = true
                }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
            }
            .foregroundColor(.primaryBlue)

            Button(role: .destructive) {
                try? authManager.logout()
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
            
            Button(role: .destructive) {
                password = ""
                showDeleteConfirmation = true
            } label: {
                if isDeleting {
                    ProgressView().tint(.red)
                } else {
                    Label("Delete Account", systemImage: "trash")
                }
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Deleting your account will permanently remove your profile, community posts, and all associated personal data from our servers. This action cannot be undone.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
    
    // MARK: - Actions
    
    private func performExport() {
        guard let userID = authManager.user?.id else { return }
        isExporting = true
        
        Task {
            do {
                let data = try await BackupManager.shared.createBackupData(for: userID)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm"
                let dateString = formatter.string(from: Date())
                let fileName = "MyInstructor_Backup_\(dateString).json"
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    self.exportURL = tempURL
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Export Failed: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isExporting = false
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        guard let userID = authManager.user?.id else { return }
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                self.alertMessage = "Permission denied."
                self.showAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            isImporting = true
            Task {
                do {
                    try await BackupManager.shared.restoreBackup(from: url, for: userID)
                    await MainActor.run {
                        self.alertMessage = "Data imported successfully!"
                        self.showAlert = true
                        self.isImporting = false
                    }
                } catch {
                    await MainActor.run {
                        self.alertMessage = "Import Failed: \(error.localizedDescription)"
                        self.showAlert = true
                        self.isImporting = false
                    }
                }
            }
        case .failure(let error):
            self.alertMessage = "Import error: \(error.localizedDescription)"
            self.showAlert = true
        }
    }
    
    private func savePrivacySettings() {
        Task {
            try? await authManager.updatePrivacySettings(
                isPrivate: isProfilePrivate,
                hideFollowers: hideFollowers,
                hideEmail: hideEmail
            )
        }
    }
    
    private func performAccountDeletion() {
        guard !password.isEmpty else { return }
        isDeleting = true
        Task {
            do {
                try await authManager.deleteAccount(password: password)
            } catch {
                isDeleting = false
            }
        }
    }
}

// MARK: - MISSING HELPERS restored

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PrivacyConsentPopup: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLocationSharingEnabled: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.primaryBlue)
            Text("Live Location Consent").font(.largeTitle).bold()
            Text("Location is shared only during active lessons.").multilineTextAlignment(.center).padding(.horizontal)
            Button("Allow") { isLocationSharingEnabled = true; dismiss() }.buttonStyle(.primaryDrivingApp)
        }.padding(30)
    }
}
