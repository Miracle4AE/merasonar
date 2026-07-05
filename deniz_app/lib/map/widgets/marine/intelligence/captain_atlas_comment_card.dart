import 'package:deniz_app/domain/marine_intelligence_report.dart';

import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';

import 'package:deniz_app/widgets/premium/premium_status_badge.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';



class CaptainAtlasCommentCard extends StatelessWidget {

  const CaptainAtlasCommentCard({

    super.key,

    this.comment,

    required this.onAskCaptain,

    this.loading = false,

    this.enabled = true,

  });



  final MarineAiComment? comment;

  final VoidCallback? onAskCaptain;

  final bool loading;

  final bool enabled;



  String get _sourceLabel {

    if (comment == null) return kMarineNoData;

    return comment!.isFallback ? kMarineAiSourceFallback : kMarineAiSourceAi;

  }



  String get _body {

    if (comment?.isFallback == true) {

      return kMarineAiCommentFallbackBanner;

    }

    if (comment != null && comment!.summaryTr.isNotEmpty) {

      return comment!.summaryTr;

    }

    return kMarinePremiumCaptainEmpty;

  }



  CaptainAtlasPresence get _presence {

    if (loading) return CaptainAtlasPresence.thinking;

    if (comment != null && comment!.summaryTr.isNotEmpty) {

      return CaptainAtlasPresence.responding;

    }

    return CaptainAtlasPresence.ready;

  }



  @override

  Widget build(BuildContext context) {

    final badges = <Widget>[

      PremiumStatusBadge(label: kMarineCaptainAtlasChip),

      if (comment != null && comment!.personaVersion.isNotEmpty)

        PremiumStatusBadge(

          label: comment!.personaVersion,

          tone: PremiumStatusTone.neutral,

        ),

      PremiumStatusBadge(

        label: '$kMarinePremiumSourceLabel $_sourceLabel',

        tone: comment?.isFallback == true

            ? PremiumStatusTone.warning

            : PremiumStatusTone.success,

      ),

    ];



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        CaptainAtlasHeroCard(

          title: kMarineSectionAiComment,

          body: _body,

          presence: _presence,

          loading: loading,

          enabled: enabled,

          badges: badges,

          actionLabel: kMarineFetchAiCommentButton,

          onAsk: (!enabled || loading) ? null : onAskCaptain,

        ),

        if (comment?.isFallback == true) ...[
          if (kDebugMode &&
              comment!.fallbackReason != null &&
              comment!.fallbackReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                kAiAssistantFallbackReasonDebug(comment!.fallbackReason),
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
        if (comment?.bestTimeWindowTr != null &&
            comment!.bestTimeWindowTr!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$kMarineAiBestTimeLabel: ${comment!.bestTimeWindowTr}',
            style: AppTextStyles.caption,
          ),
        ],

      ],

    );

  }

}


