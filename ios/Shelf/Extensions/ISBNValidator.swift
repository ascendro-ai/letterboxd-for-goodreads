import Foundation

/// Static ISBN-10 and ISBN-13 check digit validation.
/// ISBN-10 uses modulo-11 (with 'X' = 10). ISBN-13 uses modulo-10.
enum ISBNValidator {

    /// Validates an ISBN-10 or ISBN-13 string.
    static func isValid(_ isbn: String) -> Bool {
        let digits = isbn.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        switch digits.count {
        case 10: return isValidISBN10(digits)
        case 13: return isValidISBN13(digits)
        default: return false
        }
    }

    /// Normalizes to ISBN-13. Returns nil if invalid.
    static func normalize(_ isbn: String) -> String? {
        let digits = isbn.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        guard isValid(digits) else { return nil }
        if digits.count == 13 { return digits }
        // Convert ISBN-10 to ISBN-13
        let prefix = "978" + digits.prefix(9)
        let checkDigit = isbn13CheckDigit(String(prefix))
        return prefix + String(checkDigit)
    }

    // MARK: - Private

    /// ISBN-10 check: sum of (digit * position) mod 11 == 0, where X = 10.
    private static func isValidISBN10(_ isbn: String) -> Bool {
        let chars = Array(isbn)
        var sum = 0
        for i in 0..<10 {
            let c = chars[i]
            let value: Int
            if i == 9 && (c == "X" || c == "x") {
                value = 10
            } else if let digit = c.wholeNumberValue {
                value = digit
            } else {
                return false
            }
            sum += value * (10 - i)
        }
        return sum % 11 == 0
    }

    /// ISBN-13 check: alternating weights 1 and 3, sum mod 10 == 0.
    private static func isValidISBN13(_ isbn: String) -> Bool {
        let chars = Array(isbn)
        var sum = 0
        for i in 0..<13 {
            guard let digit = chars[i].wholeNumberValue else { return false }
            sum += digit * (i.isMultiple(of: 2) ? 1 : 3)
        }
        return sum % 10 == 0
    }

    /// Computes the ISBN-13 check digit for a 12-character prefix.
    private static func isbn13CheckDigit(_ prefix: String) -> Int {
        let chars = Array(prefix)
        var sum = 0
        for i in 0..<12 {
            guard let digit = chars[i].wholeNumberValue else { return 0 }
            sum += digit * (i.isMultiple(of: 2) ? 1 : 3)
        }
        return (10 - (sum % 10)) % 10
    }
}
