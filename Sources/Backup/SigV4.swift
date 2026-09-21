import CryptoKit
import Foundation

/// AWS SigV4 request signing over `CryptoKit`'s `HMAC<SHA256>`/`SHA256` —
/// no HMAC package needed, per AGENTS.md. Signs one request at a time for
/// S3's REST API (PUT/GET/HEAD/DELETE object), which is all this app calls.
struct SigV4 {
    let accessKeyID: String
    let secretAccessKey: String
    let region: String
    let service = "s3"

    func sign(request: inout URLRequest, payload: Data, date: Date = Date()) {
        guard let url = request.url, let host = url.host else { return }
        let (dateStamp, amzDate) = Self.timestamps(for: date)
        let payloadHash = Self.sha256Hex(payload)

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        let method = request.httpMethod ?? "GET"
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        let canonicalQuery = Self.canonicalQueryString(url: url)

        let headersToSign: [String: String] = ["host": host, "x-amz-content-sha256": payloadHash, "x-amz-date": amzDate]
        let sortedHeaderNames = headersToSign.keys.sorted()
        let canonicalHeaders = sortedHeaderNames.map { "\($0):\(headersToSign[$0]!)\n" }.joined()
        let signedHeaders = sortedHeaderNames.joined(separator: ";")

        let canonicalRequest = [method, canonicalURI, canonicalQuery, canonicalHeaders, signedHeaders, payloadHash].joined(separator: "\n")

        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = ["AWS4-HMAC-SHA256", amzDate, scope, Self.sha256Hex(Data(canonicalRequest.utf8))].joined(separator: "\n")

        let signingKey = Self.signingKey(secret: secretAccessKey, dateStamp: dateStamp, region: region, service: service)
        let signature = Self.hmacHex(key: signingKey, message: Data(stringToSign.utf8))

        request.setValue(
            "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)",
            forHTTPHeaderField: "Authorization"
        )
    }

    private static func timestamps(for date: Date) -> (dateStamp: String, amzDate: String) {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = formatter.string(from: date)
        return (String(amzDate.prefix(8)), amzDate)
    }

    private static func canonicalQueryString(url: URL) -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, !items.isEmpty else { return "" }
        return items.sorted { $0.name < $1.name }
            .map { "\(uriEncode($0.name))=\(uriEncode($0.value ?? ""))" }
            .joined(separator: "&")
    }

    private static func uriEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func hmac(key: Data, message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key)))
    }

    private static func hmacHex(key: Data, message: Data) -> String {
        hmac(key: key, message: message).map { String(format: "%02x", $0) }.joined()
    }

    private static func signingKey(secret: String, dateStamp: String, region: String, service: String) -> Data {
        let kDate = hmac(key: Data("AWS4\(secret)".utf8), message: Data(dateStamp.utf8))
        let kRegion = hmac(key: kDate, message: Data(region.utf8))
        let kService = hmac(key: kRegion, message: Data(service.utf8))
        return hmac(key: kService, message: Data("aws4_request".utf8))
    }
}
