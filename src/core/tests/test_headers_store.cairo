use snforge_std::{ declare, PreparedContract, deploy, start_prank, stop_prank };
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher, 
    IHeadersStoreSafeDispatcherTrait, IHeadersStoreSafeDispatcher
};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use starknet::ContractAddress;

const COMMITMENTS_INBOX_ADDRESS: felt252 = 0x123;

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

#[test]
fn test_receive_hash_wrong_address() {
    let (safe_dispatcher, _) = helper_create_safe_headers_store();

    assert(safe_dispatcher.receive_hash(0xffff, 0xabcd).is_err(), 'Should fail');
}

#[test]
fn test_receive_hash() {
    let (dispatcher, contract_address) = helper_create_headers_store(); 

    let block_number = 0x420;
    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == 0, 'Initial block hash should be 0');

    start_prank(contract_address, COMMITMENTS_INBOX_ADDRESS.try_into().unwrap());
    dispatcher.receive_hash(0xabcd, block_number);
    stop_prank(contract_address);

    let block_hash = dispatcher.get_received_block(block_number);
    assert(block_hash == 0xabcd, 'Block hash not set');
}
