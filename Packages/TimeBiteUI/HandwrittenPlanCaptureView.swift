import SwiftUI
import TimeBiteData

#if os(iOS)
import ImageIO
import UIKit
import Vision
import VisionKit

struct TimeBiteCaptureDraft: Codable, Equatable {
    var project: String
    var goal: String
    var tasks: [TimeBiteCaptureTaskDraft]
    var rawRecognizedText: String
    var source: String
}

struct TimeBiteCaptureTaskDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var allocatedMinutes: Int

    enum CodingKeys: String, CodingKey {
        case title
        case allocatedMinutes
    }
}

enum HandwrittenPlanCaptureError: LocalizedError {
    case cameraUnavailable
    case noPagesCaptured
    case recognitionFailed
    case emptyRecognition

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Document scanning is not available on this device."
        case .noPagesCaptured:
            return "No pages were captured."
        case .recognitionFailed:
            return "TimeBite could not recognize text from the scanned page."
        case .emptyRecognition:
            return "No handwriting was recognized. Try scanning again with better light."
        }
    }
}

@MainActor
final class HandwrittenPlanCaptureController: ObservableObject {
    @Published var isScannerPresented = false
    @Published var isRecognizing = false
    @Published var reviewState: HandwrittenPlanReviewState?
    @Published var errorMessage: String?

    var canScan: Bool { VNDocumentCameraViewController.isSupported }

    func startScan() {
        guard canScan else {
            errorMessage = HandwrittenPlanCaptureError.cameraUnavailable.localizedDescription
            return
        }
        isScannerPresented = true
    }

    func recognize(images: [UIImage]) {
        guard !images.isEmpty else {
            errorMessage = HandwrittenPlanCaptureError.noPagesCaptured.localizedDescription
            return
        }
        isRecognizing = true
        Task {
            do {
                let text = try await HandwrittenTextRecognizer.recognize(images: images)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw HandwrittenPlanCaptureError.emptyRecognition }
                reviewState = HandwrittenPlanReviewState(
                    image: images[0],
                    draft: TimeBiteCaptureParser.parse(rawText: trimmed)
                )
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isRecognizing = false
        }
    }
}

struct HandwrittenPlanReviewState: Identifiable {
    let id = UUID()
    let image: UIImage
    var draft: TimeBiteCaptureDraft
}

enum HandwrittenTextRecognizer {
    static func recognize(images: [UIImage]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            var pages: [String] = []
            for image in images {
                guard let cgImage = image.cgImage else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.01

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
                try handler.perform([request])
                let lines = request.results?
                    .sorted { lhs, rhs in
                        if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02 {
                            return lhs.boundingBox.midY > rhs.boundingBox.midY
                        }
                        return lhs.boundingBox.minX < rhs.boundingBox.minX
                    }
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                if !lines.isEmpty {
                    pages.append(lines.joined(separator: "\n"))
                }
            }
            guard !pages.isEmpty else { throw HandwrittenPlanCaptureError.recognitionFailed }
            return pages.joined(separator: "\n\n")
        }.value
    }
}

enum TimeBiteCaptureParser {
    static func parse(rawText: String) -> TimeBiteCaptureDraft {
        var project = ""
        var goal = ""
        var tasks: [TimeBiteCaptureTaskDraft] = []
        var section: Section?

        for rawLine in rawText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            switch line.uppercased() {
            case "PROJECT":
                section = .project
                continue
            case "GOAL":
                section = .goal
                continue
            case "TASK", "TASKS":
                section = .tasks
                continue
            default:
                break
            }

            switch section {
            case .project:
                project = append(line, to: project)
            case .goal:
                goal = append(line, to: goal)
            case .tasks:
                tasks.append(parseTask(line))
            case nil:
                if project.isEmpty {
                    project = line
                } else {
                    tasks.append(parseTask(line))
                }
            }
        }

