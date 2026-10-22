import 'package:flutter/material.dart';
import '../models/crop_track.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/crop_glyph.dart';

class CropTrackDetailScreen extends StatefulWidget {
  final String trackId;

  const CropTrackDetailScreen({super.key, required this.trackId});

  @override
  State<CropTrackDetailScreen> createState() => _CropTrackDetailScreenState();
}

class _CropTrackDetailScreenState extends State<CropTrackDetailScreen>
    with SingleTickerProviderStateMixin, PageHit {
  @override
  String get analyticsPage => 'crop_track';
  late final TabController _tabs;
  late String _mood;
  double _moisture = 0.55;
  String _pest = 'none';
  String _weather = 'sunny';
  final _note = TextEditingController();
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _mood = 'Good';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final s = AgroScope.of(context).s;
      _mood = s.moods[1];
      _inited = true;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveToday(CropTrack track) async {
    final s = AgroScope.of(context).s;
    final log = await cropTrackService.saveDailyLog(
      trackId: track.id,
      fieldMood: _mood,
      moisture: _moisture,
      pestLevel: _pest,
      weather: _weather,
      note: _note.text,
      isHindi: s.isHi,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AgroColors.deepGreen,
        content: Text(s.dailyDataSaved),
      ),
    );
    setState(() {});
    _tabs.animateTo(1);
    // ignore unused warning by referencing log
    debugPrint('Saved ${log.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return ListenableBuilder(
      listenable: cropTrackService,
      builder: (context, _) {
        final track = cropTrackService.byId(widget.trackId);
        if (track == null) {
          return Scaffold(
            body: Center(child: Text(s.trackNotFound)),
          );
        }

        final report = cropTrackService.buildReport(track, isHindi: s.isHi);
        final todayKey = DateTime.now().toIso8601String().substring(0, 10);
        final todayLog = track.logForDate(todayKey);

        return Scaffold(
          body: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.isDark
                        ? const [Color(0xFF031626), Color(0xFF082F49), Color(0xFF0369A1)]
                        : const [AgroColors.forest, AgroColors.deepGreen, AgroColors.mint],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  CropGlyph(
                                    cropId: track.cropId,
                                    emoji: track.emoji,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      track.name(s.isHi),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            s.trackDetailSubtitle,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          controller: _tabs,
                          indicatorColor: AgroColors.gold,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          tabs: [
                            Tab(text: s.tabDailyData),
                            Tab(text: s.tabSuggestions),
                            Tab(text: s.tabReport),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _DailyDataTab(
                      track: track,
                      todayLog: todayLog,
                      mood: _mood,
                      moisture: _moisture,
                      pest: _pest,
                      weather: _weather,
                      note: _note,
                      onMood: (v) => setState(() => _mood = v),
                      onMoisture: (v) => setState(() => _moisture = v),
                      onPest: (v) => setState(() => _pest = v),
                      onWeather: (v) => setState(() => _weather = v),
                      onSave: () => _saveToday(track),
                    ),
                    _SuggestionsTab(track: track, todayLog: todayLog),
                    _ReportTab(track: track, report: report),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyDataTab extends StatelessWidget {
  final CropTrack track;
  final DailyFieldLog? todayLog;
  final String mood;
  final double moisture;
  final String pest;
  final String weather;
  final TextEditingController note;
  final ValueChanged<String> onMood;
  final ValueChanged<double> onMoisture;
  final ValueChanged<String> onPest;
  final ValueChanged<String> onWeather;
  final VoidCallback onSave;

  const _DailyDataTab({
    required this.track,
    required this.todayLog,
    required this.mood,
    required this.moisture,
    required this.pest,
    required this.weather,
    required this.note,
    required this.onMood,
    required this.onMoisture,
    required this.onPest,
    required this.onWeather,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final moods = s.moods;
    final pests = [s.pestNone, s.pestLow, s.pestMedium, s.pestHigh];
    final weathers = [s.weatherSunny, s.weatherCloudy, s.weatherRainy, s.weatherHot];

    // Map display labels to stable keys for pest/weather storage when Hindi
    String pestKey(String label) {
      if (label == s.pestNone) return 'none';
      if (label == s.pestLow) return 'low';
      if (label == s.pestMedium) return 'medium';
      return 'high';
    }

    String weatherKey(String label) {
      if (label == s.weatherSunny) return 'sunny';
      if (label == s.weatherCloudy) return 'cloudy';
      if (label == s.weatherRainy) return 'rainy';
      return 'hot';
    }

    String pestLabel(String key) {
      switch (key) {
        case 'low':
          return s.pestLow;
        case 'medium':
          return s.pestMedium;
        case 'high':
          return s.pestHigh;
        default:
          return s.pestNone;
      }
    }

    String weatherLabel(String key) {
      switch (key) {
        case 'cloudy':
          return s.weatherCloudy;
        case 'rainy':
          return s.weatherRainy;
        case 'hot':
          return s.weatherHot;
        default:
          return s.weatherSunny;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SoftCard(
          color: context.agroSoftFill,
          child: Text(
            todayLog == null ? s.enterTodayData : s.updateTodayData,
            style: TextStyle(fontWeight: FontWeight.w800, color: context.agroText, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.fieldMood, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: moods.map((m) {
                  final selected = mood == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: selected,
                    onSelected: (_) => onMood(m),
                    selectedColor: AgroColors.leaf,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : (context.isDark
                              ? AgroColors.nightText
                              : AgroColors.deepGreen),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(s.soilMoisture, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(moisture * 100).round()}%',
                    style: TextStyle(fontWeight: FontWeight.w900, color: context.isDark ? AgroColors.mint : AgroColors.deepGreen),
                  ),
                ],
              ),
              Slider(
                value: moisture,
                onChanged: onMoisture,
                activeColor: AgroColors.leaf,
                inactiveColor: context.agroSoftFill,
              ),
              const SizedBox(height: 8),
              Text(s.pestLevelLabel, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: pests.map((p) {
                  final selected = pestLabel(pest) == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: selected,
                    onSelected: (_) => onPest(pestKey(p)),
                    selectedColor: AgroColors.leaf,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : (context.isDark
                              ? AgroColors.nightText
                              : AgroColors.deepGreen),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(s.weatherLabel, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: weathers.map((w) {
                  final selected = weatherLabel(weather) == w;
                  return ChoiceChip(
                    label: Text(w),
                    selected: selected,
                    onSelected: (_) => onWeather(weatherKey(w)),
                    selectedColor: AgroColors.leaf,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : (context.isDark
                              ? AgroColors.nightText
                              : AgroColors.deepGreen),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.eveningNote,
                  hintText: s.eveningHint,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(s.saveDailyData),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(s.recentLogs, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.agroText)),
        const SizedBox(height: 8),
        if (track.logs.isEmpty)
          SoftCard(child: Text(s.noDailyLogsYet, style: TextStyle(color: context.agroMuted)))
        else
          ...track.logs.take(7).map((log) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.dateKey, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
                    const SizedBox(height: 4),
                    Text(
                      '${s.fieldMood}: ${log.fieldMood} • ${s.soilMoisture}: ${(log.moisture * 100).round()}%',
                      style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                    ),
                    Text(
                      '${s.pestLevelLabel}: ${log.pestLevel} • ${s.weatherLabel}: ${log.weather}',
                      style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SuggestionsTab extends StatelessWidget {
  final CropTrack track;
  final DailyFieldLog? todayLog;

  const _SuggestionsTab({required this.track, required this.todayLog});

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final suggestions = todayLog?.suggestions ?? track.latestLog?.suggestions ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SoftCard(
          color: context.agroSoftGoldFill,
          child: Text(
            s.suggestionsExplain,
            style: TextStyle(fontWeight: FontWeight.w800, color: context.agroText, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        if (suggestions.isEmpty)
          SoftCard(child: Text(s.noSuggestionsYet, style: TextStyle(color: context.agroMuted)))
        else
          ...suggestions.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: context.agroSoftFill,
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(color: context.agroText, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ReportTab extends StatelessWidget {
  final CropTrack track;
  final CropReport report;

  const _ReportTab({required this.track, required this.report});

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SoftCard(
          gradient: const LinearGradient(
            colors: [Color(0xFF03446E), Color(0xFF0284C7), Color(0xFF38BDF8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.cropReportTitle,
                style: const TextStyle(color: AgroColors.softGold, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                report.summary(s.isHi),
                style: const TextStyle(color: Colors.white, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            children: [
              _StatRow(label: s.daysLogged, value: '${report.totalDays}'),
              _StatRow(label: s.avgMoisture, value: '${report.avgMoisturePercent.round()}%'),
              _StatRow(label: s.commonMood, value: report.mostCommonMood),
              _StatRow(label: s.commonPest, value: report.mostCommonPest),
              _StatRow(label: s.commonWeather, value: report.mostCommonWeather),
            ],
          ),
        ),
        if (report.keySuggestions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(s.reportKeySuggestions, style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText)),
          const SizedBox(height: 8),
          ...report.keySuggestions.map(
            (sug) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                color: context.agroSoftFill,
                child: Text(sug, style: TextStyle(color: context.agroText, height: 1.35)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: context.agroMuted, fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(color: context.agroText, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
