/// UI-8 shared element / Hero tag sabitleri.
abstract final class PremiumHeroTags {
  static const captainAvatar = 'hero_captain_avatar';
  static const goScore = 'hero_go_score';
  static const compare = 'hero_compare';

  static String hotspot(int id) => 'hero_hotspot_$id';
  static String savedSpot(String id) => 'hero_saved_spot_$id';
}
