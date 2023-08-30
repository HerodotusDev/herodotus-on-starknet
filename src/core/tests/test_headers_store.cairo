use snforge_std::{ declare, PreparedContract, deploy, start_prank, stop_prank };
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher, 
    IHeadersStoreSafeDispatcherTrait, IHeadersStoreSafeDispatcher
};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use starknet::ContractAddress;

//fn helper_create_headers_store() -> IHeadersStoreDispatcher {
    //let class_hash = declare('HeadersStore');
    //let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @array![0x123] };
    //let contract_address = deploy(prepared).unwrap();
    //let dispatcher = IHeadersStoreDispatcher { contract_address };
//}

#[test]
fn test_receive_hash_wrong_address() {
    let class_hash = declare('HeadersStore');
    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @array![0x123] };
    let contract_address = deploy(prepared).unwrap();
    let safe_dispatcher = IHeadersStoreSafeDispatcher { contract_address };

    assert(safe_dispatcher.receive_hash(0xffff, 0xabcd).is_err(), 'Should fail');
}

#[test]
fn test_receive_hash() {
    let class_hash = declare('HeadersStore');

    let commitments_inbox_address = 0x123;
    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @array![commitments_inbox_address] };

    let contract_address = deploy(prepared).unwrap();
    let dispatcher = IHeadersStoreDispatcher { contract_address };

    let block_number = 0x420;
    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == 0, 'Initial block hash should be 0');

    start_prank(contract_address, commitments_inbox_address.try_into().unwrap());
    dispatcher.receive_hash(0xabcd, block_number);
    stop_prank(contract_address);

    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == 0xabcd, 'Block hash not set');
}
