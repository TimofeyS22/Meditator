import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/features/meditation/widgets/meditation_tile.dart';
import 'package:meditator/shared/models/meditation.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

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
    try {
      final rows = await Db.instance.getMeditations();
      if (!mounted) return;
      setState(() {
        _all = rows.map((e) => Meditation.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
                    icon:
                        const Icon(Icons.arrow_back_rounded, color: C.text),
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
                  color: C.surfaceLight,
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
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: AnimatedContainer(
                      duration: Anim.fast,
                      width: _searchFocused ? 56 : 48,
                      child: const Icon(Icons.search_rounded,
                          color: C.textDim),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 60.ms, duration: Anim.normal)
                .slideY(begin: 0.03),

            const SizedBox(height: S.m),

            SizedBox(
              height: 40,
              child: Semantics(
                label: 'Фильтры категорий медитаций',
                child: ListView(
                  scrollDirection: Axis.horizontal,
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
                          label: '${c.emoji} ${c.label}',
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
                  ? const Center(
                      child: CircularProgressIndicator(color: C.accent))
                  : list.isEmpty
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: S.l),
                            padding: const EdgeInsets.all(S.l),
                            decoration: BoxDecoration(
                              color: C.surface.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(R.l),
                              border: Border.all(color: C.surfaceBorder),
                            ),
                            child: Text(
                              'Ничего не нашли — попробуй другой запрос.',
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(color: C.textSec),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              S.m, 0, S.m, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: S.m,
                            crossAxisSpacing: S.m,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) =>
                              MeditationTile(meditation: list[i], index: i),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/aura'),
        backgroundColor: C.surfaceLight,
        foregroundColor: C.accent,
        tooltip: 'Создать медитацию с Aura',
        icon: ShaderMask(
          shaderCallback: (b) => C.gradientPrimary.createShader(b),
          child:
              const Icon(Icons.auto_awesome_rounded, color: Colors.white),
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
              color: selected ? null : C.surfaceLight,
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : C.surfaceBorder,
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
                    color: selected ? Colors.white : C.textSec,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
