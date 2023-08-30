use snforge_std::{ declare, PreparedContract, deploy, start_prank, stop_prank };
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher, 
    IHeadersStoreSafeDispatcherTrait, IHeadersStoreSafeDispatcher
};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use starknet::ContractAddress;
use array::{ArrayTrait, SpanTrait};
use cairo_lib::utils::types::words64::Words64;

const COMMITMENTS_INBOX_ADDRESS: felt252 = 0x123;
const MMR_INITIAL_ELEMENT: felt252 = 0x02241b3b7f1c4b9cf63e670785891de91f7237b1388f6635c1898ae397ad32dd;
const MMR_INITIAL_ROOT: felt252 = 0x6759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

fn helper_create_headers_store() -> (IHeadersStoreDispatcher, ContractAddress) {
    let class_hash = declare('HeadersStore');
    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @array![COMMITMENTS_INBOX_ADDRESS] };
    let contract_address = deploy(prepared).unwrap();
    (IHeadersStoreDispatcher { contract_address }, contract_address)
}

fn helper_create_safe_headers_store() -> (IHeadersStoreSafeDispatcher, ContractAddress) {
    let class_hash = declare('HeadersStore');
    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @array![COMMITMENTS_INBOX_ADDRESS] };
    let contract_address = deploy(prepared).unwrap();
    (IHeadersStoreSafeDispatcher { contract_address }, contract_address)
}

fn helper_receive_hash(blockhash: u256, block_number: u256, dispatcher: IHeadersStoreDispatcher, contract_address: ContractAddress) {
    start_prank(contract_address, COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());
    dispatcher.receive_hash(blockhash, block_number);
    stop_prank(contract_address);
}

#[test]
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
fn test_initial_tree() {
    let (dispatcher, contract_address) = helper_create_headers_store(); 

    let mmr_id = 0;

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root = MMR_INITIAL_ROOT;
    assert(mmr.last_pos == 1, 'Wrong initial last_pos');
    assert(mmr.root == expected_root, 'initial Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong initial historical root');
}

#[test]
fn test_process_received_block() {
    let (dispatcher, contract_address) = helper_create_headers_store(); 

    let block_number = 0x820E53;
    // little endian block hash
    let real_block_hash = 0x9286BBF9936BDDC873FAF3C5ACEA50D777B8DFA90967D55669D918EC47281725;
    helper_receive_hash(real_block_hash, block_number, dispatcher, contract_address);

    let header_rlp = *helper_get_headers_rlp().at(0);

    let mmr_id = 0;
    dispatcher.process_received_block(block_number, header_rlp, array![MMR_INITIAL_ELEMENT].span(), mmr_id);

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root = 0x46d870bc268ff894d760fd8b9076d6e53437f0c61b359b107fef8ec7d50f20e;
    assert(mmr.last_pos == 3, 'Wrong last_pos');
    assert(mmr.root == expected_root, 'Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong historical root');
}

#[test]
fn test_process_batch() {
    let (dispatcher, contract_address) = helper_create_headers_store(); 

    let initial_block_number = 0x820E53;
    // little endian block hash
    let real_block_hash = 0x9286BBF9936BDDC873FAF3C5ACEA50D777B8DFA90967D55669D918EC47281725;

    helper_receive_hash(real_block_hash, initial_block_number, dispatcher, contract_address);

    let headers_rlp = helper_get_headers_rlp();

    let mmr_id = 0;
    dispatcher.process_batch(initial_block_number, headers_rlp, array![MMR_INITIAL_ELEMENT].span(), mmr_id);

}

