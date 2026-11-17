import Foundation
import Security

/// 处理 mTLS 连接的两个 TLS 质询：
///  - 服务器要求客户端证书时，出示该连接导入的 identity；
///  - 服务端证书校验时，用 magpie 签发的 CA 作为锚点，并保留主机名校验。
///
/// 没有配置客户端证书的连接不使用此 delegate，行为与以前完全一致。
final class MagpieTLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let material: ClientTLSMaterial

    init(material: ClientTLSMaterial) {
        self.material = material
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            let credential = URLCredential(
                identity: material.identity,
                certificates: [material.clientCertificate],
                persistence: .forSession
            )
            completionHandler(.useCredential, credential)

        case NSURLAuthenticationMethodServerTrust:
            guard let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            // 信任锚点加入该连接导入的 CA，同时保留系统根证书：既能直连
            // magpie 自签 CA 的 mTLS，也兼容公共 CA 的反代。质询自带的
            // SSL 策略仍会校验主机名。
            SecTrustSetAnchorCertificates(trust, material.caCertificates as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, false)
            var error: CFError?
            if SecTrustEvaluateWithError(trust, &error) {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }

        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
