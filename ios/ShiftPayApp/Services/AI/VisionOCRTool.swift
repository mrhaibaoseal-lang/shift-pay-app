import Foundation
import UIKit
import Vision

public enum VisionOCRTool {

    public static func scanScheduleTables(images: [UIImage], targetName: String) async -> VisionTableOCRResult {
        var allPageTexts: [String] = []
        var matchedRows: [String] = []
        let nameCandidates = buildNameCandidates(targetName)

        for (idx, img) in images.enumerated() {
            guard let cgImage = img.cgImage else { continue }
            let observations = await recognizeTextObservations(in: cgImage)

            let sortedByY = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []

            for obs in sortedByY {
                if let lastRow = rows.last,
                   let firstInRow = lastRow.first,
                   abs(firstInRow.boundingBox.midY - obs.boundingBox.midY) < 0.022 {
                    rows[rows.count - 1].append(obs)
                } else {
                    rows.append([obs])
                }
            }

            var pageLines: [String] = []
            for row in rows {
                let sortedByX = row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                let rowStr = sortedByX.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " | ")
                if !rowStr.isEmpty {
                    pageLines.append(rowStr)
                    if nameCandidates.contains(where: { rowStr.contains($0) }) {
                        matchedRows.append("[第\(idx + 1)頁] \(rowStr)")
                    }
                }
            }
            if !pageLines.isEmpty {
                allPageTexts.append("--- 第 \(idx + 1) 頁 ---\n" + pageLines.joined(separator: "\n"))
            }
        }

        return VisionTableOCRResult(
            fullRecognizedText: allPageTexts.joined(separator: "\n\n"),
            matchedEmployeeRowTexts: matchedRows,
            pageCount: images.count
        )
    }

    private static func buildNameCandidates(_ name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var list = [trimmed]
        if trimmed.count >= 2 { list.append(String(trimmed.suffix(2))) }
        if trimmed.count >= 1 { list.append(String(trimmed.suffix(1))) }
        return Array(Set(list))
    }

    private static func recognizeTextObservations(in cgImage: CGImage) async -> [VNRecognizedTextObservation] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let results = (req.results as? [VNRecognizedTextObservation]) ?? []
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
