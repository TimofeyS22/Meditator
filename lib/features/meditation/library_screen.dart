import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/cache/meditation_cache.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/meditation/widgets/meditation_tile.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/skeleton_placeholders.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  List<Meditation> _all = [];
  MeditationCategory? _category;
  bool _loading = true;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRouteCategory());
    _fetch();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = GoRouterState.of(context).uri.queryParameters['category'];
    MeditationCategory? next;
    if (q != null && q.isNotEmpty) {
      for (final c in MeditationCategory.values) {
        if (c.name == q) next = c;
      }
    }
    if (next != _category) {
      setState(() => _category = next);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final rows = await Db.instance.getMeditations();
    if (!mounted) return;
    if (rows.isNotEmpty) {
      MeditationCache.instance.save(rows);
      setState(() {
        _all = rows.map((e) => Meditation.fromJson(e)).toList();
        _loading = false;
      });
    } else {
      final cached = await MeditationCache.instance.load();
      if (!mounted) return;
      setState(() {
        _all = (cached ?? []).map((e) => Meditation.fromJson(e)).toList();
        _loading = false;
      });
    }
  }

  void _syncRouteCategory() {
    final q = GoRouterState.of(context).uri.queryParameters['category'];
    if (q == null || q.isEmpty) return;
    for (final c in MeditationCategory.values) {
      if (c.name == q) {
        setState(() => _category = c);
        break;
      }
    }
  }

  List<Meditation> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((m) {
      if (_category != null && m.category != _category) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.s),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    tooltip: 'Назад',
                    icon: MIcon(MIconType.arrowBack, size: 24, color: context.cText),
                  ),
                  Expanded(
                    child: Text(
                      'Библиотека',
                      textAlign: TextAlign.center,
                      style: t.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ).animate().fadeIn(duration: Anim.normal),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.m),
              child: AnimatedContainer(
                duration: Anim.normal,
                curve: Anim.curve,
                decoration: BoxDecoration(
                  color: context.cSurfaceLight,
                  borderRadius: BorderRadius.circular(R.m),
                  border: Border.all(
                    color: _searchFocused ? C.primary : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: _searchFocused
                      ? [
                          BoxShadow(
                            color: C.glowPrimary,
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.cText),
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: MIcon(MIconType.search, size: 22, color: context.cTextDim),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 60.ms, duration: Anim.normal)
                .slideY(begin: 0.03),

            const SizedBox(height: S.m),

            SizedBox(
              height: 48,
              child: Semantics(
                label: 'Фильтры категорий медитаций',
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: S.m),
                  children: [
                    _FilterChip(
                      label: 'Все',
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    ...MeditationCategory.values.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(left: S.s),
                        child: _FilterChip(
                          label: c.label,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: S.m),

            Expanded(
              child: _loading
                  ? const LibrarySkeleton()
                  : RefreshIndicator(
                      color: C.accent,
                      onRefresh: _fetch,
                      child: list.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: S.l),
                                    padding: const EdgeInsets.all(S.l),
                                    decoration: BoxDecoration(
                                      color: context.cSurface.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(R.l),
                                      border: Border.all(color: context.cSurfaceBorder),
                                    ),
                                    child: Text(
                                      'Ничего не нашли — попробуй другой запрос.',
                                      textAlign: TextAlign.center,
                                      style: t.bodyMedium,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  S.m, 0, S.m, 100),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: S.m,
                                crossAxisSpacing: S.m,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: list.length,
                              itemBuilder: (_, i) =>
                                  MeditationTile(meditation: list[i], index: i),
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/aura'),
        backgroundColor: context.cSurfaceLight,
        foregroundColor: C.accent,
        tooltip: 'Создать медитацию с Aura',
        icon: ShaderMask(
          shaderCallback: (b) => C.gradientPrimary.createShader(b),
          child:
              const MIcon(MIconType.star, color: Colors.white, size: 22),
        ),
        label: const Text('Создать с Aura'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? ', выбран' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(R.full),
          child: AnimatedContainer(
            duration: Anim.fast,
            curve: Anim.curve,
            padding:
                const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(R.full),
              gradient: selected ? C.gradientPrimary : null,
              color: selected ? null : context.cSurfaceLight,
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : context.cSurfaceBorder,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: C.glowPrimary,
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : context.cTextSec,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
