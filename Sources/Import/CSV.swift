import Foundation

/// Minimal RFC 4180-ish CSV parser (quoted fields, embedded commas/newlines,
/// doubled-quote escaping) — enough for YNAB's export format.
enum CSV {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if insideQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else if c == "\"" {
                insideQuotes = true
            } else if c == "," {
                currentRow.append(currentField)
                currentField = ""
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                currentRow.append(currentField)
                currentField = ""
                rows.append(currentRow)
                currentRow = []
            } else {
                currentField.append(c)
            }
            i += 1
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
