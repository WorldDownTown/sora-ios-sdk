import Foundation
import WebRTC

// MARK: デフォルト値

private let defaultPublisherStreamId: String = "mainStream"
private let defaultPublisherVideoTrackId: String = "mainVideo"
private let defaultPublisherAudioTrackId: String = "mainAudio"

/**
 プロキシに関する設定です
 */
public struct Proxy: CustomStringConvertible {
    /// プロキシのホスト
    let host: String

    /// ポート
    let port: Int

    /// username
    /// プロキシに認証がかかっている場合に指定する
    let username: String?

    /// password
    /// プロキシに認証がかかっている場合に指定する
    let password: String?

    /// エージェント
    var agent: String = "Sora iOS SDK \(SDKInfo.version)"

    /**
     初期化します。
     - parameter host: プロキシのホスト名
     - parameter port: プロキシのポート
     - parameter agent: プロキシのエージェント
     - parameter username: プロキシ認証に使用するユーザー名
     - parameter password: プロキシ認証に使用するパスワード
     */
    public init(host: String, port: Int, agent: String? = nil, username: String? = nil, password: String? = nil) {
        self.host = host
        self.port = port

        self.username = username
        self.password = password

        if let agent {
            self.agent = agent
        }
    }

    /// 文字列表現を返します。
    public var description: String {
        "host=\(host) port=\(port) agent=\(agent) username=\(username ?? "") password=\(String(repeating: "*", count: password?.count ?? 0))"
    }
}

/**
 クライアントに関する設定です。
 */
public struct Configuration {
    // MARK: - 接続に関する設定

    /**
     スポットライトの設定
     */
    public enum Spotlight {
        /// 有効
        case enabled

        /// 無効
        case disabled
    }

    /// サーバーの URL
    @available(*, unavailable, message: "url は廃止されました。 urlCandidates を利用してください。")
    public var url: Any?

    /// シグナリングに利用する URL の候補
    public var urlCandidates: [URL]

    /// チャネル ID
    public var channelId: String

    /// クライアント ID
    public var clientId: String?

    /// バンドル ID
    public var bundleId: String?
    /// ロール
    public var role: Role

    /// マルチストリームの可否
    public var multistreamEnabled: Bool

    /// :nodoc:
    var isMultistream: Bool {
        switch role {
        case .group, .groupSub:
            return true
        default:
            return multistreamEnabled
        }
    }

    /// :nodoc:
    var isSender: Bool {
        switch role {
        case .publisher, .group, .sendonly, .sendrecv:
            return true
        default:
            return false
        }
    }

    /**
     接続試行中のタイムアウト (秒) 。
     指定した時間内に接続が成立しなければ接続試行を中止します。
     */
    public var connectionTimeout: Int = 30

    /// 映像コーデック。デフォルトは `.default` です。
    public var videoCodec: VideoCodec = .default

    /// 映像ビットレート。デフォルトは無指定です。
    public var videoBitRate: Int?

    /// 映像キャプチャーの種別。
    /// 廃止されました。
    @available(*, unavailable, message: "videoCapturerDevice は廃止されました。")
    public var videoCapturerDevice: VideoCapturerDevice?

    /// カメラの設定
    public var cameraSettings = CameraSettings.default

    /// 音声コーデック。デフォルトは `.default` です。
    public var audioCodec: AudioCodec = .default

    /// 音声ビットレート。デフォルトは無指定です。
    public var audioBitRate: Int?

    /// 映像の可否。 `true` であれば映像を送受信します。
    /// デフォルトは `true` です。
    public var videoEnabled: Bool = true

    /// 音声の可否。 `true` であれば音声を送受信します。
    /// デフォルトは `true` です。
    public var audioEnabled: Bool = true

    /// サイマルキャストの可否。 `true` であればサイマルキャストを有効にします。
    public var simulcastEnabled: Bool = false

    /// サイマルキャストでの映像の種類。
    /// ロールが `.sendrecv` または `.recvonly` のときのみ有効です。
    public var simulcastRid: SimulcastRid?

