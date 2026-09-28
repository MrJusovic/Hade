//
//  ContentView.swift
//  Hade
//
//  Ana ekran: kenar çubuğu + istek editörü + yanıt paneli.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AppEnvironment.createdAt, ascending: true)]
    )
    private var environments: FetchedResults<AppEnvironment>

    @State private var showingEnvironments = false
    @State private var showingImport = false

    private var activeEnvironment: AppEnvironment? {
        environments.first { $0.isActive }
    }

    var body: some View {
        @Bindable var store = store
        return NavigationSplitView {
            SidebarView()
                .frame(minWidth: 240)
                .toolbar {
                    ToolbarItem {
                        Button {
                            store.newTab()
                        } label: {
                            Label("Yeni İstek", systemImage: "plus")
                        }
                        .help("Yeni İstek")
                    }
                    ToolbarItem {
                        Button {
                            store.importError = nil
                            showingImport = true
                        } label: {
                            Label("Swagger İçe Aktar", systemImage: "square.and.arrow.down.on.square")
                        }
                        .help("Swagger / OpenAPI İçe Aktar")
                    }
                }
        } detail: {
            VStack(spacing: 0) {
                tabBar
                Divider()
                VSplitView {
                    RequestEditorView()
                        .frame(minHeight: 220)

                    ResponseView(
                        response: store.response,
                        isSending: store.isSending,
                        errorMessage: store.errorMessage,
                        scriptConsole: store.scriptConsole,
                        scriptError: store.scriptError
                    )
                    .frame(minHeight: 160)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Hade")
                        .font(.headline)
                }
                ToolbarItem(placement: .primaryAction) {
                    environmentMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.showAbout = true
                    } label: {
                        Label("Bilgi", systemImage: "info.circle")
                    }
                    .help("Hakkında / Güncellemeler")
                }
            }
        }
        .sheet(isPresented: $showingEnvironments) {
            EnvironmentsView()
                .environment(store)
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
                .environment(store)
        }
        .sheet(isPresented: $store.showAbout) {
            AboutView()
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(store.tabs) { tab in
                    tabChip(tab)
                    Divider().frame(height: 18)
                }
                Button {
                    store.newTab()
                } label: {
                    Image(systemName: "plus")
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Yeni Sekme")
            }
        }
        .frame(height: 34)
        .background(.bar)
    }

    private func tabChip(_ tab: RequestTab) -> some View {
        let isActive = tab.id == store.activeTabID
        return HStack(spacing: 6) {
            Text(tab.draft.method.rawValue)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Color(tintName: tab.draft.method.tintName))
            Text(tab.title)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Button {
                store.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Sekmeyi Kapat")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { store.selectTab(tab.id) }
    }

    private var environmentMenu: some View {
        Menu {
            Button {
                store.deactivateAllEnvironments()
            } label: {
                if activeEnvironment == nil {
                    Label("Hiçbiri (değişken yok)", systemImage: "checkmark")
                } else {
                    Text("Hiçbiri (değişken yok)")
                }
            }
            if !environments.isEmpty {
                Divider()
                ForEach(environments) { env in
                    Button {
                        store.activate(env)
                    } label: {
                        if env.isActive {
                            Label(env.name ?? "Ortam", systemImage: "checkmark")
                        } else {
                            Text(env.name ?? "Ortam")
                        }
                    }
                }
            }
            Divider()
            Button("Ortamları Yönet…") { showingEnvironments = true }
        } label: {
            Label(activeEnvironment?.name ?? "Ortam Yok", systemImage: "cube.transparent")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    ContentView()
        .environment(\.managedObjectContext, context)
        .environment(AppStore(context: context))
}
