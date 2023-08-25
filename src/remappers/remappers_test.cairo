use snforge_std::{declare, PreparedContract, deploy, start_prank, stop_prank};
use snforge_std::PrintTrait;

use cairo_lib::data_structures::mmr::mmr::MMRTrait;
use cairo_lib::utils::bitwise::bit_length;
use cairo_lib::utils::math::pow;
use array::{ArrayTrait, SpanTrait};
use traits::{Into, TryInto};
use option::OptionTrait;
use result::ResultTrait;
use starknet::ContractAddress;
use herodotus_eth_starknet::remappers::timestamp_remappers::{
    ITimestampRemappersDispatcherTrait, ITimestampRemappersDispatcher, BinarySearchTree,
    ProofElement
};
use herodotus_eth_starknet::core::headers_store::{
    IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
};
use cairo_lib::data_structures::mmr::mmr::MMR;

fn deploy_headers_store() -> ContractAddress {
    let class_hash = declare('HeadersStore');
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(0);

    let prepared = PreparedContract {
        class_hash: class_hash, constructor_calldata: @constructor_calldata
    };

    deploy(prepared).unwrap()
}

fn deploy_timestamp_remappers(headers_store: ContractAddress) -> ContractAddress {
    let class_hash = declare('TimestampRemappers');
    let mut constructor_calldata: Array<felt252> = ArrayTrait::new();
    constructor_calldata.append(headers_store.into());

    let prepared = PreparedContract {
        class_hash: class_hash, constructor_calldata: @constructor_calldata
    };

    deploy(prepared).unwrap()
}

fn test_proof(mmr: @MMR) {
    let mut proof = ArrayTrait::new();
    proof.append(4);
    proof.append(0x5d44a3decb2b2e0cc71071f7b802f45dd792d064f0fc7316c46514f70f9891a);

    let mut peaks = ArrayTrait::new();
    peaks.append(0x43c59debacab61e73dec9edd73da27738a8be14c1e123bb38f9634220323c4f);
    peaks.append(8);

    let result = mmr.verify_proof(index: 5, value: 5, peaks: peaks.span(), proof: proof.span());
    match result {
        Result::Ok(r) => {
            assert(r == true, 'Invalid proof');
        },
        Result::Err(err) => {
            err.print();
            assert(false, 'Error while verifying proof')
        }
    }
}

fn count_ones(n: u256) -> u256 {
    let mut n = n;
    let mut count = 0;
    loop {
        if n == 0 {
            break count;
        }
        n = n & (n - 1);
        count += 1;
    }
}

fn leaf_index_to_mmr_index(n: u256) -> u256 {
    2 * n - 1 - count_ones(n - 1)
}

#[test]
fn test_remappers() {
    let headers_store: ContractAddress = deploy_headers_store();
    let timestamp_remappers: ContractAddress = deploy_timestamp_remappers(headers_store);

    let remapper_dispatcher = ITimestampRemappersDispatcher {
        contract_address: timestamp_remappers
    };
    let start_block: u256 = 42;
    let mapper_id = remapper_dispatcher.create_mapper(start_block);
    assert(mapper_id == 0, 'Invalid mapper id');

    // An MMR containing { 1, 2, 4, 5, 8 } as string with Starknet Poseidon as a hasher.
    let mut mmr: MMR = MMR {
        root: 0x49da356656c3153d59f9be39143daebfc12e05b6a93ab4ccfa866a890ad78f, last_pos: 8, 
    };
    test_proof(@mmr);

    let headers_store_dispatcher = IHeadersStoreDispatcher { contract_address: headers_store };
    let mmr_id = 4242; // Arbitrary MMR id

    start_prank(headers_store, 0.try_into().unwrap());
    headers_store_dispatcher.force_create_mmr(mmr_id, mmr.root, mmr.last_pos);
    stop_prank(headers_store);

    let mut proofs = ArrayTrait::new();

    let mut peaks_proof4 = ArrayTrait::new();
    peaks_proof4.append(0x43c59debacab61e73dec9edd73da27738a8be14c1e123bb38f9634220323c4f);
    peaks_proof4.append(8);
    let mut proof_4_proof = ArrayTrait::new();
    proof_4_proof.append(5);
    proof_4_proof.append(0x5d44a3decb2b2e0cc71071f7b802f45dd792d064f0fc7316c46514f70f9891a);
    let proof_a = ProofElement {
        index: 4,
        value: 4,
        peaks: peaks_proof4.span(),
        proof: proof_4_proof.span(),
        last_pos: mmr.last_pos
    };

    let mut peaks_proof1 = ArrayTrait::new();
    peaks_proof1.append(0x43c59debacab61e73dec9edd73da27738a8be14c1e123bb38f9634220323c4f);
    peaks_proof1.append(8);
    let mut proof_1_proof = ArrayTrait::new();
    proof_1_proof.append(2);
    proof_1_proof.append(0x384f427301be8e1113e6dd91088cb46e25a8f6426a997b2f842a39596bf45f4);
    let proof_b = ProofElement {
        index: 1,
        value: 1,
        peaks: peaks_proof1.span(),
        proof: proof_1_proof.span(),
        last_pos: mmr.last_pos
    };

    proofs.append(proof_a);
    proofs.append(proof_b);

    let tree = BinarySearchTree {
        mmr_id: mmr_id,
        size: 5, // leaves count
        proofs: proofs.span(),
        closest_low_val: Option::None,
        closest_high_val: Option::None,
    };
    let x = 1; // Element to find (exact match)
    let result_idx = remapper_dispatcher.mmr_binary_search(tree, x, Option::Some(false));
    assert(result_idx.unwrap() == 0, 'Invalid index');
}

