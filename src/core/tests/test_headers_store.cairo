// SPDX-License-Identifier: GPL-3.0

use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher, IHeadersStoreSafeDispatcherTrait,
    IHeadersStoreSafeDispatcher
};
use herodotus_eth_starknet::core::common::{MmrSize, MmrId};
use starknet::ContractAddress;
use cairo_lib::utils::types::words64::Words64;
use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
use debug::PrintTrait;

const COMMITMENTS_INBOX_ADDRESS: felt252 = 0x123;
const MMR_INITIAL_ELEMENT: felt252 =
    0x02241b3b7f1c4b9cf63e670785891de91f7237b1388f6635c1898ae397ad32dd;
const MMR_INITIAL_ROOT: felt252 = 0x6759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

fn helper_create_headers_store() -> (IHeadersStoreDispatcher, ContractAddress) {
    let contract = declare("HeadersStore").unwrap();
    let (contract_address, _) = contract.deploy(@array![COMMITMENTS_INBOX_ADDRESS]).unwrap();
    (IHeadersStoreDispatcher { contract_address }, contract_address)
}

fn helper_create_safe_headers_store() -> (IHeadersStoreSafeDispatcher, ContractAddress) {
    let contract = declare("HeadersStore").unwrap();
    let (contract_address, _) = contract.deploy(@array![COMMITMENTS_INBOX_ADDRESS]).unwrap();
    (IHeadersStoreSafeDispatcher { contract_address }, contract_address)
}

