import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api.dart';

enum PeerPresence { online, away, offline }

enum P2PConnectionState { connecting, connected, disconnected, failed }

/// Peer-to-peer WebRTC chat engine for matches.
/// All chat messages, read receipts, and presence updates travel strictly
/// over the WebRTC RTCDataChannel without passing message content through any server.
/// IP addresses are never displayed to the user; only peer display names are presented.
class P2PChatService with WidgetsBindingObserver {
  P2PChatService({
    required this.api,
    required this.matchId,
    required this.myUserId,
    required this.myName,
    required this.peerUserId,
    required this.peerName,
  }) : isInitiator = myUserId.compareTo(peerUserId) < 0 {
    WidgetsBinding.instance.addObserver(this);
    connectionStateNotifier = ValueNotifier(P2PConnectionState.connecting);
    peerPresenceNotifier = ValueNotifier(PeerPresence.offline);
  }

  final Api api;
  final String matchId;
  final String myUserId;
  final String myName;
  final String peerUserId;
  final String peerName;
  final bool isInitiator;

  late final ValueNotifier<P2PConnectionState> connectionStateNotifier;
  late final ValueNotifier<PeerPresence> peerPresenceNotifier;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  final _seenController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onSeen => _seenController.stream;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  Timer? _signalingTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeat;
  bool _disposed = false;
  PeerPresence _myPresence = PeerPresence.online;
  final Set<String> _processedSignalIds = {};

  P2PConnectionState get connectionState => connectionStateNotifier.value;
  PeerPresence get peerPresence => peerPresenceNotifier.value;

  Future<void> start() async {
    if (_disposed) return;
    await _initPeerConnection();
    _startSignalingLoop();
    _startHeartbeatLoop();
  }

