import 'package:flutter/material.dart';
import 'models.dart';

class GroupData {
  static final List<KPopGroup> allGroups = [
    // 1. SEVENTEEN
    KPopGroup(
      id: 'svt',
      name: 'SEVENTEEN',
      logoPath: 'assets/svt_logo.jpg',
      themeColors: [const Color(0xFFF7CAC9), const Color(0xFF92A8D1)],
      shareTag: '#Going_Seventeen',
      playlistConfigs: {
        'Going': [
          'PLk_UmMfvZDx21Z9eEQ9DcIlUfZp1uwEup', // 最新 GOING 系列
          'PLk_UmMfvZDx2-r7Kt-k2GjtQcTecKAB6p', // 2019 系列
          'PLk_UmMfvZDx1Ug2GQ5NCijKz7Q3pmZLlT', // 2020 系列
        ],
      },
    ),
    // 2. BTS
    KPopGroup(
      id: 'bts',
      name: 'BTS',
      logoPath: 'assets/BTS_logo.png',
      themeColors: [const Color(0xFFB37EB5), const Color(0xFF87588E)],
      shareTag: '#runbts',
      playlistConfigs: {
        'Run': [
          'PL5hrGMysD_GsFYwSFDWDyUApfpHEwTDhE', // 官方 RUN BTS 完整清單
        ],
      },
    ),
  ];
}