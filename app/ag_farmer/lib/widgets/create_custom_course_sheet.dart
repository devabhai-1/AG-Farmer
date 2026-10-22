import 'package:flutter/material.dart';

import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import 'crop_glyph.dart';
import 'plan_unlock_sheet.dart';

String _slug(String name) {
  final raw = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097f]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (raw.isEmpty) return 'custom_${DateTime.now().millisecondsSinceEpoch}';
  return raw.length > 40 ? raw.substring(0, 40) : raw;
}

CropItem _customItem(String name) {
  final id = 'custom_${_slug(name)}';
  return CropItem(
    id: id,
    nameEn: name.trim(),
    nameHi: name.trim(),
    emoji: '🌱',
    minPlan: PlanTier.advanced,
    priority: 900,
  );
}

/// Bottom sheet: pick a catalog crop or type a custom name.
/// When [asFasalCourse] is true, returns a [CropItem] for course enroll.
/// Otherwise starts a crop track and pops null.
Future<CropItem?> showCreateNewCourseSheet(
  BuildContext context, {
  bool asFasalCourse = false,
}) {
  return showModalBottomSheet<CropItem?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateCourseSheet(asFasalCourse: asFasalCourse),
  );
}

class _CreateCourseSheet extends StatefulWidget {
  const _CreateCourseSheet({required this.asFasalCourse});

  final bool asFasalCourse;

  @override
  State<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<_CreateCourseSheet> {
  final _name = TextEditingController();
  String _q = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<CropItem> get _filtered {
    final all = catalogService.indiaCourseCrops();
    if (_q.isEmpty) return all.take(24).toList();
    final q = _q.toLowerCase();
    return all
        .where(
          (c) =>
              c.nameEn.toLowerCase().contains(q) ||
              c.nameHi.contains(_q) ||
              c.id.contains(q),
        )
        .take(40)
        .toList();
  }

  Future<void> _pick(CropItem crop) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await ensureCropAccess(context, profileService, crop);
      if (!ok || !mounted) return;
      if (widget.asFasalCourse) {
        Navigator.of(context).pop(crop);
        return;
      }
      await cropTrackService.startTrack(crop);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      final s = AgroScope.of(context).s;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCustom() async {
    final s = AgroScope.of(context).s;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.createNewCourseEmpty)),
      );
      return;
    }
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.createNewCourseShort)),
      );
      return;
    }
    await _pick(_customItem(name));
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final crops = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: context.agroCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.agroBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.createNewCourseTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.createNewCourseSub,
                      style: TextStyle(
                        color: context.agroMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _name,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitCustom(),
                  decoration: InputDecoration(
                    hintText: s.createNewCourseHint,
                    prefixIcon: const Icon(Icons.eco_outlined),
                    filled: true,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  shrinkWrap: true,
                  itemCount: crops.length,
                  itemBuilder: (context, i) {
                    final crop = crops[i];
                    return ListTile(
                      leading: CropGlyph.item(crop, size: 28),
                      title: Text(
                        crop.name(s.isHi),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : () => _pick(crop),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submitCustom,
                    child: Text(
                      s.createNewCourseCta,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
