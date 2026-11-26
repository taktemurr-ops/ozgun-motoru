import 'core.dart';
import 'kinds/access.dart';
import 'kinds/atelier.dart';
import 'kinds/craft.dart';
import 'kinds/folk.dart';
import 'kinds/logic.dart';
import 'kinds/mech.dart';
import 'kinds/mosaic.dart';
import 'kinds/sim.dart';
import 'kinds/sky.dart';

/// Özgün oyun türleri.
const Map<String, OzgunKind> kOzgunKinds = {
  'kilim': KilimKind(),
  'cini': CiniKind(),
  'ebru': EbruKind(),
  'lale': LaleKind(),
  'kervan': KervanKind(),
  'hat': HatKind(),
  'golge': GolgeKind(),
  'mahalle': MahalleKind(),
  'disli': DisliKind(),
  'isik': IsikKind(),
  'doner': DonerKind(),
  'boya': BoyaKind(),
  'domino': DominoKind(),
  'bal': BalKind(),
  'kagit': KagitKind(),
  'akvaryum': AkvaryumKind(),
  'pazar': PazarKind(),
  'yildiz': SkyKind(),
  'tren': TrenKind(),
  'ses': SesKind(),
  'gunluk-uclu': DailyKind(),
  'mantar': MantarKind(),
  'kum': KumKind(),
  'kundekari': KundekariKind(),
  'tezhip': TezhipKind(),
  'boncuk': BoncukKind(),
  'comlek': ComlekKind(),
  'karagoz': KaraKind(),
  'hoca': HocaKind(),
  'mozrest': MozaikKind(),
};

OzgunRules ozgunRulesFor(String gameId, String kind) => ozgunRules(gameId, kOzgunKinds[kind]!);
