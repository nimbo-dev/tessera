import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Logo de Tessera dibujado como widget (no imagen), para que se adapte solo
/// al tema claro/oscuro. Las teselas cian forman una "T".
class TesseraLogo extends StatelessWidget {
  final double scale;
  final bool showSubtitle;
  const TesseraLogo({super.key, this.scale = 1, this.showSubtitle = true});

  // Rejilla 4×4: true = tesela rellena. Forma una "T".
  static const _grid = [
    [true, true, true, true],
    [false, true, true, false],
    [false, true, true, false],
    [false, true, true, false],
  ];

  @override
  Widget build(BuildContext context) {
    final cell = 15.0 * scale;
    final gap = 4.0 * scale;

    final tiles = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < _grid.length; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == _grid.length - 1 ? 0 : gap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int c = 0; c < _grid[r].length; c++)
                  Container(
                    width: cell,
                    height: cell,
                    margin: EdgeInsets.only(
                        right: c == _grid[r].length - 1 ? 0 : gap),
                    decoration: BoxDecoration(
                      color: _grid[r][c]
                          ? AppTheme.accent
                          : AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(cell * 0.28),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        tiles,
        SizedBox(width: 18 * scale),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TESSERA',
              style: TextStyle(
                fontSize: 32 * scale,
                fontWeight: FontWeight.w800,
                letterSpacing: 2 * scale,
                color: AppTheme.textPrimary,
              ),
            ),
            if (showSubtitle) ...[
              SizedBox(height: 4 * scale),
              Text(
                'Fichaje automático · Séneca',
                style: TextStyle(
                  fontSize: 11 * scale,
                  letterSpacing: 0.3,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
