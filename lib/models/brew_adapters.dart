import 'package:hive/hive.dart';

import 'brew_model.dart';
import 'mocktail_model.dart';

/// Type id Hive. Jangan diubah setelah rilis agar data lama tetap terbaca.
abstract final class BrewTypeIds {
  static const int brewEntry = 0;
  static const int brewMethod = 1;
  static const int roastLevel = 2;
  static const int brewRecipe = 3;
  static const int brewBean = 4;
  static const int mocktailRecipe = 5;
}

/// Mendaftarkan semua adapter. Aman dipanggil berulang.
void registerBrewAdapters() {
  if (!Hive.isAdapterRegistered(BrewTypeIds.brewMethod)) {
    Hive.registerAdapter(BrewMethodAdapter());
  }
  if (!Hive.isAdapterRegistered(BrewTypeIds.roastLevel)) {
    Hive.registerAdapter(RoastLevelAdapter());
  }
  if (!Hive.isAdapterRegistered(BrewTypeIds.brewEntry)) {
    Hive.registerAdapter(BrewEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(BrewTypeIds.brewRecipe)) {
    Hive.registerAdapter(BrewRecipeAdapter());
  }
  if (!Hive.isAdapterRegistered(BrewTypeIds.brewBean)) {
    Hive.registerAdapter(BrewBeanAdapter());
  }
  if (!Hive.isAdapterRegistered(BrewTypeIds.mocktailRecipe)) {
    Hive.registerAdapter(MocktailRecipeAdapter());
  }
}

class BrewMethodAdapter extends TypeAdapter<BrewMethod> {
  @override
  final int typeId = BrewTypeIds.brewMethod;

  @override
  BrewMethod read(BinaryReader reader) {
    final int index = reader.readByte();
    return index < BrewMethod.values.length
        ? BrewMethod.values[index]
        : BrewMethod.v60;
  }

  @override
  void write(BinaryWriter writer, BrewMethod obj) =>
      writer.writeByte(obj.index);
}

class RoastLevelAdapter extends TypeAdapter<RoastLevel> {
  @override
  final int typeId = BrewTypeIds.roastLevel;

  @override
  RoastLevel read(BinaryReader reader) {
    final int index = reader.readByte();
    return index < RoastLevel.values.length
        ? RoastLevel.values[index]
        : RoastLevel.medium;
  }

  @override
  void write(BinaryWriter writer, RoastLevel obj) =>
      writer.writeByte(obj.index);
}

/// Adapter tulisan tangan (tanpa build_runner) agar proyek langsung compile.
///
/// Format: jumlah field, lalu pasangan (nomor field, nilai). Nomor field
/// bersifat permanen; field baru harus memakai nomor baru dan nilai default
/// saat dibaca supaya data lama tetap valid.
class BrewEntryAdapter extends TypeAdapter<BrewEntry> {
  @override
  final int typeId = BrewTypeIds.brewEntry;

  @override
  BrewEntry read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final int rawRating = (fields[6] as int?) ?? 1;
    return BrewEntry(
      id: fields[0] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[1] as int),
      coffeeGrams: (fields[2] as num).toDouble(),
      waterGrams: (fields[3] as num).toDouble(),
      method: (fields[4] as BrewMethod?) ?? BrewMethod.v60,
      roast: (fields[5] as RoastLevel?) ?? RoastLevel.medium,
      rating: rawRating.clamp(1, 5),
      tastingNotes: (fields[7] as String?) ?? '',
      brewSeconds: (fields[8] as int?) ?? 0,
      taste: _tasteFromIndex(fields[9] as int?),
      flavorTags: _tagsFromIndexes(fields[10] as List<dynamic>?),
      grinderSetting: (fields[11] as String?) ?? '',
      photoName: fields[12] as String?,
      beanId: fields[13] as String?,
      beanName: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BrewEntry obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(2)
      ..write(obj.coffeeGrams)
      ..writeByte(3)
      ..write(obj.waterGrams)
      ..writeByte(4)
      ..write(obj.method)
      ..writeByte(5)
      ..write(obj.roast)
      ..writeByte(6)
      ..write(obj.rating)
      ..writeByte(7)
      ..write(obj.tastingNotes)
      ..writeByte(8)
      ..write(obj.brewSeconds)
      ..writeByte(9)
      ..write(obj.taste?.index)
      ..writeByte(10)
      ..write(obj.flavorTags.map((FlavorTag t) => t.index).toList())
      ..writeByte(11)
      ..write(obj.grinderSetting)
      ..writeByte(12)
      ..write(obj.photoName)
      ..writeByte(13)
      ..write(obj.beanId)
      ..writeByte(14)
      ..write(obj.beanName);
  }
}

List<FlavorTag> _tagsFromIndexes(List<dynamic>? raw) {
  if (raw == null) {
    return const <FlavorTag>[];
  }
  return <FlavorTag>[
    for (final dynamic i in raw)
      if (i is int && i >= 0 && i < FlavorTag.values.length)
        FlavorTag.values[i],
  ];
}

/// Adapter biji kopi. Field 2–4 boleh kosong/`null`.
class BrewBeanAdapter extends TypeAdapter<BrewBean> {
  @override
  final int typeId = BrewTypeIds.brewBean;

