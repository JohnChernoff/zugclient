import 'package:flutter/foundation.dart';
import "package:universal_html/html.dart" as html;
import 'package:flutter/material.dart';
import 'package:zug_utils/zug_utils.dart';
import 'package:zugclient/zug_area.dart';
import 'package:zugclient/zug_chat.dart';
import 'package:zugclient/zug_fields.dart';
import 'package:zugclient/zug_model.dart';
import 'package:zugclient/zug_user.dart';

enum LobbyStyle { normal, terseLand, tersePort }

class LobbyPage extends StatefulWidget {
  final ZugModel model;
  final String areaName;
  final Color? bkgCol;
  final Color? buttonsBkgCol;
  final ImageProvider? backgroundImage;
  final LobbyStyle style;
  final double? width;
  final double borderWidth;
  final Color borderCol;
  final ZugChat? zugChat;
  final bool seekButt, createButt, startButt, joinButt, partButt;
  final int portFlex;
  final double commandAreaWidth, commandAreaHeight;
  final bool showSelector;

  const LobbyPage(this.model, {
    this.backgroundImage,
    this.areaName = "Area",
    this.bkgCol,
    this.buttonsBkgCol,
    this.style = LobbyStyle.normal,
    this.width,
    this.borderWidth = 0,
    this.borderCol = Colors.black,
    this.zugChat,
    this.seekButt = true,
    this.createButt = true,
    this.startButt = true,
    this.joinButt = true,
    this.partButt = true,
    this.portFlex = 2,
    this.commandAreaHeight = 80,
    this.commandAreaWidth = 140,
    this.showSelector = true,
    super.key
  });

  Widget? selectorWidget() {
    return null;
  }

