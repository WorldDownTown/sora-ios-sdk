import Foundation
import WebRTC

class WrapperVideoEncoderFactory: NSObject, RTCVideoEncoderFactory {
    static var shared = WrapperVideoEncoderFactory()

    var defaultEncoderFactory: RTCDefaultVideoEncoderFactory

    var simulcastEncoderFactory: RTCVideoEncoderFactorySimulcast

    var currentEncoderFactory: RTCVideoEncoderFactory {
        simulcastEnabled ? simulcastEncoderFactory : defaultEncoderFactory
    }

    var simulcastEnabled = false

    override init() {
        // Sora iOS SDK では VP8, VP9, H.264 が有効
        defaultEncoderFactory = RTCDefaultVideoEncoderFactory()
        simulcastEncoderFactory = RTCVideoEncoderFactorySimulcast(primary: defaultEncoderFactory, fallback: defaultEncoderFactory)
    }

    func createEncoder(_ info: RTCVideoCodecInfo) -> RTCVideoEncoder? {
        currentEncoderFactory.createEncoder(info)
    }

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        currentEncoderFactory.supportedCodecs()
    }
}

// 参照: https://developer.apple.com/documentation/security/1401555-sectrustcreatewithcertificates
// The certificate to be verified, plus any other certificates you think might be useful for verifying the certificate.
// The certificate to be verified must be the first in the array.
class CustomSSLCertificateVerifier: NSObject, RTCSSLCertificateVerifier {
    func verify(_ derCertificate: Data) -> Bool {
        guard let cert = SecCertificateCreateWithData(kCFAllocatorDefault, derCertificate as CFData) else {
            Logger.error(type: .peerChannel, message: "\(#function): SecCertificateCreateWithData failed."
                + "certificate.base64EncodedString() => \(derCertificate.base64EncodedString())")
            return false
        }

        Logger.info(type: .peerChannel, message: "\(#function): cert=\(cert)")

        var trust: SecTrust?
        // NOTE: 設定しているポリシーが適切かは要確認
        let status = SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust)
        guard status == errSecSuccess else {
            Logger.error(type: .peerChannel, message: "\(#function): SecTrustCreateWithCertificates failed. status => \(status.description)")
            return false
        }

        var error: CFError?
        let result = SecTrustEvaluateWithError(trust!, &error)
        if let error = error {
            Logger.error(type: .peerChannel, message: "\(#function): SecTrustEvaluateWithError failed. error => \(error.localizedDescription)")
            return false
        }

        Logger.info(type: .peerChannel, message: "\(#function): result => \(result.description)")
        return result
    }
}

class NativePeerChannelFactory {
    static var `default` = NativePeerChannelFactory()

    var nativeFactory: RTCPeerConnectionFactory

    init() {
        Logger.debug(type: .peerChannel, message: "create native peer channel factory")

        // 映像コーデックのエンコーダーとデコーダーを用意する
        let encoder = WrapperVideoEncoderFactory.shared
        let decoder = RTCDefaultVideoDecoderFactory()
        nativeFactory =
            RTCPeerConnectionFactory(encoderFactory: encoder,
                                     decoderFactory: decoder)

        for info in encoder.supportedCodecs() {
            Logger.debug(type: .peerChannel,
                         message: "supported video encoder: \(info.name) \(info.parameters)")
        }
        for info in decoder.supportedCodecs() {
            Logger.debug(type: .peerChannel,
                         message: "supported video decoder: \(info.name) \(info.parameters)")
        }
    }

    func createNativePeerChannel(configuration: WebRTCConfiguration,
                                 constraints: MediaConstraints,
                                 delegate: RTCPeerConnectionDelegate?) -> RTCPeerConnection?
    {
        let verifier = CustomSSLCertificateVerifier()
        return nativeFactory
            .peerConnection(with: configuration.nativeValue,
                            constraints: constraints.nativeValue,
                            certificateVerifier: verifier,
                            delegate: delegate)
    }

    func createNativeStream(streamId: String) -> RTCMediaStream {
        nativeFactory.mediaStream(withStreamId: streamId)
    }

    func createNativeVideoSource() -> RTCVideoSource {
        nativeFactory.videoSource()
    }

    func createNativeVideoTrack(videoSource: RTCVideoSource,
                                trackId: String) -> RTCVideoTrack
    {
        nativeFactory.videoTrack(with: videoSource, trackId: trackId)
    }

    func createNativeAudioSource(constraints: MediaConstraints?) -> RTCAudioSource {
        nativeFactory.audioSource(with: constraints?.nativeValue)
    }

    func createNativeAudioTrack(trackId: String,
                                constraints: RTCMediaConstraints) -> RTCAudioTrack
    {
        let audioSource = nativeFactory.audioSource(with: constraints)
        return nativeFactory.audioTrack(with: audioSource, trackId: trackId)
    }

    func createNativeSenderStream(streamId: String,
                                  videoTrackId: String?,
                                  audioTrackId: String?,
                                  constraints: MediaConstraints) -> RTCMediaStream
    {
        Logger.debug(type: .nativePeerChannel,
                     message: "create native sender stream (\(streamId))")
        let nativeStream = createNativeStream(streamId: streamId)

        if let trackId = videoTrackId {
            Logger.debug(type: .nativePeerChannel,
                         message: "create native video track (\(trackId))")
            let videoSource = createNativeVideoSource()
            let videoTrack = createNativeVideoTrack(videoSource: videoSource,
                                                    trackId: trackId)
            nativeStream.addVideoTrack(videoTrack)
        }

        if let trackId = audioTrackId {
            Logger.debug(type: .nativePeerChannel,
                         message: "create native audio track (\(trackId))")
            let audioTrack = createNativeAudioTrack(trackId: trackId,
                                                    constraints: constraints.nativeValue)
            nativeStream.addAudioTrack(audioTrack)
        }

        return nativeStream
    }

    // クライアント情報としての Offer SDP を生成する
    func createClientOfferSDP(configuration: WebRTCConfiguration,
                              constraints: MediaConstraints,
                              handler: @escaping (String?, Error?) -> Void)
    {
        let peer = createNativePeerChannel(configuration: configuration, constraints: constraints, delegate: nil)

        // `guard let peer = peer {` と書いた場合、 Xcode 12.5 でビルド・エラーになった
        guard let peer2 = peer else {
            handler(nil, SoraError.peerChannelError(reason: "createNativePeerChannel failed"))
            return
        }

        let stream = createNativeSenderStream(streamId: "offer",
                                              videoTrackId: "video",
                                              audioTrackId: "audio",
                                              constraints: constraints)
        peer2.add(stream.videoTracks[0], streamIds: [stream.streamId])
        peer2.add(stream.audioTracks[0], streamIds: [stream.streamId])
        peer2.offer(for: constraints.nativeValue) { sdp, error in
            if let error = error {
                handler(nil, error)
            } else if let sdp = sdp {
                handler(sdp.sdp, nil)
            }
            peer2.close()
        }
    }
}
