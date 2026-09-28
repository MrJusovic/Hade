//
//  EnvironmentsView.swift
//  Hade
//
//  Ortamları ve {{değişkenlerini}} yönetmek için pencere.
//

import SwiftUI

struct EnvironmentsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AppEnvironment.createdAt, ascending: true)]
    )
    private var environments: FetchedResults<AppEnvironment>

    @State private var selection: AppEnvironment?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(environments) { env in
                    HStack {
                        Image(systemName: env.isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(env.isActive ? Color.accentColor : Color.secondary)
                        Text(env.name ?? "Ortam")
                    }
                    .tag(env)
                    .contextMenu {
                        Button("Aktif Yap") { store.activate(env) }
                        Button("Sil", role: .destructive) {
                            if selection == env { selection = nil }
                            store.delete(env)
                        }
                    }
                }
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem {
                    Button {
                        let env = store.addEnvironment(name: "Yeni Ortam")
                        selection = env
                    } label: {
                        Label("Ortam Ekle", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let env = selection {
                EnvironmentDetailView(env: env)
                    .id(env.objectID)
                    .environment(store)
            } else {
                ContentUnavailableView(
                    "Ortam seçin",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Değişkenleri düzenlemek için soldan bir ortam seçin veya yeni bir tane ekleyin.")
                )
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Bitti") { dismiss() }
            }
        }
    }
}

/// Tek bir ortamın adını, aktifliğini ve değişkenlerini düzenler.
private struct EnvironmentDetailView: View {
    @Environment(AppStore.self) private var store
    var env: AppEnvironment

    @State private var name: String = ""
    @State private var variables: [KeyValue] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Ortam adı", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .onSubmit { store.rename(env, to: name) }

                if env.isActive {
                    Label("Aktif", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Button("Aktif Yap") { store.activate(env) }
                }
            }
            .padding(12)

            Divider()

            Text("Değişkenler — istekte {{anahtar}} olarak kullanın")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            KeyValueEditorView(items: $variables, keyPlaceholder: "Değişken", valuePlaceholder: "Değer")
        }
        .onAppear {
            guard !loaded else { return }
            name = env.name ?? ""
            variables = AppStore.decodeKeyValues(env.variablesJSON)
            loaded = true
        }
        .onChange(of: variables) { _, newValue in
            store.setVariables(newValue, for: env)
        }
        .onChange(of: name) { _, newValue in
            store.rename(env, to: newValue)
        }
    }
}
