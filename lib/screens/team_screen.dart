import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

const _teamRoles = [UserRole.cashier, UserRole.admin, UserRole.marketOwner];

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _query = '';
  void _edit([StaffUser? user]) => showDialog<void>(
    context: context,
    builder: (_) => _UserEditor(user: user),
  );
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final users = store.users
        .where((u) => u.role != UserRole.superManager)
        .where(
          (u) => '${u.name} ${u.username}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        PageHeading(
          title: 'team',
          subtitle: 'teamSubtitle',
          action: FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(context.tr('addUser')),
          ),
        ),
        Text(
          '${context.tr('market')}: ${store.settings.name}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _teamRoles
              .map(
                (role) => SizedBox(
                  width: 260,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            role == UserRole.admin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.badge_outlined,
                            color: forest,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.tr(role.name),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(switch (role) {
                              UserRole.cashier => 'cashierPermissions',
                              UserRole.admin => 'adminPermissions',
                              UserRole.marketOwner => 'marketOwnerPermissions',
                              _ => 'ownerPermissions',
                            }),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 26),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: context.tr('search'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (users.isEmpty)
          const EmptyState(icon: Icons.group_outlined)
        else
          Card(
            child: Column(
              children: users
                  .map(
                    (u) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: sage,
                        child: Text(
                          u.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            u.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          StatusPill(context.tr(u.role.name)),
                          if (!u.active)
                            StatusPill(context.tr('inactive'), color: danger),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '@${u.username}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                      trailing: !store.isOwner && u.role != UserRole.cashier
                          ? const Icon(
                              Icons.lock_outline,
                              size: 17,
                              color: muted,
                            )
                          : PopupMenuButton<String>(
                              tooltip: context.tr('edit'),
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  _edit(u);
                                  return;
                                }
                                if (await confirmAction(
                                      context,
                                      title: 'confirmDelete',
                                      message: 'deleteHint',
                                    ) &&
                                    context.mounted) {
                                  try {
                                    store.deleteUser(u.id);
                                    notifySaved(context);
                                  } catch (e) {
                                    notifyError(context, e);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(context.tr('edit')),
                                ),
                                if (u.id != store.currentUser!.id)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      context.tr('delete'),
                                      style: const TextStyle(color: danger),
                                    ),
                                  ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({this.user});
  final StaffUser? user;
  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _username;
  final _password = TextEditingController();
  late UserRole _role;
  late bool _active;
  bool _busy = false;
  String? _marketId;
  late final Set<CashierPermission> _extraPermissions;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name);
    _username = TextEditingController(text: widget.user?.username);
    _role = widget.user?.role ?? UserRole.cashier;
    _active = widget.user?.active ?? true;
    _extraPermissions = {...?widget.user?.extraPermissions};
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = context.store;
    setState(() => _busy = true);
    try {
      await store.saveUser(
        id: widget.user?.id,
        marketId:
            widget.user == null && store.isOwner && _role == UserRole.admin
            ? _marketId ?? store.activeMarketId
            : null,
        name: _name.text,
        username: _username.text,
        role: _role,
        password: _password.text,
        active: _active,
        extraPermissions: _role == UserRole.cashier ? _extraPermissions : {},
      );
      if (mounted) {
        Navigator.pop(context);
        notifySaved(context);
      }
    } catch (e) {
      if (mounted) {
        notifyError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.user?.id == context.store.currentUser!.id;
    return PopScope(
      canPop: !_busy,
      child: FormDialog(
        title: widget.user == null ? 'addUser' : 'editUser',
        busy: _busy,
        onSave: _save,
        child: Form(
          key: _form,
          child: Column(
            children: [
              Field(_name, 'fullName', required: true),
              Field(
                _username,
                'username',
                required: true,
                hint: 'usernameHint',
              ),
              Field(
                _password,
                'password',
                obscure: true,
                required: widget.user == null,
                hint: widget.user == null ? 'passwordHint' : 'newPasswordHint',
              ),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: InputDecoration(labelText: context.tr('role')),
                items: (context.store.isOwner ? _teamRoles : [UserRole.cashier])
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(context.tr(r.name)),
                      ),
                    )
                    .toList(),
                onChanged: self ? null : (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              if (_role == UserRole.cashier) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.tr('extraPermissions'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('extraPermissionsHint'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                for (final permission in CashierPermission.values)
                  CheckboxListTile(
                    key: ValueKey('cashier-permission-${permission.name}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _extraPermissions.contains(permission),
                    title: Text(
                      context.tr('permission_${permission.name}'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      context.tr('permission_${permission.name}_hint'),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    onChanged: _busy
                        ? null
                        : (enabled) => setState(() {
                            if (enabled == true) {
                              _extraPermissions.add(permission);
                            } else {
                              _extraPermissions.remove(permission);
                            }
                          }),
                  ),
                const SizedBox(height: 16),
              ],
              if (widget.user == null &&
                  context.store.isOwner &&
                  _role == UserRole.admin) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('admin-market-selector'),
                  initialValue: _marketId ?? context.store.activeMarketId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('market'),
                    helperText: context.tr('adminMarketHint'),
                    helperMaxLines: 3,
                  ),
                  items: context.store.markets
                      .map(
                        (market) => DropdownMenuItem(
                          value: market.id,
                          child: Text(
                            market.settings.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (id) => setState(() => _marketId = id),
                ),
                const SizedBox(height: 16),
              ],
              if (_role == UserRole.marketOwner)
                Text(
                  context.tr('marketOwnerPermissions'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr('accountActive'),
                  style: const TextStyle(fontSize: 13),
                ),
                value: _active,
                onChanged: self ? null : (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