  Future<void> _initPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null || _disposed) return;
      _sendSignal('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      if (_disposed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          connectionStateNotifier.value = P2PConnectionState.connected;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          connectionStateNotifier.value = P2PConnectionState.disconnected;
          peerPresenceNotifier.value = PeerPresence.offline;
          _startSignalingLoop();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          connectionStateNotifier.value = P2PConnectionState.failed;
          peerPresenceNotifier.value = PeerPresence.offline;
          _startSignalingLoop();
          break;
        default:
          break;
      }
    };

    if (isInitiator) {
      final init = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel(
        'tevi_p2p_chat',
        init,
      );
      _setupDataChannel(_dataChannel!);

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(offer);
      await _sendSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
    } else {
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        _dataChannel = channel;
        _setupDataChannel(_dataChannel!);
      };
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (_disposed) return;
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        connectionStateNotifier.value = P2PConnectionState.connected;
        _lastHeartbeat = DateTime.now();
        peerPresenceNotifier.value = PeerPresence.online;
        _signalingTimer?.cancel(); // Pause signaling while data channel is active
        _sendPresence(_myPresence);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        connectionStateNotifier.value = P2PConnectionState.disconnected;
        peerPresenceNotifier.value = PeerPresence.offline;
        _startSignalingLoop(); // Resume signaling if disconnected
      }
    };

    channel.onMessage = (RTCDataChannelMessage data) {
      if (_disposed || data.text.isEmpty) return;
      try {
        final text = data.text;
        final json = jsonDecode(text) as Map<String, dynamic>;
        _handleP2PPacket(json);
      } catch (_) {}
    };
  }

  void _handleP2PPacket(Map<String, dynamic> packet) {
    final type = packet['type'] as String?;
    _lastHeartbeat = DateTime.now();

    switch (type) {
      case 'message':
        final msg = Map<String, dynamic>.from(packet['message'] as Map);
        _messageController.add(msg);
        break;
      case 'seen':
        _seenController.add({
          'messageId': packet['messageId'],
          'seenAt': packet['seenAt'],
        });
        break;
      case 'seen_batch':
        final ids = (packet['messageIds'] as List?)?.cast<String>() ?? [];
        for (final id in ids) {
          _seenController.add({
            'messageId': id,
            'seenAt': packet['seenAt'],
          });
        }
        break;
      case 'presence':
        final status = packet['status'] as String?;
        if (status == 'away') {
          peerPresenceNotifier.value = PeerPresence.away;
        } else if (status == 'online') {
          peerPresenceNotifier.value = PeerPresence.online;
        } else {
          peerPresenceNotifier.value = PeerPresence.offline;
        }
        break;
      case 'ping':
        final remoteStatus = packet['status'] as String?;
        if (remoteStatus == 'away') {
          peerPresenceNotifier.value = PeerPresence.away;
        } else {
          peerPresenceNotifier.value = PeerPresence.online;
        }
        _sendRaw({'type': 'pong', 'status': _myPresence.name});
        break;
      case 'pong':
        final remoteStatus = packet['status'] as String?;
        if (remoteStatus == 'away') {
          peerPresenceNotifier.value = PeerPresence.away;
        } else {
          peerPresenceNotifier.value = PeerPresence.online;
        }
        break;
    }
  }

  bool _sendRaw(Map<String, dynamic> data) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode(data)));
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Send message strictly P2P through WebRTC RTCDataChannel.
  bool sendMessage(Map<String, dynamic> message) {
    return _sendRaw({'type': 'message', 'message': message});
  }

  /// Send read receipt strictly P2P through WebRTC RTCDataChannel.
  void sendSeen(String messageId) {
    _sendRaw({
      'type': 'seen',
      'messageId': messageId,
      'seenAt': DateTime.now().millisecondsSinceEpoch / 1000,
    });
  }

  /// Send batch read receipts strictly P2P through WebRTC RTCDataChannel.
  void sendSeenBatch(List<String> messageIds) {
    if (messageIds.isEmpty) return;
    _sendRaw({
      'type': 'seen_batch',
      'messageIds': messageIds,
      'seenAt': DateTime.now().millisecondsSinceEpoch / 1000,
    });
  }

  void _sendPresence(PeerPresence presence) {
    _sendRaw({
      'type': 'presence',
      'status': presence.name,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
    });
  }

  /// Update local user presence (online or away).
  void setMyPresence(PeerPresence presence) {
    if (_myPresence == presence) return;
    _myPresence = presence;
    _sendPresence(presence);
  }

  void _startHeartbeatLoop([
    Duration interval = const Duration(seconds: 6),
    Duration timeout = const Duration(seconds: 18),
  ]) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (_disposed) return;
      if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
        _sendRaw({'type': 'ping', 'status': _myPresence.name});
        if (_lastHeartbeat != null &&
            DateTime.now().difference(_lastHeartbeat!) > timeout) {
          if (peerPresenceNotifier.value != PeerPresence.offline) {
            peerPresenceNotifier.value = PeerPresence.offline;
          }
        }
      }
    });
  }

  Future<void> _sendSignal(String type, Map<String, dynamic> payload) async {
    try {
      await api.request('POST', '/matches/$matchId/signal', {
        'type': type,
        'payload': payload,
      });
    } catch (_) {}
  }

  bool _fetchingSignals = false;

  void _startSignalingLoop() {
    _signalingTimer?.cancel();
    _signalingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_disposed ||
          (connectionState == P2PConnectionState.connected &&
              _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) ||
          _fetchingSignals) {
        return;
      }
      _fetchingSignals = true;
      try {
        final signals = await api.request('GET', '/matches/$matchId/signal');
        if (signals is List && signals.isNotEmpty) {
          if (_processedSignalIds.length > 500) {
            _processedSignalIds.removeAll(_processedSignalIds.take(250).toList());
          }
          for (final s in signals) {
            final id = s['id'] as String?;
            if (id != null && _processedSignalIds.contains(id)) continue;
            if (id != null) _processedSignalIds.add(id);

            final type = s['type'] as String?;
            final rawPayload = s['payload'];
            final payload = rawPayload is Map
                ? Map<String, dynamic>.from(rawPayload)
                : jsonDecode(rawPayload as String) as Map<String, dynamic>;

            await _handleSignal(type, payload);
          }
        }
      } catch (_) {
      } finally {
        _fetchingSignals = false;
      }
    });
  }

  Future<void> _handleSignal(
    String? type,
    Map<String, dynamic> payload,
  ) async {
    if (_peerConnection == null || _disposed) return;
    try {
      if (type == 'offer' && !isInitiator) {
        final sdp = payload['sdp'] as String;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );
        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': false,
          'offerToReceiveVideo': false,
        });
        await _peerConnection!.setLocalDescription(answer);
        await _sendSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
      } else if (type == 'answer' && isInitiator) {
        final sdp = payload['sdp'] as String;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
      } else if (type == 'candidate') {
        final candidate = RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        );
        await _peerConnection!.addCandidate(candidate);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    // Always keep connection alive in background whenever possible!
    if (state == AppLifecycleState.resumed) {
      setMyPresence(PeerPresence.online);
      _startHeartbeatLoop(const Duration(seconds: 6), const Duration(seconds: 18));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      setMyPresence(PeerPresence.away);
      _startHeartbeatLoop(const Duration(seconds: 15), const Duration(seconds: 45));
    }
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _signalingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _dataChannel?.close();
    _peerConnection?.close();
    _messageController.close();
    _seenController.close();
    connectionStateNotifier.dispose();
    peerPresenceNotifier.dispose();
  }
}
