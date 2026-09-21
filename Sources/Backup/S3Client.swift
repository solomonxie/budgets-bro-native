import Foundation

struct S3Config: Hashable {
    var bucket: String
    var region: String
    var accessKeyID: String
    var secretAccessKey: String
    var prefix: String = ""
}

struct S3ObjectSummary: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var sizeBytes: Int
    var lastModified: String
}

enum S3Error: LocalizedError {
    case httpError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .httpError(code, body): "S3 request failed (\(code)): \(body)"
        case .invalidResponse: "Unexpected response from S3"
        }
    }
}

/// Minimal virtual-hosted-style S3 REST client over `URLSession` — no AWS
/// SDK, per AGENTS.md. Covers exactly what this app needs: put/get/head/
/// delete an object and list a prefix.
final class S3Client {
    let config: S3Config
    private let signer: SigV4

    init(config: S3Config) {
        self.config = config
        signer = SigV4(accessKeyID: config.accessKeyID, secretAccessKey: config.secretAccessKey, region: config.region)
    }

    private var baseURL: URL {
        URL(string: "https://\(config.bucket).s3.\(config.region).amazonaws.com/")!
    }

    private func objectURL(key: String) -> URL {
        baseURL.appendingPathComponent(key)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw S3Error.invalidResponse }
        return (data, http)
    }

    func putObject(key: String, data: Data) async throws {
        var request = URLRequest(url: objectURL(key: key))
        request.httpMethod = "PUT"
        request.httpBody = data
        signer.sign(request: &request, payload: data)
        let (body, response) = try await send(request)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw S3Error.httpError(response.statusCode, String(data: body, encoding: .utf8) ?? "")
        }
    }

    func getObject(key: String) async throws -> Data {
        var request = URLRequest(url: objectURL(key: key))
        request.httpMethod = "GET"
        signer.sign(request: &request, payload: Data())
        let (body, response) = try await send(request)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw S3Error.httpError(response.statusCode, String(data: body, encoding: .utf8) ?? "")
        }
        return body
    }

    func headBucket() async throws {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "HEAD"
        signer.sign(request: &request, payload: Data())
        let (_, response) = try await send(request)
        guard (200 ..< 300).contains(response.statusCode) else { throw S3Error.httpError(response.statusCode, "") }
    }

    func deleteObject(key: String) async throws {
        var request = URLRequest(url: objectURL(key: key))
        request.httpMethod = "DELETE"
        signer.sign(request: &request, payload: Data())
        let (_, response) = try await send(request)
        guard (200 ..< 300).contains(response.statusCode) || response.statusCode == 404 else {
            throw S3Error.httpError(response.statusCode, "")
        }
    }

    func listObjects(prefix: String) async throws -> [S3ObjectSummary] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "list-type", value: "2"), URLQueryItem(name: "prefix", value: prefix)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        signer.sign(request: &request, payload: Data())
        let (body, response) = try await send(request)
        guard (200 ..< 300).contains(response.statusCode) else { throw S3Error.httpError(response.statusCode, "") }
        return S3ListObjectsParser.parse(body)
    }

    /// Deliberately unsigned — used to check whether the bucket allows
    /// anonymous access at all. See docs/DESIGN.md's S3 validation checklist.
    func unauthenticatedGet(key: String) async -> Int? {
        var request = URLRequest(url: objectURL(key: key))
        request.httpMethod = "GET"
        guard let (_, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
            return nil
        }
        return http.statusCode
    }
}

private final class S3ListObjectsParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentKey = ""
    private var currentSize = ""
    private var currentModified = ""
    private var results: [S3ObjectSummary] = []

    static func parse(_ data: Data) -> [S3ObjectSummary] {
        let delegate = S3ListObjectsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.results
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "Contents" {
            currentKey = ""
            currentSize = ""
            currentModified = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "Key": currentKey += string
        case "Size": currentSize += string
        case "LastModified": currentModified += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Contents" {
            results.append(S3ObjectSummary(key: currentKey, sizeBytes: Int(currentSize) ?? 0, lastModified: currentModified))
        }
    }
}
