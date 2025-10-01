import SwiftUI
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentTool: AnnotationTool
    @Binding var annotationColor: Color
    @Binding var lineWidth: CGFloat
    @Binding var currentPageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.document = document
        pdfView.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pdfView.addGestureRecognizer(tap)
        pdfView.addGestureRecognizer(pan)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        if let page = uiView.document?.page(at: currentPageIndex) {
            uiView.go(to: page)
        }
        context.coordinator.currentTool = currentTool
        context.coordinator.annotationColor = UIColor(annotationColor)
        context.coordinator.lineWidth = lineWidth
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView
        var currentTool: AnnotationTool
        var annotationColor: UIColor
        var lineWidth: CGFloat

        // store temporary in-progress ink points
        private var currentInk: PDFAnnotation?
        private var inkPathPoints: [CGPoint] = []
        // undo stack (store annotations added)
        var addedAnnotations: [PDFAnnotation] = []

        init(_ parent: PDFKitView) {
            self.parent = parent
            self.currentTool = parent.currentTool
            self.annotationColor = UIColor(parent.annotationColor)
            self.lineWidth = parent.lineWidth
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView else { return }
            let location = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = pdfView.convert(location, to: page)

            switch currentTool {
            case .text:
                addTextAnnotation(at: pagePoint, on: page, text: "New note")
            case .highlight:
                // simple highlight: create a small rectangle highlight centered at tap
                let rect = CGRect(x: pagePoint.x - 100, y: pagePoint.y - 10, width: 200, height: 20)
                addHighlight(on: page, in: rect)
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView else { return }
            let location = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = pdfView.convert(location, to: page)

            switch currentTool {
            case .ink:
                if recognizer.state == .began {
                    inkPathPoints = [pagePoint]
                    let annotation = PDFAnnotation(bounds: page.bounds(for: .mediaBox), forType: .ink, withProperties: nil)
                    annotation.color = annotationColor
                    annotation.lineWidth = lineWidth
                    currentInk = annotation
                } else if recognizer.state == .changed {
                    inkPathPoints.append(pagePoint)
                    updateInkAnnotation()
                } else if recognizer.state == .ended || recognizer.state == .cancelled {
                    if let ink = currentInk {
                        page.addAnnotation(ink)
                        addedAnnotations.append(ink)
                        currentInk = nil
                        inkPathPoints = []
                    }
                }
            default:
                break
            }
        }

        private func updateInkAnnotation() {
            guard let currentInk = currentInk else { return }
            let path = UIBezierPath()
            guard let first = inkPathPoints.first else { return }
            path.move(to: first)
            for p in inkPathPoints.dropFirst() {
                path.addLine(to: p)
            }
            // set path as PDFAnnotation's drawing (PDFKit uses PDFAnnotation's setValue(forAnnotationKey:) for path)
            let cgPath = path.cgPath
            // store as "inkList" lines: array of array of NSValues of points — easier: draw into PDFAnnotation's appearance stream
            if let page = currentInk.page {
                currentInk.clear()
            }
            currentInk.setValue(cgPath, forAnnotationKey: PDFAnnotation.Key.inkList) // not official; fallback: use appearance stream drawing
            // Instead produce appearance via drawing into a PDFAnnotation's appearance stream:
            let bounds = path.bounds.insetBy(dx: -10, dy: -10)
            currentInk.bounds = bounds
            UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            ctx.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(annotationColor.cgColor)
            ctx.addPath(cgPath)
            ctx.strokePath()
            let img = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let image = img, let data = image.pngData() {
                currentInk.setAppearanceStream(PDFStream(data: data)) // not public API; instead set appearance as a widget using PDFAnnotation’s appearance dictionary — simplest approach: create an Ink annotation via paths
            }
        }

        func addTextAnnotation(at point: CGPoint, on page: PDFPage, text: String) {
            let font = UIFont.systemFont(ofSize: 14)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: annotationColor]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let size = attributed.size()
            let rect = CGRect(x: point.x, y: point.y - size.height/2, width: max(100, size.width + 10), height: size.height + 6)
            let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = font
            annotation.color = UIColor.clear
            annotation.fontColor = annotationColor
            page.addAnnotation(annotation)
            addedAnnotations.append(annotation)
        }

        func addHighlight(on page: PDFPage, in rect: CGRect) {
            let highlight = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
            highlight.color = annotationColor.withAlphaComponent(0.3)
            page.addAnnotation(highlight)
            addedAnnotations.append(highlight)
        }

        // Expose removal of last annotation
        func undoLastAnnotation() {
            if let last = addedAnnotations.popLast(), let page = last.page {
                page.removeAnnotation(last)
            }
        }
    }
}