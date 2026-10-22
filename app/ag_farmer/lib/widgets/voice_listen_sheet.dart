import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/accurate_listen_service.dart';
import '../services/agro_scope.dart';
import '../theme/app_theme.dart';

/// Live mic → text sheet (Hindi / English).
class VoiceListenSheet extends StatefulWidget {
  const VoiceListenSheet({
    super.key,
    required this.onFinalText,
    required this.quickPrompts,
  });

  final void Function(String text) onFinalText;
  final List<({String label, String send})> quickPrompts;

  @override
  State<VoiceListenSheet> createState() => _VoiceListenSheetState();
}

class _VoiceListenSheetState extends State<VoiceListenSheet> {
  bool _preferHindi = true;
  bool _listening = false;
  bool _writing = false;
  bool _busy = false;
  bool _langSeeded = false;
  String _partial = '';
  String _error = '';
  double _level = 0;
  // Guards against popping the sheet twice (e.g. the speech plugin firing
  // two final results, or stop() racing a final result).
  bool _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_langSeeded) {
      _langSeeded = true;
      _preferHindi = AgroScope.of(context).s.isHi;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureReady());
    }
  }

  @override
  void dispose() {
    accurateListen.cancel();
    super.dispose();
  }

  void _submit(String text) {
    if (_submitted || !mounted) return;
    _submitted = true;
    Navigator.pop(context);
    widget.onFinalText(text);
  }

  Future<void> _ensureReady() async {
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _toggleListen() async {
    final s = AgroScope.of(context).s;
    HapticFeedback.mediumImpact();
    if (_writing) return;
    if (_listening) {
      setState(() {
        _listening = false;
        _writing = true;
        _partial = s.voiceWriting;
      });
      final text = (await accurateListen.finishManual(hindi: _preferHindi))
          .trim();
      if (!mounted) return;
      setState(() => _writing = false);
      if (text.isNotEmpty) {
        _submit(text);
        return;
      }
      setState(() {
        _partial = '';
        _error = s.isHi
            ? 'साफ़ बोलकर फिर माइक दबाएँ।'
            : 'Speak clearly and tap the mic again.';
      });
      return;
    }

    setState(() {
      _error = '';
      _partial = '';
      _listening = true;
    });

    try {
      await accurateListen.beginManual(
        hindi: _preferHindi,
        onLevel: (lv) {
          if (!mounted) return;
          setState(() => _level = lv.clamp(0, 1));
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = s.voiceUnavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final pulse = 1.0 + (_listening ? (_level / 40).clamp(0.0, 0.25) : 0.0);
    final media = MediaQuery.of(context);

    // Shown with isScrollControlled: true, so cap the height and scroll;
    // many quick prompts or a long partial transcript otherwise overflow.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28 + media.viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.agroBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                s.voiceModalTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.agroText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.voiceModalSub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.agroMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _LangChip(
                      selected: _preferHindi,
                      label: 'हिन्दी / बोली',
                      onTap: _listening
                          ? null
                          : () => setState(() => _preferHindi = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LangChip(
                      selected: !_preferHindi,
                      label: 'English',
                      onTap: _listening
                          ? null
                          : () => setState(() => _preferHindi = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: (_busy || _writing) ? null : _toggleListen,
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _listening
                            ? const [Color(0xFF0369A1), Color(0xFF38BDF8)]
                            : const [AgroColors.deepGreen, AgroColors.leaf],
                      ),
                      border: Border.all(
                        color: _listening ? Colors.white : AgroColors.skyIce,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AgroColors.skyVibrant.withValues(
                            alpha: _listening ? 0.45 : 0.25,
                          ),
                          blurRadius: _listening ? 28 : 16,
                          spreadRadius: _listening ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _busy
                    ? s.voicePreparing
                    : (_writing
                        ? s.voiceWriting
                        : (_listening ? s.voiceListening : s.voiceTapToSpeak)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.agroGold,
                ),
              ),
              if (_partial.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.agroSoftFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.agroBorder),
                  ),
                  child: Text(
                    _partial,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.35,
                      color: context.agroText,
                    ),
                  ),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AgroColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.voiceQuickOr,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.agroMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.quickPrompts
                    .map(
                      (p) => ActionChip(
                        label: Text(
                          p.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _submit(p.send),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AgroColors.skyPrimary : context.agroSoftFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          // >= 44dp tap target (text alone gave ~36dp).
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: selected ? Colors.white : context.agroText,
            ),
          ),
        ),
      ),
    );
  }
}
