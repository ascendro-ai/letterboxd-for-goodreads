/// Share extension that extracts ISBNs from shared URLs (Amazon, Bookshop.org,
/// Goodreads, Google Books, OpenLibrary) and opens the main app to log the book.

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        if let url = data as? URL {
                            self?.openMainApp(with: url)
                        } else {
                            self?.close()
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        if let text = data as? String, let url = URL(string: text) {
                            self?.openMainApp(with: url)
                        } else if let text = data as? String {
                            // Might be an ISBN or book title
                            self?.openMainApp(withQuery: text)
                        } else {
                            self?.close()
                        }
                    }
                    return
                }
            }
        }

        close()
    }

    private func openMainApp(with url: URL) {
        // Extract ISBN from known book URLs
        let isbn = extractISBN(from: url)
        let scheme = "shelf://"
        let deepLink: String

        if let isbn {
            deepLink = "\(scheme)book/isbn/\(isbn)"
        } else {
            deepLink = "\(scheme)search?q=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }

        openURL(deepLink)
    }

    private func openMainApp(withQuery query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        openURL("shelf://search?q=\(encoded)")
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            close()
            return
        }

        // Use the responder chain to open URL in the main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url)
                break
            }
            responder = responder?.next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.close()
        }
    }

    // ISBNs are either 10 or 13 digits. Extract from known URL patterns.
    private func extractISBN(from url: URL) -> String? {
        let urlString = url.absoluteString

        // Amazon: /dp/ISBN or /gp/product/ISBN
        if urlString.contains("amazon") {
            let patterns = ["/dp/", "/gp/product/"]
            for pattern in patterns {
                if let range = urlString.range(of: pattern) {
                    let afterPattern = String(urlString[range.upperBound...])
                    let isbn = String(afterPattern.prefix(while: { $0.isNumber || $0 == "X" }))
                    if isbn.count == 10 || isbn.count == 13 { return isbn }
                }
            }
        }

        // Bookshop.org: /book/ISBN
        if urlString.contains("bookshop.org") {
            if let range = urlString.range(of: "/book/") {
                let isbn = String(urlString[range.upperBound...].prefix(while: { $0.isNumber }))
                if isbn.count == 13 { return isbn }
            }
        }

        // OpenLibrary: /isbn/ISBN
        if urlString.contains("openlibrary.org") {
            if let range = urlString.range(of: "/isbn/") {
                let isbn = String(urlString[range.upperBound...].prefix(while: { $0.isNumber || $0 == "X" }))
                if isbn.count == 10 || isbn.count == 13 { return isbn }
            }
        }

        // Goodreads: extract ISBN from URL path if present, or use book ID for search
        if urlString.contains("goodreads.com") {
            // Some Goodreads URLs contain ISBNs in query params
            if let components = URLComponents(string: urlString),
               let isbn = components.queryItems?.first(where: { $0.name == "isbn" })?.value,
               (isbn.count == 10 || isbn.count == 13) {
                return isbn
            }
        }

        // Google Books: extract ISBN from query params
        if urlString.contains("books.google") {
            if let components = URLComponents(string: urlString),
               let isbn = components.queryItems?.first(where: { $0.name == "isbn" })?.value,
               (isbn.count == 10 || isbn.count == 13) {
                return isbn
            }
        }

        return nil
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
