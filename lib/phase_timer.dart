import 'package:flutter/material.dart';
import 'package:zugclient/zug_area.dart';

class PhaseTimerController {
  late AnimationController phaseTimer;

  PhaseTimerController(TickerProvider tickerProvider) {
    phaseTimer = AnimationController(
        vsync: tickerProvider,
        duration: const Duration(milliseconds: 8000),
        reverseDuration: const Duration(seconds: 99999)
    );
  }

  Widget getPhaseTimerCircle({
    Area? currArea,
    double? size = 120,
    Color backgroundColor = Colors.cyanAccent,
    Color progressColor = Colors.black,
    Color textColor = Colors.black,
    double strokeWidth = 8.0,
    TextStyle? textStyle,
  }) {
    if (phaseTimer.duration?.inMilliseconds != currArea?.phaseTime) {
      phaseTimer.reset();
      if (currArea?.inPhase ?? false) {
        phaseTimer.duration = Duration(milliseconds: currArea?.phaseTime ?? 0);
        phaseTimer.repeat(reverse: true);
      }
    }

    return ValueListenableBuilder<double>(
      valueListenable: phaseTimer,
      builder: (context, value, child) {
        // Calculate remaining time
        final totalDuration = phaseTimer.duration?.inMilliseconds ?? 0;
        final remainingMs = totalDuration * (1.0 - value);
        final remainingSeconds = (remainingMs / 1000).ceil();

        Widget circularTimer = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Use the available space if size is null, otherwise use the specified size
            final effectiveSize = size ?? constraints.biggest.shortestSide;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: effectiveSize,
                  height: effectiveSize,
                  child: CircularProgressIndicator(
                    value: 1.0, // Full circle for background
                    strokeWidth: strokeWidth,
                    valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: effectiveSize,
                  height: effectiveSize,
                  child: Transform.rotate(
                    angle: -1.5708, // Start from top (-90 degrees)
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: strokeWidth,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                // Center text showing remaining seconds
                Text(
                  '$remainingSeconds',
                  style: textStyle ?? TextStyle(
                    fontSize: effectiveSize * 0.25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            );
          },
        );

        // If size is specified, wrap in a SizedBox. If null, let it expand naturally
        return size != null
            ? SizedBox(
          width: size,
          height: size,
          child: circularTimer,
        )
            : circularTimer;
      },
    );
  }

  // Keep the original linear progress bar method
  Widget getPhaseTimerBar({
    Area? currArea,
    double minHeight = 32,
    backgroundColor = Colors.cyanAccent,
    color = Colors.black
  }) {
    if (phaseTimer.duration?.inMilliseconds != currArea?.phaseTime) {
      phaseTimer.reset();
      if (currArea?.inPhase ?? false) {
        phaseTimer.duration = Duration(milliseconds: currArea?.phaseTime ?? 0);
        phaseTimer.repeat(reverse: true);
      }
    }

    return ValueListenableBuilder<double>(
      valueListenable: phaseTimer,
      builder: (context, value, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0),
          child: LinearProgressIndicator(
            value: value,
            color: color,
            backgroundColor: backgroundColor,
            minHeight: minHeight,
          ),
        );
      },
    );
  }

  void disposeTimer() {
    phaseTimer.dispose();
  }
}
