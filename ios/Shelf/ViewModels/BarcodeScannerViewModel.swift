import Foundation

@Observable
final class BarcodeScannerViewModel {
    private(set) var scannedBook: Book?
    private(set) var isLookingUp = false
    private(set) var error: Error?
    private(set) var scannedISBN: String?
    var isTorchOn = false

    private let bookService = BookService.shared

    @MainActor
    func processBarcode(_ code: String) async {
        let isbn = code.replacingOccurrences(of: "-", with: "")
        guard ISBNValidator.isValid(isbn) else {
            error = BarcodeScannerError.invalidISBN
            return
        }
        scannedISBN = isbn
        await lookupISBN(isbn)
    }

    @MainActor
    func lookupISBN(_ isbn: String) async {
        guard !isLookingUp else { return }
        isLookingUp = true
        error = nil

        do {
            scannedBook = try await bookService.lookupISBN(isbn)
        } catch {
            self.error = error
        }

        isLookingUp = false
    }

    func reset() {
        scannedBook = nil
        scannedISBN = nil
        error = nil
        isLookingUp = false
    }
}

enum BarcodeScannerError: LocalizedError {
    case invalidISBN
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidISBN: "The scanned barcode is not a valid ISBN."
        case .cameraUnavailable: "Camera is not available on this device."
        }
    }
}
