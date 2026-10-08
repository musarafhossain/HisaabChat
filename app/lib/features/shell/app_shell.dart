import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_icons.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/core/widgets/window_class.dart';
import 'package:hisaabchat/features/accounts/presentation/account_form.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/shell/destinations.dart';
import 'package:hisaabchat/features/transactions/presentation/new_transaction.dart';

/// The WhatsApp-style app frame around every signed-in section
/// (docs/04-UI-UX-Design-Brief.md §3).
///
/// * compact: green-title app bar with search and ⋮, bottom NavigationBar, FAB
/// * medium / expanded: WhatsApp Desktop icon rail; each section lays out its
///   own list panel + detail pane.
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, required this.children, super.key});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  Destination get _current => Destination.values[shell.currentIndex];

  void _go(Destination destination) =>
      shell.goBranch(destination.index, initialLocation: destination.index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _FadeIndexedStack(index: shell.currentIndex, children: children);
    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (final (i, d) in Destination.railTop.indexed)
        SingleActivator(LogicalKeyboardKey(0x31 + i), control: true): () => _go(d),
    };

    final content = switch (context.windowClass) {
      WindowClass.compact => _CompactShell(current: _current, onSelect: _go, body: body),
      _ => _RailShell(current: _current, onSelect: _go, body: body),
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(autofocus: true, child: content),
    );
  }
}

class _CompactShell extends ConsumerWidget {
  const _CompactShell({required this.current, required this.onSelect, required this.body});

  final Destination current;
  final ValueChanged<Destination> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reports & Settings open full screen with a back arrow, like WhatsApp's
    // ⋮ → Settings; the four tabs keep the bottom bar.
    if (!current.isTab) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(AppIcons.back),
            onPressed: () => onSelect(Destination.home),
          ),
          title: Text(current.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HisaabChat'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(AppIcons.search),
            onPressed: () => _comingSoon(context, 'Search arrives with transactions in Phase 3.'),
          ),
          _OverflowMenu(onSelect: onSelect),
        ],
      ),
      body: body,
      floatingActionButton: ToastAvoid(child: _Fab(current: current)),
      bottomNavigationBar: ToastAvoid(
        child: NavigationBar(
          selectedIndex: Destination.bottomBar.indexOf(current),
          onDestinationSelected: (i) => onSelect(Destination.bottomBar[i]),
          destinations: [
            for (final d in Destination.bottomBar)
              NavigationDestination(
                icon: AnimatedFillIcon(d.icon, filled: false),
                selectedIcon: AnimatedFillIcon(d.icon, filled: true),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _RailShell extends ConsumerWidget {
  const _RailShell({required this.current, required this.onSelect, required this.body});

  final Destination current;
  final ValueChanged<Destination> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(authControllerProvider).value;

    Widget railButton(Destination d) {
      final selected = d == current;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: d.label,
          preferBelow: false,
          child: AnimatedContainer(
            duration: context.motion(Motion.short),
            decoration: BoxDecoration(
              color: selected ? colors.navIndicator : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: () => onSelect(d),
              icon: AnimatedFillIcon(
                d.icon,
                filled: selected,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 64,
            color: colors.panel,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                // The 'new' action lives in the rail (like WhatsApp Desktop's new-chat
                // button) so it never covers a thread's Send button.
                _Fab(current: current, small: true),
                const SizedBox(height: 12),
                for (final d in Destination.railTop) railButton(d),
                const Spacer(),
                railButton(Destination.settings),
                const SizedBox(height: 8),
                Tooltip(
                  message: user?.fullName ?? 'Profile',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onSelect(Destination.settings),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.primary,
                      child: Text(
                        user?.initials ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: colors.divider),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onSelect});

  final ValueChanged<Destination> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Destination>(
      tooltip: 'More options',
      icon: const Icon(AppIcons.more),
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final d in [Destination.reports, Destination.settings])
          PopupMenuItem(
            value: d,
            child: Row(children: [Icon(d.icon), const SizedBox(width: 12), Text(d.label)]),
          ),
      ],
    );
  }
}

/// Green rounded-square FAB; its icon follows the current section.
class _Fab extends StatelessWidget {
  const _Fab({required this.current, this.small = false});

  final Destination current;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String tooltip, String message) = switch (current) {
      Destination.accounts => (AppIcons.addAccount, 'New account', ''),
      Destination.budgets => (AppIcons.addBudget, 'New budget', 'Budgets arrive in Phase 4.'),
      Destination.reports || Destination.settings => (AppIcons.add, '', ''),
      _ => (AppIcons.add, 'New transaction', ''),
    };
    final visible = tooltip.isNotEmpty;

    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: context.motion(Motion.medium),
      curve: visible ? Motion.pop : Motion.exit,
      child: FloatingActionButton(
        tooltip: visible ? tooltip : null,
        mini: small,
        onPressed: !visible
            ? null
            : current == Destination.accounts
            ? () => showAccountForm(context)
            : current == Destination.budgets
            ? () => _comingSoon(context, message)
            : () => openNewTransaction(context),
        child: AnimatedSwitcher(
          duration: context.motion(Motion.short),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(icon, key: ValueKey(icon)),
        ),
      ),
    );
  }
}

void _comingSoon(BuildContext context, String message) => AppToast.show(context, message);

/// Keeps every section alive (like IndexedStack) and fades the newly
/// selected one in: the "fade-through" tab transition from the motion spec.
class _FadeIndexedStack extends StatefulWidget {
  const _FadeIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (context.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0).ignore();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Motion.enter),
      child: IndexedStack(
        index: widget.index,
        children: [
          for (final (i, child) in widget.children.indexed) TickerMode(enabled: i == widget.index, child: child),
        ],
      ),
    );
  }
}