    /// スポットライトの可否
    /// 詳しくは Sora のスポットライト機能を参照してください。
    public var spotlightEnabled: Spotlight = .disabled

    /// スポットライトの対象人数
    @available(*, deprecated, renamed: "spotlightNumber",
               message: "このプロパティは spotlightNumber に置き換えられました。")
    public var spotlight: Int? {
        get {
            spotlightNumber
        }
        set {
            spotlightNumber = newValue
        }
    }

    /// スポットライトの対象人数
    @available(*, deprecated, renamed: "spotlightNumber",
               message: "このプロパティは spotlightNumber に置き換えられました。")
    public var activeSpeakerLimit: Int? {
        get {
            spotlightNumber
        }
        set {
            spotlightNumber = newValue
        }
    }

    /// スポットライトの対象人数
    public var spotlightNumber: Int?

    /// スポットライト機能でフォーカスした場合の映像の種類
    public var spotlightFocusRid: SpotlightRid = .unspecified

    /// スポットライト機能でフォーカスしていない場合の映像の種類
    public var spotlightUnfocusRid: SpotlightRid = .unspecified

    /// WebRTC に関する設定
    public var webRTCConfiguration = WebRTCConfiguration()

    /// `connect` シグナリングに含めるメタデータ
    public var signalingConnectMetadata: Encodable?

    /// `connect` シグナリングに含める通知用のメタデータ
    public var signalingConnectNotifyMetadata: Encodable?

    /// シグナリングにおける DataChannel の利用可否。
    /// `true` の場合、接続確立後のシグナリングを DataChannel 経由で行います。
    public var dataChannelSignaling: Bool?

    /// メッセージング機能で利用する DataChannel の設定
    public var dataChannels: Any?

    /// DataChannel 経由のシグナリングを利用している際に、 WebSocket が切断されても Sora との接続を継続するためのフラグ。
    /// 詳細: https://sora-doc.shiguredo.jp/DATA_CHANNEL_SIGNALING#07c227
    public var ignoreDisconnectWebSocket: Bool?

    /// 音声ストリーミング機能で利用する言語コード
    public var audioStreamingLanguageCode: String?

    /// プロキシに関する設定
    public var proxy: Proxy?

    /// 転送フィルターの設定
    public var forwardingFilter: ForwardingFilter?

    // MARK: - イベントハンドラ

    /// WebSocket チャネルに関するイベントハンドラ
    public var webSocketChannelHandlers = WebSocketChannelHandlers()

    /// シグナリングチャネルに関するイベントハンドラ
    @available(*, unavailable, message: "廃止されました。 mediaChannelHandlers を利用してください。")
    public var signalingChannelHandlers = SignalingChannelHandlers()

    /// ピアチャネルに関するイベントハンドラ
    @available(*, unavailable, message: "廃止されました。 mediaChannelHandlers を利用してください。")
    public var peerChannelHandlers = PeerChannelHandlers()

    /// メディアチャネルに関するイベントハンドラ
    public var mediaChannelHandlers = MediaChannelHandlers()

    // MARK: - 接続チャネルに関する設定

    /**
     生成されるシグナリングチャネルの型。
     何も指定しなければデフォルトのシグナリングチャネルが生成されます。
     */
    @available(*, unavailable, message: "signalingChannelType は廃止されました。")
    public var signalingChannelType: Any?

    /**
     生成される WebSocket チャネルの型。
     何も指定しなければデフォルトの WebSocket チャネルが生成されます。
     */
    @available(*, unavailable, message: "webSocketChannelType は廃止されました。")
    public var webSocketChannelType: WebSocketChannel.Type?

    /**
     生成されるピアチャネルの型。
     何も指定しなければデフォルトのピアチャネルが生成されます。
     */
    @available(*, unavailable, message: "peerChannelType は廃止されました。")
    public var peerChannelType: Any?

    /// :nodoc:
    @available(*, unavailable, message: "allowsURLSessionWebSocketChannel は廃止されました。")
    public var allowsURLSessionWebSocketChannel: Bool = true

