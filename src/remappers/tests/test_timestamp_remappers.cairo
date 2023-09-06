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
    ProofElement, OriginElement
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

    let result = mmr.verify_proof(index: 5, hash: 5, peaks: peaks.span(), proof: proof.span());
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

fn prepare_mmr() -> MMR {
    // An MMR containing { 1, 2, 4, 5, 8 } as number with Starknet Poseidon as a hasher.
    let mut mmr: MMR = Default::default();
    mmr.append(1, ArrayTrait::new().span());

    let mut peaks = ArrayTrait::new();
    peaks.append(1);
    mmr.append(2, peaks.span());

    let mut peaks_2 = ArrayTrait::new();
    peaks_2.append(0x5d44a3decb2b2e0cc71071f7b802f45dd792d064f0fc7316c46514f70f9891a);
    mmr.append(4, peaks_2.span());

    peaks_2.append(4);
    mmr.append(5, peaks_2.span());

    let mut peaks_3 = ArrayTrait::new();
    peaks_3.append(0x43c59debacab61e73dec9edd73da27738a8be14c1e123bb38f9634220323c4f);
    mmr.append(8, peaks_3.span());

    mmr
}

fn test_reindex_batch(
    remapper_dispatcher: ITimestampRemappersDispatcher, mapper_id: usize, mmr_id: usize
) {
    let mut header = array![
        0x9854517da01202f9,
        0x36137eca10b07574,
        0xd5e16d5e0c35650f,
        0x98992b45fe663012,
        0x4dcc1da0f69fec4e,
        0xb585ab7a5dc7dee8,
        0x4512d31ad4ccb667,
        0x42a1f013748a941b,
        0xbc52944793d440fd,
        0xbf2aee098337d544,
        0x7b7d1bde71bf3915,
        0xe3eb13a017a0b5e3,
        0xa94cfc3d0f3c08d9,
        0xe577db24349c7835,
        0x4dea5c47be79a313,
        0x111c3e64a0d55496,
        0x56d42023159521ec,
        0x71d737a002ed2060,
        0xa599e0c8ce67b84e,
        0x1d57cca0a7214ab7,
        0x87625d52711285c5,
        0x6ff001c7382e1309,
        0x4376e7f9747c0d5d,
        0x0001b9611b595a4e,
        0x00000000000042,
        0x90001004000408,
        0x0000000000140020,
        0x00200002,
        0x0400001060040080,
        0x042100100040,
        0x02,
        0x0000286000000080,
        0x0000000000100440,
        0x00100000080000c0,
        0x402000004e,
        0x0020000000800020,
        0x00000000000020,
        0x004008000040,
        0x100404,
        0x000000001010,
        0x00004040,
        0x0004000004,
        0x004000000010,
        0x0000100810000001,
        0x000a00000080,
        0x1008c00080420004,
        0x0000000004000104,
        0x04000000000002,
        0x00000009020810,
        0x0020000100000004,
        0x0000800000001004,
        0x00100400008108,
        0x000002,
        0x0060,
        0x0001900010800402,
        0x00001080001002,
        0xc5c9d517b3670787,
        0x5ca39783cf4e8d83,
        0xfb195e8432ca1683,
        0x6e2045595050914f,
        0x2e6c6f6f706f6e61,
        0xf7622d47a067726f,
        0x2a04f8a7c20d6d60,
        0x57acfbfdb936551a,
        0x02aea3b668e60df7,
        0xbfb2018838bb66e0,
        0x46095d0140,
    ];

    let mut peaks = ArrayTrait::new();
    peaks.append(0xafce4bb6bb364b2bb42b8df4705a6077b1231770b150eb458da627a1975376);
    let mut origin_elements = ArrayTrait::new();
    let mut origin_element_1 = OriginElement {
        tree_id: mmr_id,
        tree_size: 1,
        leaf_idx: 1,
        leaf_value: 0xafce4bb6bb364b2bb42b8df4705a6077b1231770b150eb458da627a1975376, // poseidon_hash(hexRlp(9260751))
        inclusion_proof: ArrayTrait::new().span(),
        peaks: peaks.span(),
        header: header.span(),
    };
    origin_elements.append(origin_element_1);
    remapper_dispatcher.reindex_batch(mapper_id, ArrayTrait::new().span(), origin_elements.span());
}

#[test]
fn test_remappers() {
    let headers_store: ContractAddress = deploy_headers_store();
    let timestamp_remappers: ContractAddress = deploy_timestamp_remappers(headers_store);

    let remapper_dispatcher = ITimestampRemappersDispatcher {
        contract_address: timestamp_remappers
    };
    let start_block: u256 = 9260751; // Mainnet block
    let mapper_id = remapper_dispatcher.create_mapper(start_block);
    assert(mapper_id == 0, 'Invalid mapper id');

    // An MMR containing { 1, 2, 4, 5, 8 } as string with Starknet Poseidon as a hasher.
    let mmr = prepare_mmr();
    test_proof(@mmr);

    let headers_store_dispatcher = IHeadersStoreDispatcher { contract_address: headers_store };
    let mmr_id = 1; // First MMR

    start_prank(headers_store, 0.try_into().unwrap());
    headers_store_dispatcher
        .create_branch_from_message(
            0x2529764d77db01a12aefd2a8cdf885beea6f0a610fa5c04065d2be8e01cf2a1, 1
        ); // poseidon_hash(1, hexRlp(9260751))
    stop_prank(headers_store);

    test_reindex_batch(remapper_dispatcher, mapper_id, mmr_id);

    let mut peaks = array![1578761039];
    let mut proofs = ArrayTrait::new();
    proofs
        .append(
            ProofElement {
                index: 1,
                value: 1578761039,
                peaks: peaks.span(),
                proof: ArrayTrait::new().span(),
                last_pos: 1,
            }
        );
    let tree = BinarySearchTree {
        mapper_id: mapper_id,
        mmr_id: mmr_id,
        proofs: proofs.span(),
        left_neighbor: Option::Some(
            ProofElement {
                index: 1,
                value: 1578761039,
                peaks: peaks.span(),
                proof: ArrayTrait::new().span(),
                last_pos: 1,
            }
        ),
    };
    let timestamp = 1578761039; // Element to find (exact match)
    let result_idx = remapper_dispatcher.mmr_binary_search(tree, timestamp);
    assert(result_idx.unwrap() == 0, 'Invalid index');

    let corresponding_block_number: u256 = remapper_dispatcher
        .get_closest_l1_block_number(tree, timestamp)
        .unwrap();
    assert(corresponding_block_number == start_block, 'Unexpected block number');
}