        return TimeBiteCaptureDraft(
            project: project,
            goal: goal,
            tasks: tasks.isEmpty ? [TimeBiteCaptureTaskDraft(title: "", allocatedMinutes: 25)] : tasks,
            rawRecognizedText: rawText,
            source: "handwriting"
        )
    }

    private enum Section {
        case project
        case goal
        case tasks
    }

    private static func append(_ line: String, to existing: String) -> String {
        existing.isEmpty ? line : "\(existing) \(line)"
    }

    private static func parseTask(_ line: String) -> TimeBiteCaptureTaskDraft {
        let pattern = #"(?i)\s*[-–—:]?\s*(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valueRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let fullRange = Range(match.range(at: 0), in: line),
              let value = Double(line[valueRange]) else {
            return TimeBiteCaptureTaskDraft(title: line, allocatedMinutes: 25)
        }
        let unit = line[unitRange].lowercased()
        let minutes = unit.hasPrefix("h") ? Int((value * 60).rounded()) : Int(value.rounded())
        let title = String(line[..<fullRange.lowerBound])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:")))
        return TimeBiteCaptureTaskDraft(title: title, allocatedMinutes: max(1, minutes))
    }
}

struct HandwrittenPlanCaptureButton: View {
    @ObservedObject var capture: HandwrittenPlanCaptureController
    let onSave: (TimeBiteCaptureDraft) -> Void
    var iconOnly = false

    var body: some View {
        Button {
            capture.startScan()
        } label: {
            Group {
                if iconOnly {
                    Image(systemName: "doc.viewfinder")
                        .frame(minWidth: 44, minHeight: 44)
                } else {
                    Label("Scan Handwritten Plan", systemImage: "doc.viewfinder")
                }
            }
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Scan handwritten plan")
        .disabled(capture.isRecognizing)
        .sheet(isPresented: $capture.isScannerPresented) {
            DocumentScannerView { result in
                capture.isScannerPresented = false
                switch result {
                case .success(let images):
                    capture.recognize(images: images)
                case .cancelled:
                    break
                case .failure(let error):
                    capture.errorMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $capture.reviewState) { state in
            HandwrittenPlanReviewView(state: state) { draft in
                onSave(draft)
                capture.reviewState = nil
            } onCancel: {
                capture.reviewState = nil
            }
        }
        .overlay {
            if capture.isRecognizing {
                ProgressView("Recognizing handwriting...")
                    .padding()
                    .background(.regularMaterial, in: Rectangle())
            }
        }
    }
}

struct HandwrittenPlanReviewView: View {
    @State private var state: HandwrittenPlanReviewState
    let onSave: (TimeBiteCaptureDraft) -> Void
    let onCancel: () -> Void

    init(
        state: HandwrittenPlanReviewState,
        onSave: @escaping (TimeBiteCaptureDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _state = State(initialValue: state)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scanned page") {
                    Image(uiImage: state.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                }
                Section("Recognized text") {
                    TextEditor(text: $state.draft.rawRecognizedText)
                        .frame(minHeight: 140)
                        .font(.body.monospaced())
                }
                Section("Project") {
                    TextField("Project", text: $state.draft.project)
                }
                Section("Goal") {
                    TextField("Goal", text: $state.draft.goal)
                }
                Section("Tasks") {
                    ForEach($state.draft.tasks) { $task in
                        HStack {
                            TextField("Task", text: $task.title)
                            Spacer()
                            TextField("Minutes", value: $task.allocatedMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                    .onDelete { offsets in
                        state.draft.tasks.remove(atOffsets: offsets)
                    }
                    Button {
                        state.draft.tasks.append(TimeBiteCaptureTaskDraft(title: "", allocatedMinutes: 25))
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Review Scan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to TimeBite") { onSave(state.draft) }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !state.draft.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        state.draft.tasks.contains {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.allocatedMinutes > 0
        }
    }
}

enum DocumentScannerResult {
    case success([UIImage])
    case cancelled
    case failure(Error)
}

struct DocumentScannerView: UIViewControllerRepresentable {
    fileprivate let completion: (DocumentScannerResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (DocumentScannerResult) -> Void

        init(completion: @escaping (DocumentScannerResult) -> Void) {
            self.completion = completion
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            completion(.success(images))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(.cancelled)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion(.failure(error))
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
#endif
