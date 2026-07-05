import 'package:deniz_app/widgets/premium/ambient/ambient_marine_background.dart';

import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';

import 'package:flutter/material.dart';



/// Ambient arka planın route değişimlerinde kesilmemesi için MaterialApp builder sarmalayıcısı.

class PremiumAmbientShell extends StatelessWidget {

  const PremiumAmbientShell({super.key, required this.child});



  final Widget child;



  @override

  Widget build(BuildContext context) {

    return Stack(

      fit: StackFit.expand,

      children: [

        AmbientMarineBackground(

          enabled: PremiumAnimationPolicy.ambientEnabled(context),

          child: const SizedBox.expand(),

        ),

        child,

      ],

    );

  }

}

