import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/services/call_signaling_service.dart';
import 'package:mobile_app/services/call_state.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.conversationId,
    required this.callLogId,
    required this.callType,
    required this.title,
    required this.isCaller,
  });

  final int conversationId;
  final int callLogId;
  final String callType;
  final String title;
  final bool isCaller;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  late CallSignalingService _signaling;

  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _connected = false;
  bool _offerSent = false;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    CallState.instance.startActive(
      ActiveCallData(
        conversationId: widget.conversationId,
        callLogId: widget.callLogId,
        callType: widget.callType,
        isCaller: widget.isCaller,
        title: widget.title,
      ),
    );
    _init();
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    _signaling.dispose();
    super.dispose();
  }

  Future<void> _updateCallStatus(String statusValue) async {
    await http.post(
      Uri.parse(
        '${AppApi.chat}/${widget.conversationId}/call-logs/${widget.callLogId}/status/',
      ),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'status': statusValue}),
    );
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling = CallSignalingService(widget.conversationId);
    _signaling.connect(_handleSignal);

    debugPrint('call init: ${widget.callType}, isCaller=${widget.isCaller}');

    final mediaConstraints = {
      'audio': true,
      'video': widget.callType == 'video',
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    debugPrint('local stream ready: ${_localStream?.getTracks().length}');

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(configuration);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('onTrack fired, streams=${event.streams.length}');
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() => _connected = true);
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('send candidate');
      _signaling.send({'type': 'candidate', 'candidate': candidate.toMap()});
    };

    if (widget.isCaller) {
      _ringTimer = Timer(const Duration(seconds: 30), () async {
        if (!_connected && mounted) {
          await _updateCallStatus('missed');
          CallState.instance.endActive();
          Navigator.pop(context);
        }
      });
    } else {
      // 🔥 BÊN NHẬN báo đã sẵn sàng
      _signaling.send({'type': 'ready'});
      debugPrint('callee sent ready');
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null || _offerSent) return;
    _offerSent = true;

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _signaling.send({'type': 'offer', 'sdp': offer.sdp, 'sdpType': offer.type});

    debugPrint('caller sent offer');
  }

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    debugPrint('signal type = $type');

    if (type == 'ready' && widget.isCaller) {
      // 🔥 Chỉ khi bên nhận sẵn sàng thì caller mới gửi offer
      await _createAndSendOffer();
    } else if (type == 'offer' && !widget.isCaller) {
      final offer = RTCSessionDescription(
        data['sdp'] as String,
        data['sdpType'] as String,
      );
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _signaling.send({
        'type': 'answer',
        'sdp': answer.sdp,
        'sdpType': answer.type,
      });

      debugPrint('callee sent answer');
    } else if (type == 'answer' && widget.isCaller) {
      final answer = RTCSessionDescription(
        data['sdp'] as String,
        data['sdpType'] as String,
      );
      await _peerConnection!.setRemoteDescription(answer);
      if (mounted) setState(() => _connected = true);
      debugPrint('caller received answer');
    } else if (type == 'candidate') {
      final c = data['candidate'] as Map<String, dynamic>;
      await _peerConnection!.addCandidate(
        RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
      );
    } else if (type == 'hangup') {
      if (mounted) {
        CallState.instance.endActive();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _hangup() async {
    _signaling.send({'type': 'hangup'});
    await _updateCallStatus('ended');
    if (!mounted) return;
    CallState.instance.endActive();
    Navigator.pop(context);
  }

  void _toggleMic() {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_micEnabled;
    }
    setState(() => _micEnabled = !_micEnabled);
  }

  void _toggleCamera() {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !_cameraEnabled;
    }
    setState(() => _cameraEnabled = !_cameraEnabled);
  }

  void _minimize() {
    CallState.instance.setMinimized(true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: isVideo
                ? RTCVideoView(_remoteRenderer)
                : const Center(
                    child: Icon(Icons.call, color: Colors.white54, size: 96),
                  ),
          ),
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: _minimize,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _connected ? 'Đang kết nối' : 'Đang đổ chuông...',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          if (isVideo)
            Positioned(
              right: 16,
              top: 120,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: _micEnabled ? Colors.white24 : Colors.orange,
                  onPressed: _toggleMic,
                  child: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                ),
                if (isVideo)
                  FloatingActionButton(
                    backgroundColor: _cameraEnabled
                        ? Colors.white24
                        : Colors.orange,
                    onPressed: _toggleCamera,
                    child: Icon(
                      _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    ),
                  ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: _hangup,
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
