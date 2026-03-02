import Foundation

/// Typed book identifier extracted from URLs shared via the share extension
/// or deep links. Each case maps to a different lookup strategy.
enum BookIdentifier {
    case isbn(String)
    case amazonASIN(String)
    case openLibraryWork(String)
    case goodreadsID(String)
    case rawURL(URL)

    /// Attempts to extract a typed book identifier from a URL.
    static func extract(from url: URL) -> BookIdentifier {
        let urlString = url.absoluteString

        // Amazon: /dp/ASIN or /gp/product/ASIN
        if urlString.contains("amazon") {
            for pattern in ["/dp/", "/gp/product/"] {
                if let range = urlString.range(of: pattern) {
                    let afterPattern = String(urlString[range.upperBound...])
                    let id = String(afterPattern.prefix(while: { $0.isLetter || $0.isNumber }))
                    if id.count == 10 || id.count == 13 {
                        // Could be ISBN or ASIN
                        if id.allSatisfy({ $0.isNumber || $0 == "X" }) && ISBNValidator.isValid(id) {
                            return .isbn(id)
                        }
                        return .amazonASIN(id)
                    }
                }
            }
        }

        // Bookshop.org: /book/ISBN
        if urlString.contains("bookshop.org") {
            if let range = urlString.range(of: "/book/") {
                let isbn = String(urlString[range.upperBound...].prefix(while: { $0.isNumber }))
                if isbn.count == 13 { return .isbn(isbn) }
            }
        }

        // OpenLibrary: /isbn/ISBN or /works/OLID
        if urlString.contains("openlibrary.org") {
            if let range = urlString.range(of: "/isbn/") {
                let isbn = String(urlString[range.upperBound...].prefix(while: { $0.isNumber || $0 == "X" }))
                if isbn.count == 10 || isbn.count == 13 { return .isbn(isbn) }
            }
            if let range = urlString.range(of: "/works/") {
                let olid = String(urlString[range.upperBound...].prefix(while: { $0.isLetter || $0.isNumber }))
                if !olid.isEmpty { return .openLibraryWork(olid) }
            }
        }

        // Goodreads: /book/show/ID or /book/show/ID-slug
        if urlString.contains("goodreads.com") {
            if let range = urlString.range(of: "/book/show/") {
                let afterShow = String(urlString[range.upperBound...])
                let grID = String(afterShow.prefix(while: { $0.isNumber }))
                if !grID.isEmpty { return .goodreadsID(grID) }
            }
        }

        // Google Books: /books?id=VOLUMEID
        if urlString.contains("books.google") {
            if let components = URLComponents(string: urlString),
               let volumeID = components.queryItems?.first(where: { $0.name == "id" })?.value {
                // Google Books volume IDs can be looked up via search
                return .rawURL(url)
            }
        }

        return .rawURL(url)
    }
}
