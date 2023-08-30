use snforge_std::{ declare, PreparedContract, deploy, start_prank, stop_prank };
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher, 
    IHeadersStoreSafeDispatcherTrait, IHeadersStoreSafeDispatcher
};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use starknet::ContractAddress;
use array::ArrayTrait;

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
fn test_process_received_block() {
    let (dispatcher, contract_address) = helper_create_headers_store(); 

    let block_number = 0x820E53;
    // RLP encoded: 0xf90201a07316e20526638b2ec44be5ceeb290848f910f36f2539f2b6f4355d3aa48d8909a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794e0a2bd4258d2768837baa26a28fe71dc079f84c7a047aa895300d0d14f8433d4a743a0689c04d89a21d863e1916f504294fd57e2f2a0a31e0c29e555c302ebf860a355bc557185126a558cc075a9091028f045cc7b15a06cb0697a808b72fec997241bb4496074a6181f2f9938c5407496a72563110646b901009195023d3526504c0110080884800009153c3400884818102202181482f15208042e18e16c0243109013106631250084c500e8e06e502b8048811a49492c7aa00a61588185e9d16c4290a21810e408073b81548219d6203c8174028490208a11218013d30a0872048000e99e241108129d0029c402984580a1001430e8d8007c069304e1cb8620062c00581ca688120482413a090296d8443801c06844621101ae288900081380089d4844c42302140204900000aa98204a001948cf2409cf02a3125852c1422b995a4a00314403e5084124a02150a80d8140a215524c946142ba199c0926102262218b016640310104c40700b5c3086441390269c012901a428083820e538401c9c38084010589368463f3126080a075eb17165a67f979f8037a368bf2fd56a7cfa0b4ec596ce5e896570e57c039a5880000000000000000842b8615f7
    // little endian block hash
    let real_block_hash = 0x9286BBF9936BDDC873FAF3C5ACEA50D777B8DFA90967D55669D918EC47281725;
    helper_receive_hash(real_block_hash, block_number, dispatcher, contract_address);

    let header_rlp = array![
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
    ].span();

    let mmr_id = 0;

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root = MMR_INITIAL_ROOT;
    assert(mmr.last_pos == 1, 'Wrong initial last_pos');
    assert(mmr.root == expected_root, 'initial Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong initial historical root');

    dispatcher.process_received_block(block_number, header_rlp, array![MMR_INITIAL_ELEMENT].span(), mmr_id);

    let mmr = dispatcher.get_mmr(mmr_id);
    let expected_root = 0x46d870bc268ff894d760fd8b9076d6e53437f0c61b359b107fef8ec7d50f20e;
    assert(mmr.last_pos == 3, 'Wrong last_pos');
    assert(mmr.root == expected_root, 'Wrong root');

    let historical_root = dispatcher.get_historical_root(mmr_id, mmr.last_pos);
    assert(historical_root == expected_root, 'Wrong historical root');
}