fn helper_receive_hash(
    blockhash: u256,
    block_number: u256,
    dispatcher: IHeadersStoreDispatcher,
    contract_address: ContractAddress
) {
    start_prank(CheatTarget::One(contract_address), COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());
    dispatcher.receive_hash(blockhash, block_number);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_header_block_1() {
    let headers_rlp = array![
        array![
            0x64dd60e4a0fc01f9,
            0x4c54f284013c491f,
            0xcf69fedcb4e3cf9b,
            0x0d1b29ed8a4f05a8,
            0x4dcc1da05e02a0dd,
            0xb585ab7a5dc7dee8,
            0x4512d31ad4ccb667,
            0x42a1f013748a941b,
            0x0042944793d440fd,
            0x0000000000000000,
            0x0000000000000000,
            0xedfc36fc32a01100,
            0x9319629f76c5000d,
            0x2a57fdbe486254cd,
            0x3dc181f13929b4f5,
            0xb5350f77a0c70890,
            0x58aff8b90f301ca1,
            0x2a7c97ac1a555144,
            0x27ab16def38f5914,
            0x82468fa0ce42063b,
            0x7bf6ce1c3a5b5782,
            0xb7e9521cac238426,
            0x697018cba3bda32c,
            0x0001b93b44a845dd,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x8280c3c901840280,
            0x80b0dbd6648429b7,
            0x5c67599946e432a0,
            0xa80937f4a9d1d3ee,
            0xf84428719d685d05,
            0x289ef4c9db34aa20,
            0x000000000000886c,
            0x555e4239840000
        ]
            .span(),
        array![
            0xffe62d10a0fc01f9,
            0x48b5b8c90c4801b0,
            0xe46af4d44cc305fd,
            0xea90db93937591aa,
            0x4dcc1da07d880904,
            0xb585ab7a5dc7dee8,
            0x4512d31ad4ccb667,
            0x42a1f013748a941b,
            0x0042944793d440fd,
            0x0000000000000000,
            0x0000000000000000,
            0x8350600f4ca01100,
            0x56f3150a8a78d66f,
            0x73d2b84cef2d199b,
            0x42bed64a1ea39943,
            0xc494f04da0dcb31e,
            0xb948bfaaea99f413,
            0x5c0bb3233cd8d16f,
            0x2d6bc9f9efa595ec,
            0x5d713ca075e82e5d,
            0xde6fd4cc97256dd9,
            0x5b0a3eb1e4a56d04,
            0xc9e63e0cf62f0a7d,
            0x0001b9ea0096ee2f,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x0000000000000000,
            0x8280c3c901840180,
            0x80aedbd66484f5f9,
            0x5c67599946e432a0,
            0xa80937f4a9d1d3ee,
            0xf84428719d685d05,
            0x289ef4c9db34aa20,
            0x000000000000886c,
            0x009d693a840000
        ]
            .span()
    ]
        .span();

    let mut mmr = MMRTrait::new(
        root: 0x78ece8884698aadc91f067cf2d0d54a955e458ab6cd2ebc18fe815a3aafb43, last_pos: 263
    );
    let mmr_peaks = array![
        0x735d9916958a088b58e320e015ba24e93ad034159fe0551c31cbb69d5be0a05,
        0x0e4829e42415b71f12d9d936cb22bc50cd97f4a9737852454deeca9b49c59a2,
        0x38aaa5bd29a41a3818b28eff66365d8ea7dd20380456f27b832f1091503a961
    ]
        .span();
    let mmr_proof = array![].span();
    let mmr_id = 1;

    let (dispatcher, contract_address) = helper_create_headers_store();

    start_prank(CheatTarget::One(contract_address), COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());
    dispatcher.create_branch_from_message(mmr.root, mmr.last_pos, 0, mmr_id);
    stop_prank(CheatTarget::One(contract_address));
    assert(dispatcher.get_mmr_root(mmr_id) == mmr.root, 'Root not set');

    dispatcher
        .process_batch(
            headers_rlp,
            mmr_peaks,
            mmr_id,
            Option::None,
            Option::Some(mmr.last_pos),
            Option::Some(mmr_proof)
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_receive_hash_wrong_address() {
    let (safe_dispatcher, _) = helper_create_safe_headers_store();

    assert(safe_dispatcher.receive_hash(0xffff, 0xabcd).is_err(), 'Should fail');
}

#[test]
fn test_receive_hash() {
    let (dispatcher, contract_address) = helper_create_headers_store();

    let block_number = 0x420;
    let real_block_hash = 0xabcd;
    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == 0, 'Initial block hash should be 0');

    helper_receive_hash(real_block_hash, block_number, dispatcher, contract_address);

    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == real_block_hash, 'Block hash not set');
}

#[test]
fn test_create_branch_from_message() {
    let (dispatcher, contract_address) = helper_create_safe_headers_store();

    let mmr_id_1 = 0x5a93;
    let mmr_id_2 = 0xcd82;
    let root = 0x123123123;
    let size = 10;

    start_prank(CheatTarget::One(contract_address), COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());

    // Create MMR.
    assert(dispatcher.get_mmr_size(mmr_id_1).unwrap() == 0, 'Initial mmr size should be 0');
    dispatcher.create_branch_from_message(root, size, 0, mmr_id_1).unwrap();
    assert(dispatcher.get_mmr_size(mmr_id_1).unwrap() == size, 'Mmr size mismatch');
    assert(dispatcher.get_mmr_root(mmr_id_1).unwrap() == root, 'Mmr root mismatch');

    // Creating MMR with ID 0 is not allowed.
    assert(
        dispatcher.create_branch_from_message(root, size, 0, 0).is_err(), 'Mmr ID 0 should fail'
    );

    // Both root and size 0 is not allowed.
    assert(
        dispatcher.create_branch_from_message(0, 0, 0, mmr_id_2).is_err(),
        'Root and size 0 should fail'
    );

    // Creating MMR with the same ID should fail.
    assert(
        dispatcher.create_branch_from_message(root, size, 0, mmr_id_1).is_err(),
        'MMR already exists should fail'
    );

    // Create another MMR.
    assert(dispatcher.get_mmr_size(mmr_id_2).unwrap() == 0, 'Initial mmr size should be 0');
    dispatcher.create_branch_from_message(root, size, 0, mmr_id_2).unwrap();
    assert(dispatcher.get_mmr_size(mmr_id_2).unwrap() == size, 'Mmr size mismatch');
    assert(dispatcher.get_mmr_root(mmr_id_2).unwrap() == root, 'Mmr root mismatch');

    stop_prank(CheatTarget::One(contract_address));

    let mmr_id_3 = 0x8124a;

    // Sender other than commitments inbox should fail.
    assert(
        dispatcher.create_branch_from_message(root, size, 0, mmr_id_3).is_err(),
        'only commitments inbox'
    );
}

fn helper_create_mmr_with_items(mut items: Span<felt252>) -> MMR {
    let mut mmr: MMR = Default::default();
    let mut peaks = array![].span();
    loop {
        match items.pop_front() {
            Option::Some(item) => {
                let (_root, new_peaks) = mmr.append(*item, peaks).unwrap();
                peaks = new_peaks;
            },
            Option::None => { break; }
        }
    };
    mmr
}

#[test]
fn test_create_branch_single_element() {
    let (dispatcher, contract_address) = helper_create_safe_headers_store();

    // Setup mmr with 7 elements
    let mmr_id = 1;
    let items = array![MMR_INITIAL_ELEMENT, 0x4AF3, 0xB1C2, 0x68D0, 0xE923, 0x0F4B, 0x37A8];
    let mmr = helper_create_mmr_with_items(items.span());
    start_prank(CheatTarget::One(contract_address), COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());
    dispatcher.create_branch_from_message(mmr.root, mmr.last_pos, 0, mmr_id).unwrap();
    stop_prank(CheatTarget::One(contract_address));

    // Create branch with 3rd element
    let new_mmr_id = 10;
    let index = 4;
    let hash = 0xB1C2;
    let proof = array![0x68D0, 0x5e58373c626c427a3d2b417634424a93ca5efa8cde09ac9747aa03f3afecb8d]
        .span();
    let peaks = array![
        0x7cd5f93b55c504e2919127e13b025c86cbb135e14efb41a97c56a3f61bc48d8,
        0x73cc8b5fc3ab909c2b7f33c34bd341df3b1d328f29c59bbe97dc53a17bbc33f,
        0x37A8
    ]
        .span();

    // New MMR with ID 0 should fail
    assert(
        dispatcher
            .create_branch_single_element(index, hash, peaks, proof, mmr_id, mmr.last_pos, 0)
            .is_err(),
        'new mmr id 0 should fail'
    );

    // Source MMR with ID 0 should fail
    assert(
        dispatcher
            .create_branch_single_element(index, hash, peaks, proof, 0, mmr.last_pos, new_mmr_id)
            .is_err(),
        'src mmr id 0 should fail'
    );

    // Source MMR must exist
    assert(
        dispatcher
            .create_branch_single_element(index, hash, peaks, proof, 2, mmr.last_pos, new_mmr_id)
            .is_err(),
        'no src mmr should fail'
    );

    // Invalid proof should fail
    assert(
        dispatcher
            .create_branch_single_element(
                index,
                hash,
                peaks,
                array![
                    0x68D0,
                    0x5e58373c626c427a3d2b417634424a93ca5efa8cde09ac9747aa03f3afecb8d,
                    0x1234
                ]
                    .span(),
                mmr_id,
                mmr.last_pos,
                new_mmr_id
            )
            .is_err(),
        'invalid proof should fail'
    );

    // Valid proof should succeed
    dispatcher
        .create_branch_single_element(index, hash, peaks, proof, mmr_id, mmr.last_pos, new_mmr_id)
        .unwrap();
    let new_mmr = dispatcher.get_mmr(new_mmr_id).unwrap();
    assert(
        new_mmr.root == 0x2f9bb49a56c6119deabb24612297842a5ec873bd67e71e7b87b94c8e1b95d7a,
        'new mmr root mismatch'
    );
    assert(new_mmr.last_pos == 1, 'new mmr last_pos mismatch');

    // New MMR that already exists should fail
    assert(
        dispatcher
            .create_branch_single_element(
                index, hash, peaks, proof, mmr_id, mmr.last_pos, new_mmr_id
            )
            .is_err(),
        'mmr alrd exists should fail'
    );
}

#[test]
fn test_initial_tree() {
    let (dispatcher, _) = helper_create_headers_store();

    let mmr_id = 1;
    dispatcher.create_branch_from(0, 0, mmr_id);

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root = MMR_INITIAL_ROOT;
    assert(mmr.last_pos == 1, 'Wrong initial last_pos');
    assert(mmr.root == expected_root, 'initial Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong initial historical root');
}

#[test]
fn test_process_batch_form_message() {
    let (dispatcher, contract_address) = helper_create_headers_store();

    let initial_block_number = 17000000;
    let real_block_hash = 0x96cfa0fb5e50b0a3f6cc76f3299cfbf48f17e8b41798d1394474e67ec8a97e9f;
    helper_receive_hash(real_block_hash, initial_block_number, dispatcher, contract_address);

    let headers_rlp = helper_get_headers_rlp();

    let mmr_id = 1;
    dispatcher.create_branch_from(0, 0, mmr_id);
    dispatcher
        .process_batch(
            headers_rlp,
            array![MMR_INITIAL_ELEMENT].span(),
            mmr_id,
            Option::Some(initial_block_number),
            Option::None(()),
            Option::None(())
        );

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root =
        1572837993933765604342513043085607997530137513337847038176530205164559011564;
    assert(mmr.last_pos == 8, 'Wrong last_pos');
    assert(mmr.root == expected_root, 'Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong historical root');
}

fn helper_get_headers_rlp() -> Span<Words64> {
    array![
        array![
            2263451220831175417,
            15475506108952879400,
            741690966216059028,
            13724127879293809526,
            5605888210103258221,
            13080049234815213288,
            4977272650390615655,
            4801382644103943195,
            822351442115576061,
            2060919963544886938,
            18065096119526433143,
            1608533759003496649,
            16489482639633695118,
            7025941497850136839,
            10591609375142486485,
            7220336757408602667,
            7856157561857638375,
            3853215147490336009,
            9070333417946327719,
            9150428924427655983,
            4661516135849121303,
            13467930351579739758,
            11044089176353269841,
            484970083255961,
            1456070127597430016,
            6996368964054954260,
            6125042939451209992,
            13382169361900390758,
            13384706961269000216,
            726594207542745875,
            155868532616267650,
            4408436971440116262,
            3227122037203945572,
            8070679583062700783,
            10955358009385170327,
            5350963046420058626,
            108160275332743715,
            6381397266628877336,
            10864858612374694,
            3747198369819467930,
            1158024666376900867,
            14346358011940197873,
            5477400452999241732,
            2501491483916515854,
            5366374862300466635,
            1192345635063386634,
            219182559240669484,
            9439546545580609842,
            1306354196916066381,
            11323468202912547128,
            15019515907020639297,
            5108293730157035012,
            9271082673976782882,
            5873126165013603462,
            8683586642608403599,
            7970228417676569,
            109283097845007488,
            9532652062815339465,
            2340009848045711460,
            8243105109760107072,
            17981836061268408368,
            7350476381845388023,
            6675110943001960198,
            5980065904163247402,
            150047286339368,
            325666548054228992,
            3786134474
        ]
            .span(),
        array![
            18073948714761847545,
            3290041491040724544,
            6598842851249156943,
            5529524783226291947,
            5605888210011765240,
            13080049234815213288,
            4977272650390615655,
            4801382644103943195,
            6193175472731603197,
            7086963355284609558,
            4995438275794032993,
            16956357881389657030,
            15613776393908769712,
            2193139528487071678,
            10804628434238642549,
            11142474787304836249,
            8300668493757212547,
            691775098901035867,
            1575644320975544375,
            4194326385868609400,
            4505473742391860683,
            12494856608087585096,
            6041528240182399639,
            485361786249898,
            464653979515988252,
            3541254846823932931,
            2352324107368962624,
            3891699727207523185,
            318242716413069334,
            11269660922827772386,
            16222810945268829475,
            1540578610629379349,
            8766291876504540681,
            8378491135147941611,
            15085376041798092450,
            9557017229828589058,
            2380735362467103630,
            6380566034511823220,
            2315045011511580928,
            290562627456467178,
            5188203018714352673,
            7066178713878904833,
            6351221582347420417,
            4690525538907068711,
            1756738133233600683,
            4656339391256003887,
            9478355114445065478,
            6958207667992092688,
            1298202110618166121,
            3490973676261181968,
            1171440115169305832,
            1182196112113288310,
            5531344054721352480,
            331926494334000397,
            15889399050641101526,
            1215186644830539848,
            109281998333379712,
            9521983613160178633,
            6320697073782894692,
            15975942949964087686,
            11429022381281133393,
            3156334603524254354,
            38519522890963463,
            9583660007044415488,
            730522711556
        ]
            .span(),
        array![
            16258094403813245689,
            8848141150820070407,
            9389337065954772067,
            6661813387766626173,
            5605888210970854734,
            13080049234815213288,
            4977272650390615655,
            4801382644103943195,
            822351442115576061,
            2060919963544886938,
            18065096119526433143,
            14135443637078626505,
            1149132355277286562,
            17075401624164885194,
            2224691342506516857,
            15861493743569776204,
            5015209523127625563,
            7886281485269689195,
            3201513657845167049,
            13445339048197784617,
            2722472119466823668,
            16348681903395167598,
            3153165077052095424,
            485300223273810,
            9834119466139625891,
            3533162832434418011,
            8233799357976852748,
            2771626766815771043,
            2329311774773823634,
            18161797320538812599,
            6321723364700918038,
            63524636975373447,
            7613640039527949060,
            2888100744547973739,
            10389346990891731616,
            2911820121303234560,
            14107800826278324478,
            5415655881191781464,
            1659207482701845004,
            9590643411577537759,
            469130880880984840,
            508909024075604404,
            7670166929783101495,
            7393490203459105868,
            3779684785234237594,
            13209357100645878666,
            264205773068502156,
            5929139682183867948,
            6918200283421216843,
            8887434976564905797,
            4425384324557026668,
            2657246422577133158,
            14240392002589373476,
            113823169938948,
            13952776587774279593,
            809656802443033230,
            109280898821751936,
            7500671518624498633,
            8458476963213894788,
            3924940343138872425,
            15613244428192161849,
            12991289672117631062,
            9087286043836762247,
            1077017187705520547,
            8977572,
            14581652858232373248,
            176
        ]
            .span(),
        array![
            18117585367741825785,
            11397625231657444299,
            13020100591073269189,
            18063699384525308064,
            5605888213284998782,
            13080049234815213288,
            4977272650390615655,
            4801382644103943195,
            2492061003963187453,
            15942085690261344290,
            5461852400203701304,
            956453846532548015,
            15906639059275075554,
            4531630737325424748,
            6736363734040833168,
            1446842186843128587,
            17715095491322047417,
            14688583986064528878,
            12125714989419609197,
            6124987441207038151,
            12310790503049931683,
            16441258639057996025,
            10986973253936343588,
            485368778672626,
            9519748492945323136,
            13188229551610669264,
            8126548237727481366,
            10535488506593274675,
            2819363699747669341,
            2932751463835833597,
            11740392584503478567,
            15202868471241462382,
            12680104983162081529,
            4169800423664923560,
            13122015778666320268,
            3656107654205198376,
            74808653070094231,
            5308971143734792580,
            3226401757423811040,
            7230628839993774042,
            3492934170351703975,
            5701625586977652771,
            8661157851087331334,
            15041871135591427148,
            4140641292659165375,
            7700685200877656852,
            9733868595213004673,
            8201196711109809186,
            4813828554610839641,
            17346816928903627276,
            5920873595315875274,
            4945096467382339067,
            9736195843772560018,
            5022361903244281670,
            18019021205241238728,
            8285664062163439164,
            109279799310124160,
            9576733936399205321,
            7018123964667736164,
            7236274654161298806,
            2064673519172742958,
            9433434497394490918,
            613123056794871754,
            12438023933322756306,
            149833700565390,
            325666548054228992,
            2995362435
        ]
            .span(),
    //array![
    //18219417174019932921,
    //16083864134760656902,
    //10295426118574649922,
    //8360381505023288964,
    //5605888209921422376,
    //13080049234815213288,
    //4977272650390615655,
    //4801382644103943195,
    //10103988799149457661,
    //3546896030373547137,
    //12811728746864885809,
    //2674941986357680018,
    //11483445208482818996,
    //17199270617691170075,
    //4877820188118080676,
    //9486021517467869285,
    //9955969497858801935,
    //7044770139951371625,
    //3681550067156513767,
    //920927437527569614,
    //17345961124947359199,
    //16776142633484725612,
    //16184957196300600453,
    //485896919658199,
    //3538506517102569288,
    //4769204004714711480,
    //5931061528349387208,
    //4180056229859865880,
    //9639852251318257516,
    //6270017864455576140,
    //5366345283411066142,
    //3482969231853834770,
    //6848211817462293029,
    //18353282125984597993,
    //13880047340619859988,
    //11104041080886923656,
    //16955503076797066006,
    //13973038692264982075,
    //6108764803908769501,
    //11873845832132548526,
    //8381738505829707343,
    //2972822542871643441,
    //13379703747836711703,
    //12981693489590182669,
    //11057897053441178290,
    //16189476766595711848,
    //3073172693940475468,
    //6173773309367305245,
    //3538088185396420231,
    //10977363621874008597,
    //4585808254850954830,
    //14152802300651852800,
    //13315182579216102418,
    //8365169692555580944,
    //15132713022927738563,
    //16410361240221501796,
    //109278699798496384,
    //17835038482695766985,
    //9500512617080317060,
    //7526752372513901313,
    //3328215298606065544,
    //11563121160349320498,
    //2766238696243360747,
    //14962176934875455032,
    //6259965550571698305,
    //11864091271460930794,
    //136,
    //68740728284808448
    //].span(),
    //array![
    //4980889823718474489,
    //3966853924813684024,
    //12639221170754933430,
    //14646770530818728383,
    //5605888211468837151,
    //13080049234815213288,
    //4977272650390615655,
    //4801382644103943195,
    //17005192278141321469,
    //3475584354178098859,
    //17858124224415326122,
    //16549259734987893260,
    //5305525775066799391,
    //5708678197831794626,
    //3480834116117044666,
    //15907514683217208241,
    //16948852932055821348,
    //10799729905615085207,
    //14912140562703110876,
    //1949305063464768131,
    //6797550865115124396,
    //17109300633997942481,
    //5094694012074499950,
    //484947486570285,
    //1950199655348379904,
    //6917557070558922768,
    //4638716446997024904,
    //13839598300919496960,
    //1173187707225069570,
    //10099086143075856644,
    //335946492853911938,
    //2306309760489759810,
    //1011075983415181376,
    //2607584459851039338,
    //13860184649085362560,
    //5349837052445184,
    //225182192741924898,
    //1480839889590162196,
    //578167540170561088,
    //2595297744495845378,
    //9534683397146902571,
    //3985685717535476755,
    //1748069286377760816,
    //10672001697452208129,
    //461636555603249802,
    //10386746059491165704,
    //261737098019612246,
    //2342446062398256136,
    //5911328589143617761,
    //4617390286317829320,
    //1729602179133875776,
    //2315026267805921338,
    //72198332736747008,
    //9802086795546111889,
    //6935659424929480928,
    //149942085783463186,
    //109277600286868608,
    //9551186354231100361,
    //8391447007065878628,
    //7526752130573169520,
    //8243105109760107053,
    //11207258939277140782,
    //953069320280687651,
    //8358076700073148736,
    //11460787224762429817,
    //149597160199684,
    //325666548054228992,
    //4176937042
    //].span()
    ]
        .span()
}
