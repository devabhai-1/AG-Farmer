import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('agFarmerRealtimeConnect')
external JSPromise<JSAny?> _jsConnect(JSString secret, JSString callsUrl);

@JS('agFarmerRealtimeDisconnect')
external void _jsDisconnect();

@JS('agFarmerRealtimeInterrupt')
external void _jsInterrupt();

@JS('agFarmerRealtimeReady')
external JSBoolean? get _jsReady;

class VoiceLiveWebrtcImpl {
  static bool get isSupported => true;
  static bool _scriptInjected = false;

  static void _ensureScript() {
    if (_scriptInjected) return;
    _scriptInjected = true;
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..text = r'''
(function(){
  if (window.agFarmerRealtimeReady) return;
  let pc = null;
  let local = null;
  let audioEl = null;

  let dc = null;

  window.agFarmerRealtimeDisconnect = function(){
    try { if (local) local.getTracks().forEach(t => t.stop()); } catch(e){}
    local = null;
    try { if (dc) dc.close(); } catch(e){}
    dc = null;
    try { if (pc) pc.close(); } catch(e){}
    pc = null;
    try {
      if (audioEl) {
        audioEl.srcObject = null;
        audioEl.remove();
      }
    } catch(e){}
    audioEl = null;
  };

  window.agFarmerRealtimeInterrupt = function(){
    try {
      if (audioEl) audioEl.muted = true;
      if (dc && dc.readyState === 'open') {
        dc.send(JSON.stringify({ type: 'response.cancel' }));
      }
    } catch(e){}
  };

  window.agFarmerRealtimeConnect = async function(secret, callsUrl){
    window.agFarmerRealtimeDisconnect();
    local = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    pc = new RTCPeerConnection({ iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] });
    audioEl = document.createElement('audio');
    audioEl.autoplay = true;
    document.body.appendChild(audioEl);

    // Create DataChannel before creating offer
    dc = pc.createDataChannel('oai-events');
    dc.onopen = () => {
      try {
        dc.send(JSON.stringify({
          type: 'session.update',
          session: {
            turn_detection: {
              type: 'server_vad',
              threshold: 0.45,
              prefix_padding_ms: 300,
              silence_duration_ms: 500,
              create_response: true
            }
          }
        }));
      } catch(e){}
    };
    dc.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'input_audio_buffer.speech_started') {
          if (audioEl) audioEl.muted = true;
          try { dc.send(JSON.stringify({ type: 'response.cancel' })); } catch(e){}
        } else if (msg.type === 'response.audio.delta' || msg.type === 'response.created') {
          if (audioEl) audioEl.muted = false;
        }
      } catch(e){}
    };

    pc.ontrack = (e) => {
      if (e.streams && e.streams[0]) audioEl.srcObject = e.streams[0];
      else {
        const ms = new MediaStream([e.track]);
        audioEl.srcObject = ms;
      }
    };
    local.getTracks().forEach(t => pc.addTrack(t, local));
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await new Promise((resolve) => {
      if (pc.iceGatheringState === 'complete') return resolve();
      const t = setTimeout(resolve, 2500);
      pc.onicegatheringstatechange = () => {
        if (pc.iceGatheringState === 'complete') {
          clearTimeout(t);
          resolve();
        }
      };
    });
    const sdp = pc.localDescription && pc.localDescription.sdp;
    if (!sdp) throw new Error('no_local_sdp');
    const resp = await fetch(callsUrl, {
      method: 'POST',
      body: sdp,
      headers: {
        Authorization: 'Bearer ' + secret,
        'Content-Type': 'application/sdp'
      }
    });
    if (!resp.ok) throw new Error('realtime_calls_' + resp.status);
    const answerSdp = await resp.text();
    await pc.setRemoteDescription({ type: 'answer', sdp: answerSdp });
    return 'ok';
  };

  window.agFarmerRealtimeReady = true;
})();
''';
    web.document.head?.append(script);
  }

  static Future<void> connect({
    required String accessToken,
    required String wsUrl,
    required String model,
    required String voice,
    required String instructions,
    bool premium = false,
    bool video = false,
    void Function(String status)? onStatus,
    void Function(String role, String text)? onTranscript,
  }) async {
    _ensureScript();
    onStatus?.call('mic');
    // Wait a tick so script is parsed
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (_jsReady != true.toJS) {
      throw StateError('realtime_js_missing');
    }
    onStatus?.call('exchange');
    // Web JS bridge still expects secret + calls URL; map from token/ws.
    final result = await _jsConnect(accessToken.toJS, wsUrl.toJS).toDart;
    if (result == null) {
      throw StateError('realtime_connect_failed');
    }
    onStatus?.call('listening');
  }

  static Future<void> disconnect() async {
    try {
      if (_scriptInjected) _jsDisconnect();
    } catch (_) {}
  }

  static void interrupt() {
    try {
      if (_scriptInjected) _jsInterrupt();
    } catch (_) {}
  }
}
