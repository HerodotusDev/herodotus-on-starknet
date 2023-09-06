#[cfg(test)]
mod binary_search {
    use option::OptionTrait;
    use core::array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto, PartialOrd};
    use debug::PrintTrait;

    fn custom_binary_search(arr: Span<u256>, x: u256) -> Option<u256> {
        let mut left: u256 = 0;
        let mut right: u256 = arr.len().into();
        loop {
            if left >= right {
                break;
            }

            let mid: u256 = (left + right) / 2;
            let mid_val: u256 = *arr.at(mid.try_into().unwrap());
            if x >= mid_val {
                left = mid + 1;
            } else {
                right = mid;
            }
            continue;
        };
        if left == 0 {
            return Option::None(());
        }
        return Option::Some(left - 1);
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_no_element() {
        let mut arr = ArrayTrait::new();
        let arr_span = arr.span();

        assert(custom_binary_search(arr_span, 43).is_none(), 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_single_element() {
        let mut arr = ArrayTrait::new();
        arr.append(42);

        let arr_span = arr.span();
        assert(custom_binary_search(arr_span, 42).unwrap() == 0, 'Unexpected result'); // Present
        assert(
            custom_binary_search(arr_span, 43).unwrap() == 0, 'Unexpected result'
        ); // Not present, larger
        assert(
            custom_binary_search(arr_span, 41).is_none(), 'Unexpected result'
        ); // Not present, smaller
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_many_elements() {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr.append(5);

        let arr_span = arr.span();
        assert(custom_binary_search(arr_span, 0).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 1).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 2).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 5).unwrap() == 4, 'Unexpected result');
        assert(custom_binary_search(arr_span, 6).unwrap() == 4, 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn text_binary_search_many_elements_with_gaps() {
        let mut arr = ArrayTrait::new();
        arr.append(3);
        arr.append(8);
        arr.append(9);
        arr.append(14);

        let arr_span = arr.span();

        // Exact match for array with gaps
        assert(custom_binary_search(arr_span, 2).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 7).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 8).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 9).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 10).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 13).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 14).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 15).unwrap() == 3, 'Unexpected result');

        // Closest to x
        assert(custom_binary_search(arr_span, 2).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 7).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 8).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 9).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 10).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 13).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 14).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 15).unwrap() == 3, 'Unexpected result');
    }

    #[available_gas(999999999999999)]
    #[test]
    fn test_binary_search_1000_elements_array() {
        let arr = array![
            3,
            4,
            5,
            6,
            7,
            9,
            10,
            11,
            12,
            13,
            14,
            18,
            20,
            23,
            24,
            26,
            29,
            30,
            31,
            32,
            33,
            36,
            37,
            38,
            41,
            42,
            44,
            45,
            47,
            48,
            51,
            53,
            54,
            57,
            58,
            59,
            60,
            61,
            62,
            63,
            65,
            66,
            67,
            68,
            70,
            74,
            75,
            76,
            77,
            79,
            81,
            85,
            87,
            89,
            90,
            91,
            93,
            94,
            95,
            96,
            97,
            98,
            99,
            100,
            102,
            103,
            105,
            109,
            111,
            114,
            117,
            118,
            119,
            121,
            122,
            123,
            124,
            126,
            128,
            130,
            133,
            134,
            135,
            136,
            137,
            138,
            140,
            142,
            143,
            144,
            145,
            146,
            147,
            148,
            150,
            151,
            152,
            153,
            154,
            155,
            157,
            162,
            164,
            165,
            167,
            168,
            169,
            170,
            173,
            174,
            175,
            176,
            178,
            179,
            180,
            181,
            183,
            185,
            186,
            189,
            190,
            194,
            196,
            197,
            198,
            199,
            203,
            205,
            206,
            208,
            209,
            210,
            211,
            213,
            217,
            218,
            219,
            220,
            224,
            225,
            227,
            228,
            229,
            230,
            233,
            234,
            235,
            236,
            239,
            240,
            241,
            243,
            244,
            247,
            248,
            250,
            251,
            252,
            254,
            255,
            256,
            260,
            261,
            262,
            263,
            264,
            265,
            270,
            271,
            272,
            273,
            274,
            278,
            280,
            285,
            286,
            287,
            288,
            289,
            290,
            291,
            292,
            293,
            296,
            297,
            299,
            301,
            302,
            303,
            304,
            305,
            306,
            307,
            308,
            309,
            310,
            311,
            312,
            313,
            314,
            317,
            321,
            322,
            325,
            327,
            328,
            330,
            331,
            332,
            333,
            336,
            337,
            338,
            340,
            342,
            343,
            344,
            347,
            349,
            350,
            351,
            352,
            353,
            355,
            357,
            358,
            359,
            360,
            361,
            362,
            365,
            366,
            369,
            370,
            371,
            372,
            373,
            375,
            376,
            377,
            378,
            381,
            382,
            385,
            386,
            387,
            388,
            389,
            390,
            391,
            392,
            396,
            402,
            403,
            404,
            405,
            408,
            410,
            412,
            413,
            414,
            416,
            417,
            418,
            421,
            423,
            424,
            426,
            427,
            428,
            429,
            430,
            431,
            432,
            433,
            434,
            435,
            439,
            442,
            443,
            444,
            446,
            447,
            448,
            449,
            450,
            451,
            452,
            455,
            456,
            457,
            458,
            460,
            461,
            462,
            463,
            464,
            465,
            467,
            468,
            473,
            474,
            475,
            479,
            480,
            482,
            484,
            485,
            486,
            488,
            489,
            490,
            491,
            492,
            494,
            496,
            498,
            499,
            503,
            504,
            505,
            507,
            508,
            509,
            510,
            511,
            514,
            515,
            520,
            521,
            523,
            524,
            526,
            527,
            528,
            529,
            530,
            531,
            532,
            533,
            534,
            535,
            536,
            537,
            539,
            540,
            542,
            543,
            544,
            546,
            547,
            551,
            552,
            553,
            556,
            558,
            559,
            561,
            565,
            566,
            567,
            568,
            570,
            571,
            572,
            575,
            577,
            578,
            580,
            581,
            582,
            583,
            584,
            585,
            586,
            587,
            588,
            590,
            591,
            595,
            601,
            602,
            603,
            604,
            605,
            606,
            607,
            608,
            610,
            617,
            619,
            620,
            621,
            622,
            623,
            624,
            625,
            626,
            627,
            630,
            631,
            632,
            637,
            638,
            640,
            641,
            642,
            644,
            645,
            646,
            647,
            648,
            649,
            650,
            651,
            652,
            654,
            657,
            659,
            660,
            662,
            663,
            664,
            665,
            667,
            669,
            670,
            671,
            672,
            673,
            675,
            676,
            677,
            678,
            680,
            682,
            683,
            684,
            685,
            686,
            688,
            690,
            691,
            693,
            696,
            697,
            698,
            700,
            701,
            705,
            706,
            707,
            708,
            709,
            713,
            715,
            716,
            717,
            718,
            719,
            721,
            722,
            723,
            725,
            727,
            728,
            730,
            733,
            734,
            735,
            738,
            739,
            740,
            741,
            742,
            743,
            744,
            745,
            746,
            747,
            748,
            750,
            751,
            752,
            755,
            756,
            757,
            758,
            760,
            761,
            762,
            764,
            765,
            766,
            767,
            769,
            770,
            772,
            773,
            774,
            775,
            777,
            778,
            780,
            781,
            782,
            783,
            785,
            786,
            787,
            789,
            790,
            791,
            793,
            794,
            796,
            797,
            798,
            799,
            800,
            802,
            807,
            808,
            809,
            810,
            811,
            812,
            815,
            816,
            819,
            820,
            821,
            822,
            827,
            830,
            831,
            833,
            834,
            835,
            837,
            840,
            841,
            844,
            845,
            846,
            847,
            848,
            849,
            850,
            851,
            852,
            853,
            854,
            856,
            857,
            858,
            859,
            860,
            862,
            863,
            865,
            866,
            867,
            868,
            869,
            870,
            871,
            872,
            874,
            877,
            878,
            879,
            882,
            883,
            884,
            886,
            887,
            888,
            889,
            890,
            891,
            892,
            894,
            897,
            898,
            899,
            900,
            901,
            903,
            905,
            907,
            910,
            914,
            915,
            917,
            918,
            919,
            920,
            922,
            923,
            924,
            926,
            930,
            931,
            933,
            936,
            937,
            938,
            939,
            940,
            941,
            942,
            943,
            944,
            946,
            947,
            948,
            949,
            950,
            951,
            952,
            955,
            956,
            957,
            958,
            960,
            961,
            963,
            964,
            967,
            969,
            970,
            972,
            973,
            977,
            978,
            979,
            980,
            981,
            983,
            984,
            987,
            989,
            991,
            992,
            993,
            995,
            997,
            999
        ];

        let arr_span = arr.span();

        // Test for a number that is present in the array
        assert(custom_binary_search(arr_span, 10).unwrap() == 6, 'Unexpected result');

        // Test for a number that is between two elements, expecting the index of the number on the left
        assert(custom_binary_search(arr_span, 8).unwrap() == 4, 'Unexpected result');

        // Test for a number smaller than the smallest number in the array
        assert(custom_binary_search(arr_span, 2).is_none(), 'Unexpected result');

        // Test for a number larger than the largest number in the array
        assert(
            custom_binary_search(arr_span, 1000).unwrap() == arr.len().into() - 1,
            'Unexpected result'
        );

        // Test for a number that's close to the middle
        assert(custom_binary_search(arr_span, 500).unwrap() == 317, 'Unexpected result');

        // Test for the first number in the array
        assert(custom_binary_search(arr_span, 3).unwrap() == 0, 'Unexpected result');

        // Test for the last number in the array
        assert(
            custom_binary_search(arr_span, 999).unwrap() == arr.len().into() - 1,
            'Unexpected result'
        );

        // Test for boundary cases
        assert(
            custom_binary_search(arr_span, 4).unwrap() == 1, 'Unexpected result'
        ); // Second smallest
        assert(
            custom_binary_search(arr_span, 998).unwrap() == arr.len().into() - 2,
            'Unexpected result'
        ); // Second largest

        let middle_index: u32 = arr.len() / 2;
        assert(
            custom_binary_search(arr_span, *arr.at(middle_index)).unwrap() == middle_index.into(),
            'Unexpected result'
        ); // Middle of the array

        // Test arbitrary cases
        assert(custom_binary_search(arr_span, 16).unwrap() == 10, 'Unexpected result');
        assert(custom_binary_search(arr_span, 200).unwrap() == 125, 'Unexpected result');

        // Test all present elements
        let mut idx: u32 = 0;
        loop {
            if idx == arr.len() {
                break;
            }

            assert(
                custom_binary_search(arr_span, *arr.at(idx)).unwrap() == idx.into(),
                'Unexpected result'
            );

            idx += 1;
        }
    }
}
