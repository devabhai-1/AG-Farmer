import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/api_client.dart';
import '../services/page_analytics.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';

class CreditTokenScreen extends StatefulWidget {
  const CreditTokenScreen({super.key});

  @override
  State<CreditTokenScreen> createState() => _CreditTokenScreenState();
}

class _CreditTokenScreenState extends State<CreditTokenScreen> with PageHit {
  @override
  String get analyticsPage => 'credit_token';
  final _code = TextEditingController();
  final _voice = TextEditingController(text: '5');
  final _video = TextEditingController(text: '1');
  int _voiceLeft = 0;
  int _videoLeft = 0;
  String _note = '';
  String _made = '';
  bool _busy = false;

  bool get _canMint =>
      profileService.plan == PlanTier.distributor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _voice.dispose();
    _video.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.call('credit.status', auth: true);
      final wallet = res['wallet'];
      if (!mounted || wallet is! Map) return;
      setState(() {
        _voiceLeft = int.tryParse('${wallet['voice']}') ?? 0;
        _videoLeft = int.tryParse('${wallet['video']}') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _note = '';
    });
    try {
      final res = await ApiClient.instance.call(
        'credit.redeem',
        auth: true,
        data: {'code': code},
      );
      final wallet = res['wallet'];
      if (!mounted) return;
      setState(() {
        _busy = false;
        _code.clear();
        _note = AgroScope.of(context).s.isHi
            ? 'क्रेडिट लग गया।'
            : 'Credits added.';
        if (wallet is Map) {
          _voiceLeft = int.tryParse('${wallet['voice']}') ?? _voiceLeft;
          _videoLeft = int.tryParse('${wallet['video']}') ?? _videoLeft;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _busy = false;
        _note = msg.contains('credit_used')
            ? (AgroScope.of(context).s.isHi ? 'यह टोकन पहले लग चुका है।' : 'This token is already used.')
            : (AgroScope.of(context).s.isHi ? 'टोकन सही नहीं है।' : 'Token is not valid.');
      });
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = '';
      _made = '';
    });
    try {
      final res = await ApiClient.instance.call(
        'credit.create',
        auth: true,
        data: {
          'voice': int.tryParse(_voice.text.trim()) ?? 0,
          'video': int.tryParse(_video.text.trim()) ?? 0,
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _made = '${res['code'] ?? ''}';
        _note = AgroScope.of(context).s.isHi
            ? 'टोकन बन गया। इसे किसान को दो।'
            : 'Token created. Give it to the farmer.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = AgroScope.of(context).s.isHi
            ? 'टोकन नहीं बना।'
            : 'Could not create the token.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = AgroScope.of(context).s.isHi;
    return Scaffold(
      appBar: AppBar(
        title: Text(hi ? 'क्रेडिट टोकन' : 'Credit token'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20, 16, 20, 28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            hi
                ? 'आवाज़ क्रेडिट $_voiceLeft · वीडियो मिनट $_videoLeft'
                : 'Voice credits $_voiceLeft · Video minutes $_videoLeft',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: hi ? 'टोकन लगाओ' : 'Redeem token',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _busy ? null : _redeem,
            style: ElevatedButton.styleFrom(
              backgroundColor: AgroColors.deepGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(hi ? 'क्रेडिट लगाओ' : 'Add credits'),
          ),
          if (_canMint) ...[
            const SizedBox(height: 28),
            Text(
              hi ? 'नया टोकन बनाओ' : 'Create a token',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voice,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: hi ? 'आवाज़' : 'Voice',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _video,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: hi ? 'वीडियो मिनट' : 'Video minutes',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _create,
              child: Text(hi ? 'टोकन बनाओ' : 'Create token'),
            ),
            if (_made.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  _made,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
          ],
          if (_note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(_note),
            ),
        ],
      ),
    );
  }
}

Future<void> openCreditTokenScreen(BuildContext context) {
  HapticFeedback.lightImpact();
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CreditTokenScreen()),
  );
}
