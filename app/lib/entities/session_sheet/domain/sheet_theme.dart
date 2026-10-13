import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_theme.freezed.dart';

/// Habillage ludique d'une technique `[Prop]` : fil rouge de ses séances.
@freezed
abstract class SheetTheme with _$SheetTheme {
  const factory SheetTheme({required String name, required String pitch}) =
      _SheetTheme;
}