  Widget selectedArea(BuildContext context, {Color? bkgCol, Color? txtCol, Iterable<dynamic>? occupants}) {
    Iterable<dynamic> occupantList = occupants ?? model.currentArea.occupantMap.values;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bkgCol?.withOpacity(0.8) ?? Theme.of(context).colorScheme.surface.withOpacity(0.8),
            bkgCol?.withOpacity(0.95) ?? Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Players in ${model.currentArea.id}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "${occupantList.length}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Player list
            Expanded(
              child: occupantList.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: occupantList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  UniqueName uName = UniqueName.fromData(occupantList.elementAt(index)[fieldUser]);
                  return _buildOccupantCard(context, uName, occupantList.elementAt(index));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No players in this area",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupantCard(BuildContext context, UniqueName uName, Map<String, dynamic> json) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Handle player tap if needed
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.currentArea.getOccupantName(uName),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Online",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action button
              IconButton(
                onPressed: () {
                  // Handle player action
                },
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getAreaItem(String? title, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title ?? "",
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  int compareAreas(Area? a, Area? b) {
    if (a == null || b == null) return 0;
    return a.id.compareTo(b.id);
  }

  Widget getHelp(BuildContext context, Widget buttons) {
    return buttons;
  }

  CommandButtonData getHelpButton(String helpPage, {Color normCol = Colors.cyan}) {
    return CommandButtonData("Help", normCol, Icons.help_outline, () {
      if (kIsWeb) {
        html.window.open(helpPage, 'new tab');
      } else {
        ZugUtils.launch(helpPage, isNewTab: true);
      }
    });
  }

  CommandButtonData getSeekButton({Color normCol = Colors.orangeAccent}) {
    return CommandButtonData("Seek", normCol, Icons.search, model.seekArea);
  }

  CommandButtonData getJoinButton({Color normCol = Colors.blueAccent}) {
    return CommandButtonData("Join", normCol, Icons.login, () => model.joinArea(model.currentArea.id));
  }

  CommandButtonData getPartButton({Color normCol = Colors.grey}) {
    return CommandButtonData("Leave", normCol, Icons.logout, model.partArea);
  }

  CommandButtonData getStartButton({Color normCol = Colors.redAccent}) {
    return CommandButtonData("Start", normCol, Icons.play_arrow, model.startArea);
  }

  CommandButtonData getCreateButton({Color normCol = Colors.greenAccent}) {
    return CommandButtonData("New", normCol, Icons.add, model.newArea);
  }

  List<CommandButtonData> getExtraCmdButtons(BuildContext context) {
    return [];
  }

  @override
  State<StatefulWidget> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget getMainArea(BuildContext context) {
    Set<DropdownMenuItem<String>> areaSet = {};
    areaSet.addAll(widget.model.areas.keys
        .where((key) => widget.model.areas[key]?.exists ?? false)
        .map<DropdownMenuItem<String>>((String title) {
      return DropdownMenuItem<String>(
        value: title,
        child: widget.getAreaItem(title, context),
      );
    }).toList());

    List<DropdownMenuItem<String>> areas = areaSet.toList();
    areas.sort((a, b) => widget.compareAreas(
        widget.model.areas[a.value], widget.model.areas[b.value]));

    String selectedTitle = widget.model.currentArea.exists
        ? widget.model.currentArea.id
        : widget.model.noArea.id;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        gradient: widget.backgroundImage == null ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.bkgCol ?? Theme.of(context).colorScheme.surface,
            (widget.bkgCol ?? Theme.of(context).colorScheme.surface).withOpacity(0.8),
          ],
        ) : null,
        border: Border.all(color: widget.borderCol, width: widget.borderWidth),
        image: widget.backgroundImage != null
            ? DecorationImage(
          image: widget.backgroundImage!,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3),
            BlendMode.darken,
          ),
        )
            : null,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Command area
            widget.style == LobbyStyle.tersePort
                ? Expanded(flex: widget.portFlex, child: getCommandArea(context))
                : getCommandArea(context),

            // Area selector
            if (widget.showSelector) widget.selectorWidget() ?? Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Select ${widget.areaName}:",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          value: selectedTitle,
                          items: areas,
                          icon: Icon(
                            Icons.expand_more,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onChanged: (String? title) {
                            setState(() {
                              widget.model.switchArea(title);
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selected area display
            Expanded(flex: 1, child: widget.selectedArea(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) => Flex(
        direction: widget.style == LobbyStyle.tersePort ? Axis.vertical : Axis.horizontal,
        children: [
          SizedBox(
            width: widget.style == LobbyStyle.tersePort
                ? null
                : constraints.maxWidth * .75,
            height: widget.style == LobbyStyle.tersePort
                ? constraints.maxHeight / 2
                : null,
            child: getMainArea(context),
          ),
          Expanded(
            flex: 1,
            child: widget.zugChat ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget getCommandArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.buttonsBkgCol?.withOpacity(0.9) ??
                Theme.of(context).colorScheme.surface.withOpacity(0.9),
            widget.buttonsBkgCol?.withOpacity(0.95) ??
                Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      width: widget.style == LobbyStyle.tersePort ? widget.commandAreaWidth : null,
      height: widget.style == LobbyStyle.tersePort ? null : widget.commandAreaHeight,
      child: EqualButtonRow(buttData: getCmdButtons(context)),
    );
  }

  List<CommandButtonData?> getCmdButtons(BuildContext context, {
    double padding = 4.0,
    CommandButtonData? seekButt,
    CommandButtonData? createButt,
    CommandButtonData? startButt,
    CommandButtonData? joinButt,
    CommandButtonData? partButt,
    CommandButtonData? helpButt,
    List<CommandButtonData>? extraButts,
  }) {
    List<CommandButtonData> extraList = extraButts ?? widget.getExtraCmdButtons(context);
    List<CommandButtonData?> buttons = [
      widget.seekButt ? widget.getSeekButton() : null,
      widget.createButt ? widget.getCreateButton() : null,
      widget.startButt ? widget.getStartButton() : null,
      widget.joinButt ? widget.getJoinButton() : null,
      widget.partButt ? widget.getPartButton() : null,
    ];
    buttons.addAll(extraList);
    return buttons;
  }
}

class CommandButtonData {
  final String text;
  final VoidCallback callback;
  final Color color;
  final IconData icon;

  const CommandButtonData(this.text, this.color, this.icon, this.callback);
}

class EqualButtonRow extends StatelessWidget {
  final List<CommandButtonData?> buttData;
  final TextStyle textStyle;
  final double spacing;

  const EqualButtonRow({
    Key? key,
    required this.buttData,
    this.textStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    this.spacing = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final validButtons = buttData.where((button) => button != null).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.center,
            children: validButtons.map((buttonData) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: _ModernButton(
                  buttonData: buttonData!,
                  textStyle: textStyle,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ModernButton extends StatefulWidget {
  final CommandButtonData buttonData;
  final TextStyle textStyle;

  const _ModernButton({
    required this.buttonData,
    required this.textStyle,
  });

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered
                    ? isDark ? [
                  widget.buttonData.color.withOpacity(0.95),
                  widget.buttonData.color.withOpacity(0.8),
                ] : [
                  widget.buttonData.color.withOpacity(0.9),
                  widget.buttonData.color.withOpacity(0.7),
                ]
                    : isDark ? [
                  widget.buttonData.color.withOpacity(0.9),
                  widget.buttonData.color.withOpacity(0.7),
                ] : [
                  widget.buttonData.color.withOpacity(0.8),
                  widget.buttonData.color.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: isDark && _isHovered ? Border.all(
                color: widget.buttonData.color.withOpacity(0.6),
                width: 1,
              ) : null,
              boxShadow: _isHovered
                  ? [
                BoxShadow(
                  color: widget.buttonData.color.withOpacity(isDark ? 0.5 : 0.4),
                  blurRadius: isDark ? 16 : 12,
                  offset: const Offset(0, 6),
                ),
              ]
                  : [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: isDark ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.buttonData.callback,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.buttonData.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.buttonData.text,
                    style: widget.textStyle.copyWith(
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}