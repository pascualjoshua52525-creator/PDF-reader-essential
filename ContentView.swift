import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var manager = PDFDocumentManager()
    @State private var showingPicker = false
    @State private var showingShare = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let document = manager.document {
                    PDFKitView(document: document,
                               currentTool: $manager.currentTool,
                               annotationColor: $manager.annotationColor,
                               lineWidth: $manager.lineWidth,
                               currentPageIndex: $manager.currentPageIndex)
                        .overlay(toolOverlay, alignment: .top)
                        .edgesIgnoringSafeArea(.bottom)

                    HStack(spacing: 12) {
                        Button(action: { manager.goToPreviousPage() }) {
                            Label("Prev", systemImage: "chevron.left")
                        }
                        .disabled(manager.document?.pageCount == 0 || manager.currentPageIndex <= 0)

                        Text("Page \(manager.currentPageIndex + 1) / \(manager.document?.pageCount ?? 0)")
                            .frame(maxWidth: .infinity)

                        Button(action: { manager.goToNextPage() }) {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .disabled(manager.document?.pageCount == 0 || manager.currentPageIndex >= (manager.document?.pageCount ?? 1) - 1)
                    }
                    .padding()
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 80))
                            .padding(.bottom)
                        Text("No PDF loaded")
                        Spacer()
                    }
                }
            }
            .navigationTitle("PDF Reader & Editor")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPicker = true }) {
                        Label("Open", systemImage: "folder")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { manager.undoLastAnnotation() }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!manager.canUndo)

                        Button(action: { showingShare.toggle() }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(manager.document == nil)
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                DocumentPicker { url in
                    showingPicker = false
                    if let url = url {
                        manager.open(url: url)
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let url = manager.temporarySaveURL() {
                    ActivityView(activityItems: [url]) {
                        // completion
                    }
                } else {
                    Text("Failed to create share file.")
                }
            }
        }
    }

    private var toolOverlay: some View {
        HStack(spacing: 12) {
            Picker("", selection: $manager.currentTool) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    Image(systemName: tool.iconName).tag(tool)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 260)

            ColorPicker("", selection: $manager.annotationColor)
                .labelsHidden()
                .frame(width: 44)

            Slider(value: $manager.lineWidth, in: 1...10)
                .frame(width: 120)
        }
        .padding(8)
        .background(VisualEffectBlur(blurStyle: .systemUltraThinMaterial))
        .cornerRadius(12)
        .padding()
    }
}