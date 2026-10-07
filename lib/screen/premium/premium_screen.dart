import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../helper/global.dart';
import '../../controllers/premium_controller.dart';
import '../../helper/iap.dart';
import '../../helper/my_dialogs.dart';
import '../../helper/razorpay_helper.dart';
import '../../widget/button/image_btn.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _c = PremiumController();

  // 0: India (Razorpay/UPI), 1: Abroad (Google Play)
  int _selectedRegion = 0;

  @override
  void initState() {
    super.initState();
    _c.initData();
    RazorpayHelper.init();

    // Auto-detect country: default to India if locale or timezone indicates India
    final country = Get.deviceLocale?.countryCode?.toUpperCase();
    final isIndia = country == 'IN' ||
        DateTime.now().timeZoneOffset == const Duration(hours: 5, minutes: 30);
    _selectedRegion = isIndia ? 0 : 1;
  }

  @override
  void dispose() {
    RazorpayHelper.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          //
          ListView(
            physics: const BouncingScrollPhysics(),
            padding:
                EdgeInsets.only(top: mq.height * .04, bottom: mq.height * .1),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  //
                  Lottie.asset('assets/lottie/crown_badge.json',
                      width: mq.width * .3),

                  //
                  SizedBox(
                    width: mq.width * .6,
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Go Premium',
                              style: TextStyle(
                                  color: pColor,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w500)),

                          //
                          Padding(
                            padding: EdgeInsets.only(left: 3, top: 10),
                            child: Text(
                                'For Unlimited Language Translation Services!',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 15)),
                          )
                        ]),
                  )
                ],
              ),

              SizedBox(height: mq.height * .03),

              Align(
                child: Image.asset('assets/images/premium_features.webp',
                    width: mq.width * .85),
              ),

              SizedBox(height: mq.height * .02),

              Obx(() => Column(
                    children: [
                      // Region Selector (India / Abroad)
                      if (IAP.isPurchased.isFalse) _regionSelector(),

                      Stack(
                        children: [
                          //
                          Container(
                              constraints: const BoxConstraints(minHeight: 150),
                              margin: EdgeInsets.only(
                                  top: mq.height * .01,
                                  bottom: mq.height * .02,
                                  left: mq.width * .05,
                                  right: mq.width * .05),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 18),
                              decoration: BoxDecoration(
                                  color: pColor.withOpacity(.12),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(20))),
                              child: IAP.isPurchased.value
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.verified_rounded,
                                            color: pColor, size: 28),
                                        SizedBox(width: 8),
                                        Text(
                                          'You\'re a Premium User',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: pColor,
                                          ),
                                        ),
                                      ],
                                    )
                                  : _selectedRegion == 0
                                      ? _indiaCard()
                                      : _abroadCard()),

                          //
                          if (IAP.isPurchased.isFalse)
                            Positioned(
                                top: -13,
                                right: mq.width * .04,
                                child: Lottie.asset('assets/lottie/offer.json',
                                    height: 80))
                        ],
                      ),

                      // Buy Button
                      if (IAP.isPurchased.isFalse)
                        Align(
                            child: ImageBtn(
                                onTap: _onBuyPressed,
                                text: _selectedRegion == 0
                                    ? 'Pay with Razorpay'
                                    : 'Buy with Google Play',
                                showArrow: true,
                                width: mq.width * .65)),

                      // Continue with Ads
                      IAP.isPurchased.isTrue
                          ? const SizedBox(height: 15)
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: mq.height * .02),
                              child: GestureDetector(
                                onTap: Get.back,
                                child: const Text(
                                  'Continue with Ads',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.transparent,
                                    shadows: [
                                      Shadow(
                                          offset: Offset(0, -2), color: pColor)
                                    ],
                                    decoration: TextDecoration.underline,
                                    decorationStyle: TextDecorationStyle.solid,
                                    decorationColor: pColor,
                                  ),
                                ).animate().fade(
                                    curve: Curves.easeIn,
                                    duration: const Duration(seconds: 4)),
                              ),
                            )
                    ],
                  )),

              //
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '$appName ',
                    style: TextStyle(fontSize: 13),
                  ),

                  //
                  GestureDetector(
                      onTap: () => MyDialogs.info(msg: todo),
                      child: const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w500),
                      )),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'and ',
                    style: TextStyle(fontSize: 13),
                  ),

                  //
                  GestureDetector(
                      onTap: () => launchUrlString(
                          'https://clipcraftcreations.blogspot.com/p/privacy-policy.html',
                          mode: LaunchMode.externalApplication),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w500),
                      )),
                ],
              ),
              SizedBox(
                height: mq.height / 30,
              ),
            ],
          ),

          //
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: Get.back,
              icon: const Icon(CupertinoIcons.clear_circled_solid,
                  size: 30, color: pColor),
            ).animate().fade(
                curve: Curves.easeIn, duration: const Duration(seconds: 4)),
          ),
        ],
      ),
    );
  }

  void _onBuyPressed() {
    if (_selectedRegion == 0) {
      // Razorpay for India
      RazorpayHelper.openCheckout(
        amountInPaise: 10000, // ₹100.00
        name: appName,
        description: 'Lifetime Premium Access (No Ads)',
      );
    } else {
      // Google Play Billing for abroad
      _c.purchase();
    }
  }

  Widget _regionSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mq.width * .06, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRegion = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedRegion == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedRegion == 0
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇮🇳 ', style: TextStyle(fontSize: 15)),
                    Text(
                      'India (Razorpay)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedRegion == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedRegion == 0 ? pColor : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRegion = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedRegion == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedRegion == 1
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌐 ', style: TextStyle(fontSize: 15)),
                    Text(
                      'Abroad (Play Store)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedRegion == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedRegion == 1 ? pColor : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // India Plan (Razorpay: UPI, Cards, Netbanking)
  Widget _indiaCard() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '₹100.00',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.30,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '₹200.00',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                    letterSpacing: -0.30,
                  ),
                ),
              ]),

              SizedBox(
                width: mq.width * .45,
                child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One Time Pay',
                        style: TextStyle(
                          color: pColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Lifetime access of Translation features without any Ads.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: pColor),
                SizedBox(width: 5),
                Text(
                  'UPI · Google Pay · PhonePe · Paytm · Cards · Razorpay',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: pColor),
                ),
              ],
            ),
          )
        ],
      );

  // Abroad Plan (Google Play Billing)
  Widget _abroadCard() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  _c.product.value.price.isNotEmpty &&
                          _c.product.value.price != '... '
                      ? _c.product.value.price
                      : '\$1.99',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.30,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _c.product.value.rawPrice != 0
                      ? '\$${(_c.product.value.rawPrice * 2).toStringAsFixed(2)}'
                      : '\$3.99',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                    letterSpacing: -0.30,
                  ),
                ),
              ]),

              SizedBox(
                width: mq.width * .45,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _c.product.value.title.isNotEmpty
                            ? _c.product.value.title.split('(')[0]
                            : 'One Time Pay',
                        style: const TextStyle(
                          color: pColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _c.product.value.description.isNotEmpty
                            ? _c.product.value.description
                            : 'Lifetime access of Translation features without any Ads.',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: pColor),
                SizedBox(width: 5),
                Text(
                  'Google Play Store Billing · International Cards · PayPal',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: pColor),
                ),
              ],
            ),
          )
        ],
      );
}
