import 'package:flutter/material.dart';
import 'package:zugclient/zug_app.dart';
import 'package:zugclient/zug_model.dart';

class ZugNavBar extends StatefulWidget {
  final ZugModel model;
  final List<ZugPage> pages;
  final Decoration? decoration;
  final Color? iconColor, indicatorColor, tintColor;
  final Axis orientation;

  const ZugNavBar({super.key, required this.pages, required this.model,
    this.decoration = const BoxDecoration(color: Colors.black),
    this.iconColor = Colors.white,
    this.indicatorColor = Colors.grey,
    this.tintColor = Colors.cyanAccent,
    this.orientation = Axis.vertical
  });

  @override
  State<StatefulWidget> createState() => _ZugNavBarState();

}

class _ZugNavBarState extends State<ZugNavBar> {

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.decoration,
      child: ValueListenableBuilder<Enum>(
        valueListenable: widget.model.pageNotifier,
        builder: (context, pageType, _) {
          final visibleItems = widget.pages
              .where((item) => item.isVisible(widget.model))
              .toList();

          // Find selected index safely
          int selectedIndex =
          visibleItems.indexWhere((item) => item.type == pageType);
          final noSelection = selectedIndex == -1 && visibleItems.isNotEmpty;
          if (noSelection) {
            selectedIndex = 0;
            // Optional: auto-correct invalid page (currently breaks when pages don't always use a navbar)
            //WidgetsBinding.instance.addPostFrameCallback((_) { //widget.model.gotoPage(visibleItems.first.type); });
          }

          return Theme(
            data: Theme.of(context).copyWith(
              navigationBarTheme: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.all(
                  TextStyle(color: widget.iconColor),
                ),
              ),
            ),
            child: widget.orientation == Axis.horizontal
                ? NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: noSelection ? Colors.transparent : widget.indicatorColor,
              surfaceTintColor: widget.tintColor,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  widget.model.gotoPage(visibleItems[index].type),
              destinations: visibleItems
                  .map((p) => NavigationDestination(icon: p.icon, label: p.label))
                  .toList(),
            )
                : NavigationRail(
              backgroundColor: Colors.transparent,
              indicatorColor:  noSelection ? Colors.transparent : widget.indicatorColor,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  widget.model.gotoPage(visibleItems[index].type),
              destinations: visibleItems.map((p) {
                return NavigationRailDestination(
                  icon: p.icon,
                  label: Text(p.label),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
