import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';
import '../services/yeelight_service.dart';
import '../services/storage_service.dart';
import '../widgets/group_card.dart';
import '../screens/settings_screen.dart';
import '../screens/scenes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final YeelightService _yeelightService = YeelightService();
  final StorageService _storage = StorageService.instance;

  List<Lamp> _lamps = [];
  List<LampGroup> _groups = [];
  List<Scene> _scenes = [];
  bool _isDiscovering = false;
  StreamSubscription? _deviceSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _reachabilitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToLamps();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceSubscription?.cancel();
    _stateSubscription?.cancel();
    _reachabilitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Wi-Fi drops while backgrounded kill the sockets without a FIN, so the
    // connections have to be re-verified before the user presses anything.
    _yeelightService.refreshConnections();
  }

  /// Initialize app
  Future<void> _initialize() async {
    await _loadData();

    // Open the control connections before discovery runs: the stored IPs are
    // almost always still right, and a warm socket is what makes the first
    // button press instant.
    _yeelightService.warmUp(_lamps.map((l) => l.ip));

    await _startDiscovery();
  }

  /// Load saved data
  Future<void> _loadData() async {
    final lamps = await _storage.loadLamps();
    final groups = await _storage.loadGroups();
    final scenes = await _storage.loadScenes();

    setState(() {
      _lamps = lamps;
      _groups = groups;
      _scenes = scenes;
    });

    // Generate system groups automatically if needed
    await _updateSystemGroups();
  }

  /// Subscribe to everything the lamps tell us on their own.
  void _listenToLamps() {
    _deviceSubscription = _yeelightService.deviceStream.listen((device) async {
      await _onDeviceDiscovered(device);
    });

    // NOTIFICATION messages pushed by the lamps (spec 4.3) and keepalive reads.
    _stateSubscription = _yeelightService.stateStream.listen(_onStateUpdate);

    _reachabilitySubscription =
        _yeelightService.reachabilityStream.listen(_onReachabilityChanged);
  }

  /// A lamp reported a property change on its own.
  void _onStateUpdate(LampStateUpdate update) {
    final index = _lamps.indexWhere((l) => l.ip == update.ip);
    if (index < 0) return;

    final old = _lamps[index];
    final lamp = old.copyWith(
      power: update.power,
      brightness: update.brightness,
      colorTemp: update.colorTemp,
      rgb: update.rgb,
      reachable: true,
      lastSeen: DateTime.now(),
    );

    _lamps[index] = lamp;
    _storage.updateLamp(lamp);

    if (old.power != lamp.power ||
        old.brightness != lamp.brightness ||
        old.colorTemp != lamp.colorTemp ||
        old.rgb != lamp.rgb ||
        !old.reachable) {
      if (mounted) setState(() {});
    }
  }

  /// The control connection to a lamp went up or down.
  void _onReachabilityChanged(LampReachability event) {
    final index = _lamps.indexWhere((l) => l.ip == event.ip);
    if (index < 0) return;
    if (_lamps[index].reachable == event.reachable) return;

    _lamps[index] = _lamps[index].copyWith(reachable: event.reachable);

    // A lamp that dropped off its known IP has most likely been given a new one
    // by DHCP. Look for it in the background so the next press finds it.
    if (!event.reachable) _rediscoverInBackground();

    if (mounted) setState(() {});
  }

  bool _rediscovering = false;

  Future<void> _rediscoverInBackground() async {
    if (_rediscovering) return;
    _rediscovering = true;
    try {
      await _yeelightService.startDiscovery(
        knownIPs: _lamps.map((l) => l.ip).toList(),
      );
    } finally {
      _rediscovering = false;
    }
  }

  /// Start lamp discovery
  Future<void> _startDiscovery() async {
    setState(() => _isDiscovering = true);

    await _yeelightService.startDiscovery(
      knownIPs: _lamps.map((lamp) => lamp.ip).toList(),
    );

    if (mounted) setState(() => _isDiscovering = false);
  }

  /// New lamp discovered
  Future<void> _onDeviceDiscovered(YeelightDevice device) async {
    // Match on the device id first: that is what survives a DHCP-assigned new
    // IP, and it is what lets us move the lamp over instead of duplicating it.
    var existingIndex = _lamps.indexWhere((l) => l.id == device.id);
    if (existingIndex < 0) {
      existingIndex = _lamps.indexWhere((l) => l.ip == device.ip);
    }

    Lamp lamp;
    bool wasUpdated = false;

    if (existingIndex >= 0) {
      // Update existing lamp - keep custom name and icon color!
      final oldLamp = _lamps[existingIndex];
      lamp = oldLamp.copyWith(
        // name bleibt unverändert (benutzerdefinierter Name)
        ip: device.ip,
        power: device.power,
        brightness: device.brightness,
        colorTemp: device.colorTemp,
        rgb: device.rgb,
        supportedMethods:
            device.supportedMethods.isEmpty ? null : device.supportedMethods,
        reachable: true,
        lastSeen: DateTime.now(),
      );

      if (oldLamp.ip != device.ip) {
        _yeelightService.relocate(oldLamp.ip, device.ip);
      } else {
        _yeelightService.warmUp([device.ip]);
      }

      // Check if status changed
      wasUpdated = oldLamp.power != lamp.power ||
          oldLamp.brightness != lamp.brightness ||
          oldLamp.colorTemp != lamp.colorTemp ||
          oldLamp.rgb != lamp.rgb ||
          oldLamp.ip != lamp.ip ||
          !oldLamp.reachable;

      _lamps[existingIndex] = lamp;
    } else {
      // Add new lamp
      final colorIndex = _lamps.length % LampColors.palette.length;
      lamp = Lamp(
        id: device.id,
        name: device.name,
        model: device.model,
        ip: device.ip,
        power: device.power,
        brightness: device.brightness,
        colorTemp: device.colorTemp,
        rgb: device.rgb,
        supportedMethods: device.supportedMethods,
        iconColor: LampColors.getColor(colorIndex),
      );
      _lamps.add(lamp);
      _yeelightService.warmUp([device.ip]);
      wasUpdated = true;
    }

    await _storage.updateLamp(lamp);
    await _updateSystemGroups();

    // Update UI only if something changed
    if (wasUpdated && mounted) {
      setState(() {});
    }
  }

  /// Update system groups
  Future<void> _updateSystemGroups() async {
    final systemGroups = await _storage.generateSystemGroups(_lamps);

    // Keep existing custom groups
    final customGroups =
        _groups.where((g) => g.type == GroupType.custom).toList();

    _groups = [...systemGroups, ...customGroups];
    await _storage.saveGroups(_groups);
  }

  /// Manual refresh
  Future<void> _refresh() async {
    await _startDiscovery();

    // lastSeen wird automatisch durch Discovery aktualisiert
    // Alte Lampen werden durch isOffline Getter automatisch erkannt

    setState(() {});
  }

  /// Create new group
  Future<void> _createGroup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateGroupDialog(lamps: _lamps),
    );

    if (result != null) {
      final group = LampGroup(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: result['name'],
        lampIds: List<String>.from(result['lampIds']),
        iconColor: LampColors.getColor(_groups.length),
        type: GroupType.custom,
      );

      _groups.add(group);
      await _storage.updateGroup(group);
      setState(() {});
    }
  }

  /// Toggle group on/off
  Future<void> _toggleGroup(LampGroup group) async {
    final groupLamps =
        _lamps.where((l) => group.lampIds.contains(l.id)).toList();

    if (groupLamps.isEmpty) return;

    // Base the target on every lamp, including ones we currently believe are
    // unreachable: the user can see the lamp and knows what it is doing even
    // when the app has lost track of it. A mixed group turns on, as before.
    final allOn = groupLamps.every((l) => l.power);
    final targetPower = !allOn;

    // Flip the UI now. The command goes out on an already-open socket, so this
    // is what the user sees while it is in flight - not a frozen button.
    setState(() {
      for (final lamp in groupLamps) {
        final index = _lamps.indexWhere((l) => l.id == lamp.id);
        if (index >= 0) {
          _lamps[index] = _lamps[index].copyWith(power: targetPower);
        }
      }
    });

    // All lamps at once, not one after another.
    final results = await Future.wait(
      groupLamps.map((lamp) => _yeelightService.setPower(lamp.ip, targetPower)),
    );

    // Reconcile: a lamp that did not take the command keeps whatever state it
    // reports next (via notification or keepalive); we only persist the ones
    // that did, and flag the rest as unreachable.
    for (int i = 0; i < groupLamps.length; i++) {
      final index = _lamps.indexWhere((l) => l.id == groupLamps[i].id);
      if (index < 0) continue;

      if (results[i]) {
        _lamps[index] = _lamps[index].copyWith(lastSeen: DateTime.now());
        await _storage.updateLamp(_lamps[index]);
      } else {
        _lamps[index] = _lamps[index].copyWith(
          power: groupLamps[i].power, // revert the optimistic flip
          reachable: false,
        );
      }
    }

    if (mounted) setState(() {});
  }

  /// Edit group (settings)
  void _editGroup(LampGroup group) async {
    if (group.type == GroupType.single) {
      // For single lamps: check if brightness/color temp supported
      final lamp = _lamps.firstWhere((l) => l.id == group.lampIds.first);

      if (lamp.supportsColorTemp || lamp.supportsRgb) {
        // Lamp supports extended settings -> Settings Screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              group: group,
              lamps: [lamp],
              onSceneSaved: _onSceneSaved,
            ),
          ),
        );
        // Refresh lamp states after return
        await _refreshLampStates();
      } else {
        // Only name/color -> Dialog
        _showLampSettings(group);
      }
    } else {
      // For groups: brightness and color temperature settings
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            group: group,
            lamps: _lamps.where((l) => group.lampIds.contains(l.id)).toList(),
            onSceneSaved: _onSceneSaved,
          ),
        ),
      );
      // Refresh lamp states after return
      await _refreshLampStates();
    }
  }

  /// Callback when scene was saved
  void _onSceneSaved(Scene scene) {
    setState(() {
      final index = _scenes.indexWhere((s) => s.id == scene.id);
      if (index >= 0) {
        _scenes[index] = scene;
      } else {
        _scenes.add(scene);
      }
    });
  }

  /// Show lamp-specific settings
  void _showLampSettings(LampGroup group) async {
    final lamp = _lamps.firstWhere((l) => l.id == group.lampIds.first);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LampSettingsDialog(lamp: lamp),
    );

    if (result != null) {
      // Update lamp
      final updatedLamp = lamp.copyWith(
        name: result['name'],
        iconColor: result['color'],
      );

      final index = _lamps.indexWhere((l) => l.id == lamp.id);
      if (index >= 0) {
        _lamps[index] = updatedLamp;
        await _storage.updateLamp(updatedLamp);

        // Regenerate system groups (for new name)
        await _updateSystemGroups();
        setState(() {});
      }
    }
  }

  /// Delete group
  Future<void> _deleteGroup(LampGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    String title, content;

    if (group.type == GroupType.single) {
      final lamp = _lamps.firstWhere((l) => l.id == group.lampIds.first);
      title = l10n.deleteLampTitle;
      content = l10n.deleteLampConfirm(lamp.name);
    } else {
      title = l10n.deleteGroupTitle;
      content = l10n.deleteGroupConfirm(group.name);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (group.type == GroupType.single) {
        // Delete lamp
        final lampId = group.lampIds.first;
        _lamps.removeWhere((l) => l.id == lampId);
        await _storage.deleteLamp(lampId);
      } else {
        // Delete custom group
        _groups.removeWhere((g) => g.id == group.id);
        await _storage.deleteGroup(group.id);
      }

      // Regenerate system groups
      await _updateSystemGroups();
      setState(() {});
    }
  }

  /// Show scenes for group
  void _showScenes(LampGroup group) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScenesScreen(
          group: group,
          scenes: _scenes,
          lamps: _lamps.where((l) => group.lampIds.contains(l.id)).toList(),
        ),
      ),
    );

    // Reload scenes after returning
    if (result == 'scenes_changed') {
      final scenes = await _storage.loadScenes();
      setState(() {
        _scenes = scenes;
      });
    }

    // Always refresh lamp states since a scene might have been applied
    await _refreshLampStates();
  }

  /// Refresh lamp states for a group.
  ///
  /// Reads the properties back over the open connections instead of re-running
  /// discovery - the lamps also push their changes on their own, so this is
  /// only a safety net for a notification we might have missed.
  Future<void> _refreshLampStates() async {
    await _yeelightService.refreshConnections();
  }

  /// Check if current settings match a scene
  Scene? _getMatchingScene(LampGroup group) {
    final groupLamps =
        _lamps.where((l) => group.lampIds.contains(l.id)).toList();

    // Find matching scenes for these lamps
    for (final scene in _scenes) {
      if (scene.isApplicableToLamps(groupLamps)) {
        if (scene.matchesLamps(groupLamps)) {
          return scene;
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Sort groups: All, then Custom, then Single lamps
    final sortedGroups = [..._groups];
    sortedGroups.sort((a, b) {
      if (a.type == GroupType.all) return -1;
      if (b.type == GroupType.all) return 1;
      if (a.type == GroupType.custom && b.type == GroupType.single) return -1;
      if (a.type == GroupType.single && b.type == GroupType.custom) return 1;
      return a.name.compareTo(b.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: _isDiscovering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isDiscovering ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _groups.isEmpty
            ? const EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sortedGroups.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = sortedGroups[index];
                  final groupLamps = _lamps
                      .where((l) => group.lampIds.contains(l.id))
                      .toList();
                  final activeScene = _getMatchingScene(group);

                  return GroupCard(
                    group: group,
                    lamps: groupLamps,
                    activeScene: activeScene,
                    onToggle: () => _toggleGroup(group),
                    onSettings: () => _editGroup(group),
                    onScenes: () => _showScenes(group),
                    onDelete: group.type != GroupType.all
                        ? () => _deleteGroup(group)
                        : null,
                    onLampSettings: group.type == GroupType.single
                        ? () => _showLampSettings(group)
                        : null,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        tooltip: l10n.newGroup,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog to create a new group
class CreateGroupDialog extends StatefulWidget {
  final List<Lamp> lamps;

  const CreateGroupDialog({super.key, required this.lamps});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _controller = TextEditingController();
  final Set<String> _selectedLampIds = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty || _selectedLampIds.isEmpty) return;

    Navigator.of(context).pop({
      'name': name,
      'lampIds': _selectedLampIds.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();

    return AlertDialog(
      title: Text(l10n.newGroup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group name
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l10n.groupName,
                hintText: l10n.groupNameHint,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            if (onlineLamps.isEmpty)
              Text(l10n.noLampsOnlineShort)
            else ...[
              Text(l10n.selectLamps),
              const SizedBox(height: 8),
              ...onlineLamps.map((lamp) {
                return CheckboxListTile(
                  title: Text(lamp.name),
                  subtitle: Text(lamp.ip),
                  value: _selectedLampIds.contains(lamp.id),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedLampIds.add(lamp.id);
                      } else {
                        _selectedLampIds.remove(lamp.id);
                      }
                    });
                  },
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed:
              _controller.text.trim().isNotEmpty && _selectedLampIds.isNotEmpty
                  ? _save
                  : null,
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// Dialog for lamp-specific settings (without delete)
class LampSettingsDialog extends StatefulWidget {
  final Lamp lamp;

  const LampSettingsDialog({super.key, required this.lamp});

  @override
  State<LampSettingsDialog> createState() => _LampSettingsDialogState();
}

class _LampSettingsDialogState extends State<LampSettingsDialog> {
  late TextEditingController _nameController;
  late int _selectedColorIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.lamp.name);
    _selectedColorIndex = LampColors.getColorIndex(widget.lamp.iconColor);
    if (_selectedColorIndex == -1) _selectedColorIndex = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop({
      'name': name,
      'color': LampColors.getColor(_selectedColorIndex),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.editLamp),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.lampName,
                hintText: l10n.lampNameHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 20),

            // Color
            Text(l10n.iconColor, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: LampColors.palette.asMap().entries.map((entry) {
                final index = entry.key;
                final color = entry.value;
                final isSelected = index == _selectedColorIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary, width: 3)
                          : Border.all(color: Colors.grey.shade300),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Empty state when no lamps found
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noLampsFound,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.pullToRefresh,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Setup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.setupLanControl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
