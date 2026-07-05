import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/theme/app_colors.dart';

import 'package:deniz_app/theme/app_spacing.dart';

import 'package:deniz_app/widgets/premium/premium_dock_item.dart';

import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';

import 'package:flutter/material.dart';



class MissionQuickActionDock extends StatelessWidget {

  const MissionQuickActionDock({

    super.key,

    required this.onMapTap,

    required this.onMarineTap,

    required this.onLiveTap,

    required this.onCompareTap,

    required this.onCaptainTap,

    this.sticky = false,

  });



  final VoidCallback onMapTap;

  final VoidCallback onMarineTap;

  final VoidCallback onLiveTap;

  final VoidCallback onCompareTap;

  final VoidCallback onCaptainTap;

  final bool sticky;



  @override

  Widget build(BuildContext context) {

    final dock = RepaintBoundary(

      child: Semantics(

        container: true,

        label: 'Hızlı aksiyonlar',

        child: PremiumGlassPanel(

          blur: sticky ? 14 : 12,

          padding: const EdgeInsets.symmetric(

            horizontal: AppSpacing.sm,

            vertical: AppSpacing.sm,

          ),

          child: SingleChildScrollView(

            scrollDirection: Axis.horizontal,

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [

                PremiumDockItem(

                  key: const Key('btn_photo_analysis'),

                  icon: Icons.map_outlined,

                  label: kMissionDockMap,

                  onPressed: onMapTap,

                ),

                PremiumDockItem(

                  key: const Key('btn_marine_analysis'),

                  icon: Icons.analytics_outlined,

                  label: kMissionDockMarine,

                  onPressed: onMarineTap,

                ),

                PremiumDockItem(

                  key: const Key('btn_live_area'),

                  icon: Icons.sensors_rounded,

                  label: kMissionDockLive,

                  onPressed: onLiveTap,

                  accent: true,

                ),

                PremiumDockItem(

                  icon: Icons.compare_arrows_rounded,

                  label: kMissionDockCompare,

                  onPressed: onCompareTap,

                ),

                Semantics(

                  button: true,

                  label: kMissionDockCaptain,

                  child: PremiumDockItem(

                    key: const Key('btn_captain_atlas'),

                    icon: Icons.auto_awesome_rounded,

                    label: kMissionDockCaptain,

                    onPressed: onCaptainTap,

                    accent: true,

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );



    if (!sticky) {

      return Padding(

        padding: const EdgeInsets.only(top: AppSpacing.sectionGap),

        child: dock,

      );

    }



    return Material(

      color: Colors.transparent,

      child: Container(

        decoration: BoxDecoration(

          border: Border(

            top: BorderSide(color: AppColors.borderCyan.withValues(alpha: 0.2)),

          ),

        ),

        padding: EdgeInsets.fromLTRB(

          AppSpacing.md,

          AppSpacing.sm,

          AppSpacing.md,

          AppSpacing.sm + MediaQuery.paddingOf(context).bottom,

        ),

        child: dock,

      ),

    );

  }

}

