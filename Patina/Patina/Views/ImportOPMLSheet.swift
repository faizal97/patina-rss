import SwiftUI
import UniformTypeIdentifiers

/// Sheet for importing OPML files
struct ImportOPMLSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var importResult: OpmlImportResult?
    @State private var isImporting = false
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignTokens.Colors.accent)
                Text("Import OPML")
                    .font(DesignTokens.Typography.headingLarge)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }

            if let result = importResult {
                // Show results
                ImportResultView(result: result)
            } else {
                // Show import options
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    Text("Import feeds from an OPML file")
                        .font(DesignTokens.Typography.headingSmall)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("OPML files can be exported from most RSS readers like Feedly, NetNewsWire, or Reeder.")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .multilineTextAlignment(.center)

                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Choose OPML File...")
                            .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                            .foregroundStyle(DesignTokens.Colors.backgroundPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(DesignTokens.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }
                .padding()
            }

            Spacer()

            HStack {
                Button(importResult != nil ? "Done" : "Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .keyboardShortcut(.escape)

                Spacer()

                if importResult != nil {
                    Button {
                        importResult = nil
                        showFilePicker = true
                    } label: {
                        Text("Import Another")
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 450, height: 350)
        .background(DesignTokens.Colors.backgroundSecondary)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .overlay {
            if isImporting {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .tint(DesignTokens.Colors.accent)
                    Text("Importing feeds...")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(url)

        case .failure(let error):
            appState.errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    private func importFile(_ url: URL) {
        isImporting = true

        Task {
            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    appState.errorMessage = "Failed to access file"
                    isImporting = false
                    return
                }

                defer { url.stopAccessingSecurityScopedResource() }

                let content = try String(contentsOf: url, encoding: .utf8)
                importResult = await appState.importOPML(content: content)
            } catch {
                appState.errorMessage = "Failed to read file: \(error.localizedDescription)"
            }

            isImporting = false
        }
    }
}

struct ImportResultView: View {
    let result: OpmlImportResult

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: result.failedFeeds == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(result.failedFeeds == 0 ? DesignTokens.Colors.success : DesignTokens.Colors.warning)

            Text("Import Complete")
                .font(DesignTokens.Typography.headingMedium)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("Total feeds found:")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Text("\(result.totalFeeds)")
                        .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                HStack {
                    Text("Successfully imported:")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Text("\(result.importedFeeds)")
                        .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                        .foregroundStyle(DesignTokens.Colors.success)
                }

                if result.failedFeeds > 0 {
                    HStack {
                        Text("Failed:")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Spacer()
                        Text("\(result.failedFeeds)")
                            .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                            .foregroundStyle(DesignTokens.Colors.error)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

            if !result.errors.isEmpty {
                DisclosureGroup {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            ForEach(result.errors, id: \.self) { error in
                                Text(error)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                } label: {
                    Text("Show errors")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    ImportOPMLSheet()
        .environment(AppState())
}
