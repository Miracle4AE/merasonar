import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';

import 'package:flutter/material.dart';



class CaptainAtlasLiveCard extends StatelessWidget {

  const CaptainAtlasLiveCard({

    super.key,

    required this.enabled,

    required this.onAsk,

    this.lastSummary,

    this.loading = false,

  });



  final bool enabled;

  final VoidCallback? onAsk;

  final String? lastSummary;

  final bool loading;



  @override

  Widget build(BuildContext context) {

    final hasSummary = lastSummary != null && lastSummary!.trim().isNotEmpty;



    return CaptainAtlasHeroCard(

      title: kAiAssistantLiveTitle,

      body: hasSummary ? lastSummary! : kLiveCaptainEmpty,

      presence: loading

          ? CaptainAtlasPresence.thinking

          : (hasSummary

              ? CaptainAtlasPresence.responding

              : CaptainAtlasPresence.ready),

      loading: loading,

      enabled: enabled,

      actionLabel: kPremiumCaptainAskButton,

      actionKey: const Key('btn_live_ai_assistant'),

      onAsk: enabled ? onAsk : null,

    );

  }

}


