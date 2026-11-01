import Foundation
import UIKit
import Vision

public enum VisionOCRTool {

    public static func scanScheduleTables(
        images: [UIImage],
        targetName: String,
        year: Int = 2026,
        month: Int = 11
    ) async -> VisionTableOCRResult {
        var allPageTexts: [String] = []
        var matchedRows: [String] = []
        var allCalendarCells: [VisionCalendarCellOCR] = []
        let nameCandidates = buildNameCandidates(targetName)

        for (idx, rawImg) in images.enumerated() {
            let img = normalizeOrientation(rawImg)
            guard let cgImage = img.cgImage else { continue }
            let observations = await recognizeTextObservations(in: cgImage)

            let pageCells = extractSevenColumnCalendarCells(
                observations: observations,
                targetName: targetName,
                year: year,
                month: month
            )
            allCalendarCells.append(contentsOf: pageCells)

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
            calendarCells: allCalendarCells,
            pageCount: images.count
        )
    }

    private static func extractSevenColumnCalendarCells(
        observations: [VNRecognizedTextObservation],
        targetName: String,
        year: Int,
        month: Int
    ) -> [VisionCalendarCellOCR] {
        guard !observations.isEmpty else { return [] }
        let weekdayMap: [(key: String, col: Int)] = [
            ("星期一", 0), ("週一", 0), ("星期二", 1), ("週二", 1),
            ("星期三", 2), ("週三", 2), ("星期四", 3), ("週四", 3),
            ("星期五", 4), ("週五", 4), ("星期六", 5), ("週六", 5),
            ("星期日", 6), ("週日", 6), ("星期天", 6)
        ]

        var headerObs: [(col: Int, box: CGRect)] = []
        for obs in observations {
            guard let text = obs.topCandidates(1).first?.string else { continue }
            for item in weekdayMap where text.contains(item.key) {
                headerObs.append((item.col, obs.boundingBox))
                break
            }
        }

        let headerY = headerObs.isEmpty ? 0.72 : (headerObs.map { $0.box.minY }.reduce(0, +) / CGFloat(headerObs.count))
        let gridMinX: CGFloat = 0.05
        let gridMaxX: CGFloat = 0.95
        let bodyObs = observations.filter { $0.boundingBox.midY < headerY - 0.005 && $0.boundingBox.midY > 0.03 }
        guard !bodyObs.isEmpty else { return [] }

        let gridTopY = headerY - 0.005
        let gridBottomY = max(0.03, (bodyObs.map { $0.boundingBox.minY }.min() ?? 0.06) - 0.01)
        let rowHeight = max(0.05, (gridTopY - gridBottomY) / 4.0)
        let colWidth = (gridMaxX - gridMinX) / 7.0

        var cellTokens: [[String]] = Array(repeating: [], count: 28)
        var mondayVotes: [Int: Int] = [:]
        let dim = PayrollEngine.daysInMonth(year: year, month: month)

        for obs in bodyObs {
            let candidates = obs.topCandidates(3).map { $0.string }
            guard let topStr = candidates.first else { continue }
            let col = max(0, min(6, Int((obs.boundingBox.midX - gridMinX) / colWidth)))
            let rowFromTop = max(0, min(3, Int((gridTopY - obs.boundingBox.midY) / rowHeight)))
            cellTokens[rowFromTop * 7 + col].append(candidates.joined(separator: " "))

            if let numMatch = topStr.range(of: #"^\s*(\d{1,2})\b"#, options: .regularExpression) {
                let digits = String(topStr[numMatch]).trimmingCharacters(in: .whitespaces)
                if let d = Int(digits), d >= 1 && d <= dim {
                    let dk = PayrollEngine.dateKey(year: year, month: month, day: d)
                    if (PayrollEngine.weekdayIndex(of: dk) + 6) % 7 == col {
                        mondayVotes[d - (rowFromTop * 7 + col), default: 0] += 1
                    }
                }
            }
        }

        let firstWd = PayrollEngine.weekdayIndex(of: PayrollEngine.dateKey(year: year, month: month, day: 1))
        let fallbackMonday = firstWd == 1 ? 1 : (firstWd == 0 ? 2 : (9 - firstWd))
        let row0Monday = mondayVotes.max(by: { $0.value < $1.value })?.key ?? fallbackMonday

        var results: [VisionCalendarCellOCR] = []
        for r in 0..<4 {
            for c in 0..<7 {
                let day = row0Monday + r * 7 + c
                guard day >= 1 && day <= dim else { continue }
                let rawText = cellTokens[r * 7 + c].joined(separator: " ")
                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let detected = ScheduleJSONParser.extractEmployeeShiftFromCellText(rawText, employeeName: targetName)
                results.append(
                    VisionCalendarCellOCR(
                        day: day,
                        weekdayColumn: c,
                        rawCellText: rawText,
                        normalizedCellText: detected?.matchedSegment ?? rawText,
                        detectedShiftCode: detected?.shiftCode
                    )
                )
            }
        }
        return results
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func buildNameCandidates(_ name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ["弘"] }
        var list = [trimmed, "弘"]
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