    // MARK: パブリッシャーに関する設定

    /// パブリッシャーのストリームの ID です。
    /// 通常、指定する必要はありません。
    public var publisherStreamId: String = defaultPublisherStreamId

    /// パブリッシャーの映像トラックの ID です。
    /// 通常、指定する必要はありません。
    public var publisherVideoTrackId: String = defaultPublisherVideoTrackId

    /// パブリッシャーの音声トラックの ID です。
    /// 通常、指定する必要はありません。
    public var publisherAudioTrackId: String = defaultPublisherAudioTrackId

    // MARK: - インスタンスの生成

    /**
     このイニシャライザーは ``init(url:channelId:role:multistreamEnabled:)`` に置き換えられました。
     以降はマルチストリームの可否を明示的に指定してください。
     このイニシャライザーはマルチストリームを無効にして初期化します。

     - parameter url: サーバーの URL
     - parameter channelId: チャネル ID
     - parameter role: ロール
     */
    ///
    @available(*, deprecated, renamed: "init(url:channelId:role:multistreamEnabled:)",
               message: "このイニシャライザーは init(url:channelId:role:multistreamEnabled:) に置き換えられました。")
    public init(url: URL,
                channelId: String,
                role: Role)
    {
        urlCandidates = [url]
        self.channelId = channelId
        self.role = role
        multistreamEnabled = false
    }

    /**
     初期化します。

     - parameter url: サーバーの URL
     - parameter channelId: チャネル ID
     - parameter role: ロール
     - parameter multistreamEnabled: マルチストリームの可否
     */
    public init(url: URL,
                channelId: String,
                role: Role,
                multistreamEnabled: Bool)
    {
        urlCandidates = [url]
        self.channelId = channelId
        self.role = role
        self.multistreamEnabled = multistreamEnabled
    }

    /**
     初期化します。
     - parameter urlCandidates: シグナリングに利用する URL の候補
     - parameter channelId: チャネル ID
     - parameter role: ロール
     - parameter multistreamEnabled: マルチストリームの可否
     */
    public init(urlCandidates: [URL],
                channelId: String,
                role: Role,
                multistreamEnabled: Bool)
    {
        self.urlCandidates = urlCandidates
        self.channelId = channelId
        self.role = role
        self.multistreamEnabled = multistreamEnabled
    }
}

/**
 転送フィルターのルールのフィールドの設定です。
 */
public enum ForwardingFilterRuleField: String, Codable {
    /// connection_id
    case connectionId = "connection_id"

    /// client_id
    case clientId = "client_id"

    /// kind
    case kind
}

/**
 転送フィルターのルールの演算子の設定です。
 */
public enum ForwardingFilterRuleOperator: String, Codable {
    /// is_in
    case isIn = "is_in"

    /// is_not_in
    case isNotIn = "is_not_in"
}

/**
 転送フィルターのルールの設定です。
 */
public struct ForwardingFilterRule: Codable {
    /// field
    public let field: ForwardingFilterRuleField

    /// operator
    public let `operator`: ForwardingFilterRuleOperator

    /// values
    public let values: [String]

    /**
     初期化します。

     - parameter field: field
     - parameter operator: operator
     - parameter values: values
     */
    public init(field: ForwardingFilterRuleField,
                operator: ForwardingFilterRuleOperator,
                values: [String])
    {
        self.field = field
        self.operator = `operator`
        self.values = values
    }
}

/**
 転送フィルターのアクションの設定です。
 */
public enum ForwardingFilterAction: String, Codable {
    /// block
    case block

    /// allow
    case allow
}

/**
 転送フィルターに関する設定です。
 */
public struct ForwardingFilter: Codable {
    /// action
    public let action: ForwardingFilterAction

    /// rules
    public let rules: [[ForwardingFilterRule]]

    /**
     初期化します。

     - parameter action: action
     - parameter rules: rules
     */
    public init(action: ForwardingFilterAction, rules: [[ForwardingFilterRule]]) {
        self.action = action
        self.rules = rules
    }
}