fn helper_get_headers_rlp() -> Span<Words64> {
    array![
        array![
            0x05e21673a00102f9,
            0xcee54bc42e8b6326,
            0x6ff310f9480829eb,
            0x3a5d35f4b6f23925,
            0x4dcc1da009898da4,
            0xb585ab7a5dc7dee8,
            0x4512d31ad4ccb667,
            0x42a1f013748a941b,
            0xa2e0944793d440fd,
            0xba378876d25842bd,
            0x9f07dc71fe286aa2,
            0x005389aa47a0c784,
            0x43a7d433844fd1d0,
            0xd8219ad8049c68a0,
            0xfd9442506f91e163,
            0x290c1ea3a0f2e257,
            0xa360f8eb02c355e5,
            0x556a12857155bc55,
            0xf0281009a975c08c,
            0x69b06ca0157bcc45,
            0x2497c9fe728b807a,
            0x1f18a6746049b41b,
            0xa7967440c538992f,
            0x0001b94606116325,
            0x4c5026353d029591,
            0x0900808408081001,
            0x1018488800343c15,
            0x0852f18214180222,
            0x1043026ce1182e04,
            0x8400253166101390,
            0x802b506ee0e800c5,
            0xa07a2c49491a8148,
            0x6cd1e9858158610a,
            0x0708e41018a29042,
            0x3c20d6198254813b,
            0x118a209084027481,
            0x0472080ad3138021,
            0x120811249ee90080,
            0x80459802c429009d,
            0x7c00d8e8301400a1,
            0x062086cbe1049306,
            0x041288a61c58002c,
            0x44d89602093a4182,
            0x0111624468c00138,
            0x08801308008928ae,
            0x02140223c444489d,
            0x4a2098aa00009004,
            0x02cf0924cf481900,
            0x992b42c1525812a3,
            0x08e5034431004a5a,
            0x810da85021a02441,
            0x4261944c5215a240,
            0x62221026099c19ba,
            0x0401314066018b21,
            0x416408c3b50007c4,
            0x421a9012c0690239,
            0xc90184530e828380,
            0x84368905018480c3,
            0xeb75a0806012f363,
            0x03f879f9675a1617,
            0xcfa756fdf28b367a,
            0x96e8e56c59ecb4a0,
            0x0088a539c0570e57,
            0x8400000000000000,
            0xf715862b
        ].span(),
        array![
            0x3b235465a01402f9,
            0x902698b708c727b3,
            0x4a708e432d87e880,
            0x46e2cd02a8e3a22b,
            0x4dcc1da02a6d9080,
            0xb585ab7a5dc7dee8,
            0x4512d31ad4ccb667,
            0x42a1f013748a941b,
            0xc88d944793d440fd,
            0xd518ac472987af47,
            0xd9d465eb46a63fd6,
            0x828a933238a06095,
            0x9d5dfdcabf348e04,
            0x657e83e18a70d0f7,
            0xaf82ef655c840604,
            0xb48044b6a0679fbb,
            0x6b6aeadc3050acf6,
            0xc4f4ffec824848b2,
            0x64daf34ad1d6691f,
            0xa2abf4a07ba61355,
            0x6746ecc0309a7c56,
            0x0b34f499497e73d0,
            0x1c2d7ec803e09028,
            0x0001b97e6d5ab28c,
            0x244822104f08a560,
            0x445990844184d080,
            0x324800690273a000,
            0x1051b19a0c484741,
            0x246201423000abdc,
            0xe400660028100400,
            0xc333040c091080d9,
            0x612b37854cfe2202,
            0x88b130ae00c2c4ca,
            0x2000c8400b40825a,
            0x1815460756c18b89,
            0x810f2280ce484600,
            0x90c0980300108481,
            0x9288510c831b0041,
            0x10445046040d819c,
            0x02049844d8543aa5,
            0xcb2e72fc4e21204e,
            0x3404000205184829,
            0x1f20042c0981105c,
            0x54146e5649000118,
            0x184e06da00206c82,
            0x800040ade272c088,
            0x6048442000042414,
            0x622338355e348800,
            0x1d0a04c00a503542,
            0x07e5434520022004,
            0xf0904a5034306240,
            0x2278500ad228b300,
            0x0587120006191152,
            0x0c2a14c34fa1b020,
            0x45a0419a991240c0,
            0x4764288280484210,
            0xc90184520e828380,
            0x6384b07c908380c3,
            0x65776f50945412f3,
            0x6220796220646572,
            0x6574756f72586f6c,
            0x3195845f2bfa01a0,
            0x26ebd3f31aafc465,
            0x44deceb20d27b3f7,
            0x10a7133fa21e18f4,
            0x0000000000008866,
            0x6a72a02d840000,
        ].span()
    ].span()
}
