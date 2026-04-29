import 'package:flutter/material.dart';
import 'models.dart';

class GroupData {
  static final List<String> seventeenMembers = [
    'S.COUPS', 'JEONGHAN', 'JOSHUA', 'JUN', 'HOSHI', 'WONWOO', 'WOOZI', 
    'THE8', 'MINGYU', 'DK', 'SEUNGKWAN', 'VERNON', 'DINO'
  ];

  static final List<KPopGroup> allGroups = [
    // 1. SEVENTEEN 成為唯一的主角
    KPopGroup(
      id: 'svt',
      name: 'SEVENTEEN',
      logoPath: 'assets/svt_logo.jpg',
      themeColors: [const Color(0xFFF7CAC9), const Color(0xFF92A8D1)], // 石英粉與寧靜藍
      shareTag: '#going_seventeen',
      playlistConfigs: {
        'Going 2024': [
          'PLk_UmMfvZDx21Z9eEQ9DcIlUfZp1uwEup', // 2024
        ],
        'Going 2023': [
          'PLk_UmMfvZDx2-r7Kt-k2GjtQcTecKAB6p', // 2023
        ],
        'Going 2022': [
          'PLk_UmMfvZDx1Ug2GQ5NCijKz7Q3pmZLlT', // 2022
        ],
        'Going 2021': [
          'PLk_UmMfvZDx12H_R696r0Nf_xG0T-uS4D', // 2021
        ],
        'Going 2020': [
          'PLk_UmMfvZDx2f_f-0L6i9A37S4fW_O35V', // 2020 Part 1
          'PLk_UmMfvZDx3Xk-fC1-5G6438DIBI5h-R', // 2020 Part 2
        ],
      },
    ),
  ];
}
