import Foundation
import PDFKit
import SwiftUI

enum AnnotationTool: CaseIterable {
    case pointer, ink, text, highlight

    var iconName: String {
        switch self {
        case .pointer: return "hand.draw"
        case .ink: return "pencil.tip"
        case .text: return "text.cursor"
        case .highlight: return "highlighter"
        }
    }
}

final class PDFDocumentManager: ObservableObject {
    @Published var document: PDFDocument?
    @Published var currentTool: AnnotationTool = .pointer
    @Published var annotationColor: Color = .yellow
    @Published var lineWidth: CGFloat = 3.0
    @Published var currentPageIndex: Int = 0

    // simple undo flag
    var canUndo: Bool {
        // can't easily introspect PDFKit's annotations stack; rely on external logic if needed
        // For now, always allow; delegate to Coordinator's stack if you wire it up more tightly
        true
    }

    private var openedURL: URL?

    func open(url: URL) {
        if let doc = PDFDocument(url: url) {
            self.document = doc
            self.openedURL = url
            self.currentPageIndex = 0
        } else {
            print("Failed to open pdf at \(url)")
        }
    }

    func temporarySaveURL() -> URL? {
        guard let document = document else { return nil }
        let filename = (openedURL?.deletingPathExtension().lastPathComponent ?? "Edited") + "-edited.pdf"
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        document.write(to: temp)
        return temp
    }

    func saveTo(url: URL) -> Bool {
        guard let document = document else { return false }
        return document.write(to: url)
    }

    func goToNextPage() {
        guard let doc = document else { return }
        currentPageIndex = min(currentPageIndex + 1, doc.pageCount - 1)
    }
    func goToPreviousPage() {
        currentPageIndex = max(currentPageIndex - 1, 0)
    }

    // placeholder: undo rely on PDFKit pages/annotations removal
    func undoLastAnnotation() {
        // This manager doesn't know annotations added by the PDFKitView Coordinator.
        // For a tight architecture, you can pass a closure or notification from the coordinator to here.
        NotificationCenter.default.post(name: .undoAnnotationRequest, object: nil)
    }
}

extension Notification.Name {
    static let undoAnnotationRequest = Notification.Name("undoAnnotationRequest")
}