  @override
  BrewBean read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final int? roastMs = fields[4] as int?;
    return BrewBean(
      id: fields[0] as String,
      name: (fields[1] as String?) ?? 'Biji',
      roaster: (fields[2] as String?) ?? '',
      origin: (fields[3] as String?) ?? '',
      roastDate: roastMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(roastMs),
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
    );
  }

  @override
  void write(BinaryWriter writer, BrewBean obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.roaster)
      ..writeByte(3)
      ..write(obj.origin)
      ..writeByte(4)
      ..write(obj.roastDate?.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.createdAt.millisecondsSinceEpoch);
  }
}

TasteFeedback? _tasteFromIndex(int? index) =>
    index != null && index >= 0 && index < TasteFeedback.values.length
    ? TasteFeedback.values[index]
    : null;

/// Adapter resep favorit. Field 6–9 boleh `null` (memakai bawaan metode).
class BrewRecipeAdapter extends TypeAdapter<BrewRecipe> {
  @override
  final int typeId = BrewTypeIds.brewRecipe;

  @override
  BrewRecipe read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrewRecipe(
      id: fields[0] as String,
      name: (fields[1] as String?) ?? 'Resep',
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      coffeeGrams: (fields[3] as num).toDouble(),
      method: (fields[4] as BrewMethod?) ?? BrewMethod.v60,
      roast: (fields[5] as RoastLevel?) ?? RoastLevel.medium,
      customization: BrewCustomization(
        ratio: (fields[6] as num?)?.toDouble(),
        bloomSeconds: fields[7] as int?,
        firstPourSeconds: fields[8] as int?,
        secondPourSeconds: fields[9] as int?,
      ),
    );
  }

  @override
  void write(BinaryWriter writer, BrewRecipe obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.coffeeGrams)
      ..writeByte(4)
      ..write(obj.method)
      ..writeByte(5)
      ..write(obj.roast)
      ..writeByte(6)
      ..write(obj.customization.ratio)
      ..writeByte(7)
      ..write(obj.customization.bloomSeconds)
      ..writeByte(8)
      ..write(obj.customization.firstPourSeconds)
      ..writeByte(9)
      ..write(obj.customization.secondPourSeconds);
  }
}

T _enumAt<T>(List<T> values, Object? index, T fallback) =>
    index is int && index >= 0 && index < values.length
    ? values[index]
    : fallback;

/// Adapter resep mocktail. Enum disimpan sebagai indeks, hiasan sebagai bitmask,
/// dan sirup sebagai dua daftar paralel (nama dan bagian).
class MocktailRecipeAdapter extends TypeAdapter<MocktailRecipe> {
  @override
  final int typeId = BrewTypeIds.mocktailRecipe;

  @override
  MocktailRecipe read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> f = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final List<String> names =
        (f[10] as List<dynamic>?)?.whereType<String>().toList() ?? <String>[];
    final List<int> parts =
        (f[11] as List<dynamic>?)?.whereType<int>().toList() ?? <int>[];
    final int mask = (f[12] as int?) ?? 0;
    return MocktailRecipe(
      id: f[0] as String,
      name: (f[1] as String?) ?? 'Mocktail',
      createdAt: DateTime.fromMillisecondsSinceEpoch(f[2] as int),
      spec: MocktailSpec(
        servings: ((f[3] as int?) ?? 1).clamp(
          MocktailSpec.minServings,
          MocktailSpec.maxServings,
        ),
        glassMl: ((f[4] as int?) ?? 300).clamp(
          MocktailSpec.minGlassMl,
          MocktailSpec.maxGlassMl,
        ),
        base: _enumAt(MocktailBase.values, f[5], MocktailBase.soda),
        sweetness: _enumAt(
          MocktailSweetness.values,
          f[6],
          MocktailSweetness.normal,
        ),
        method: _enumAt(MocktailMethod.values, f[7], MocktailMethod.build),
        useIce: (f[8] as bool?) ?? true,
        useCitrus: (f[9] as bool?) ?? true,
        syrups: <MocktailSyrup>[
          for (int i = 0; i < names.length; i++)
            MocktailSyrup(
              names[i],
              parts: (i < parts.length ? parts[i] : 1).clamp(
                MocktailSpec.minParts,
                MocktailSpec.maxParts,
              ),
            ),
        ],
        garnishes: <MocktailGarnish>{
          for (final MocktailGarnish g in MocktailGarnish.values)
            if (mask & (1 << g.index) != 0) g,
        },
      ),
    );
  }

  @override
  void write(BinaryWriter writer, MocktailRecipe obj) {
    final MocktailSpec s = obj.spec;
    int mask = 0;
    for (final MocktailGarnish g in s.garnishes) {
      mask |= 1 << g.index;
    }
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(s.servings)
      ..writeByte(4)
      ..write(s.glassMl)
      ..writeByte(5)
      ..write(s.base.index)
      ..writeByte(6)
      ..write(s.sweetness.index)
      ..writeByte(7)
      ..write(s.method.index)
      ..writeByte(8)
      ..write(s.useIce)
      ..writeByte(9)
      ..write(s.useCitrus)
      ..writeByte(10)
      ..write(s.syrups.map((MocktailSyrup x) => x.name).toList())
      ..writeByte(11)
      ..write(s.syrups.map((MocktailSyrup x) => x.parts).toList())
      ..writeByte(12)
      ..write(mask);
  }
}
