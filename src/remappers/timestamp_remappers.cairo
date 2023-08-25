use core::array::SpanTrait;
use cairo_lib::data_structures::mmr::proof::Proof;
use cairo_lib::data_structures::mmr::peaks::Peaks;
use cairo_lib::utils::types::bytes::{Bytes, BytesTryIntoU256};

type Headers = Span<Bytes>;

#[derive(Drop, Copy, Serde)]
struct OriginElement {
    tree_id: usize,
    tree_size: usize,
    leaf_idx: usize,
    leaf_value: felt252,
    inclusion_proof: Proof,
    peaks: Peaks,
    header: Bytes
}

#[derive(Drop, Copy, Serde)]
struct ProofElement {
    index: usize,
    value: u256,
    peaks: Peaks,
    proof: Proof,
    last_pos: usize,
}

#[derive(Drop, Copy, Serde)]
struct BinarySearchTree {
    mmr_id: usize,
    size: u256,
    proofs: Span<ProofElement>,
    closest_low_val: Option<ProofElement>,
    closest_high_val: Option<ProofElement>
}

#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    fn create_mapper(ref self: TContractState, start_block: u256) -> usize;

    fn reindex_batch(
        ref self: TContractState,
        mapper_id: usize,
        mapper_peaks: Peaks,
        origin_elements: Span<OriginElement>
    );

    fn mmr_binary_search(
        self: @TContractState, tree: BinarySearchTree, x: u256, get_closest: Option<bool>
    ) -> Option<u256>;
}

#[starknet::contract]
mod TimestampRemappers {
    use super::{
        ITimestampRemappers, Headers, OriginElement, Proof, Peaks, SpanTrait, Bytes,
        BytesTryIntoU256, ProofElement, BinarySearchTree
    };
    use starknet::{ContractAddress};
    use zeroable::Zeroable;
    use option::OptionTrait;
    use result::ResultTrait;
    use traits::{Into, TryInto};

    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    use cairo_lib::hashing::keccak::KeccakTrait;
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use cairo_lib::encoding::rlp::{RLPItem, rlp_decode};

    use debug::PrintTrait;

    #[derive(Drop, starknet::Store)]
    struct Mapper {
        start_block: u256,
        latest_block: felt252,
        mmr: MMR
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MapperCreated: MapperCreated
    }

    #[derive(Drop, starknet::Event)]
    struct MapperCreated {
        mapper_id: usize,
        start_block: u256
    }

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        mappers: LegacyMap::<usize, Mapper>,
        mappers_count: usize,
    }

    #[constructor]
    fn constructor(ref self: ContractState, headers_store: ContractAddress) {
        self.headers_store.write(headers_store);
        self.mappers_count.write(0);
    }

    #[external(v0)]
    impl TimestampRemappers of super::ITimestampRemappers<ContractState> {
        fn create_mapper(ref self: ContractState, start_block: u256) -> usize {
            let mapper = Mapper {
                start_block: start_block, latest_block: -1, mmr: Default::default(), 
            };

            let mapper_id = self.mappers_count.read();
            self.mappers.write(mapper_id, mapper);
            self.mappers_count.write(mapper_id + 1);

            self
                .emit(
                    Event::MapperCreated(
                        MapperCreated { mapper_id: mapper_id, start_block: start_block }
                    )
                );

            mapper_id
        }

        fn reindex_batch(
            ref self: ContractState,
            mapper_id: usize,
            mapper_peaks: Peaks,
            origin_elements: Span<OriginElement>
        ) {
            let headers_store_addr = self.headers_store.read();

            let mut mapper = self.mappers.read(mapper_id);
            let mut mapper_mmr = mapper.mmr;
            let mut mapper_peaks = mapper_peaks;

            let mut expected_block: u256 = (mapper.latest_block + 1).into();
            if (mapper.latest_block == -1) {
                expected_block = mapper.start_block;
            }

            let mut idx = 0;
            let len = origin_elements.len();
            loop {
                if idx == len {
                    break ();
                }
                let origin_element: OriginElement = *origin_elements.at(idx);
                let origin_element_block_number = extract_header_block_number(
                    @origin_element.header
                );
                assert(origin_element_block_number == expected_block, 'Unexpected block number');

                let current_hash = KeccakTrait::keccak_cairo(origin_element.header);
                assert(current_hash == origin_element.leaf_value.into(), 'Invalid header rlp');

                let is_valid_proof = IHeadersStoreDispatcher {
                    contract_address: headers_store_addr
                }
                    .verify_historical_mmr_inclusion(
                        origin_element.leaf_idx,
                        origin_element.leaf_value,
                        origin_element.peaks,
                        origin_element.inclusion_proof,
                        origin_element.tree_id,
                        origin_element.tree_size
                    );
                assert(is_valid_proof, 'Invalid proof');

                let origin_element_timestamp = extract_header_timestamp(@origin_element.header);
                mapper_mmr.append(origin_element_timestamp.try_into().unwrap(), mapper_peaks);

                expected_block += 1;
                idx += 1;
            };

            let last_block_appended: felt252 = (expected_block - 1).try_into().unwrap();
            mapper.latest_block = last_block_appended;
        }

        fn mmr_binary_search(
            self: @ContractState, tree: BinarySearchTree, x: u256, get_closest: Option<bool>
        ) -> Option<u256> {
            if tree.size == 0 {
                return Option::None(());
            }
            let headers_store_addr = self.headers_store.read();

            let mut low: u256 = 0;
            let mut high: u256 = tree.size - 1;

            let proofs: Span<ProofElement> = tree.proofs;
            let mut proof_idx = 0;
            let result = loop {
                if low > high {
                    break Option::None(());
                }

                let mid: u256 = (low + high) / 2;
                let proof_element: ProofElement = *proofs.at(proof_idx);

                assert(
                    proof_element.index.into() == leaf_index_to_mmr_index(mid + 1),
                    'Unexpected proof index'
                );

                let mid_val: u256 = proof_element.value;
                let is_valid_proof = IHeadersStoreDispatcher {
                    contract_address: headers_store_addr
                }
                    .verify_historical_mmr_inclusion(
                        proof_element.index,
                        mid_val.try_into().unwrap(),
                        proof_element.peaks,
                        proof_element.proof,
                        tree.mmr_id,
                        proof_element.last_pos
                    );
                assert(is_valid_proof, 'Invalid proof');

                if mid_val == x {
                    break Option::Some(mid);
                }
                if mid_val < x {
                    low = mid + 1;
                } else {
                    if mid == 0 {
                        break Option::None(());
                    }
                    high = mid - 1;
                }
                proof_idx += 1;
            };

            match result {
                Option::Some(_) => result,
                Option::None(_) => {
                    if get_closest.unwrap() == true {
                        closest_from_x(tree, low, high, x, headers_store_addr)
                    } else {
                        result
                    }
                }
            }
        }
    }

    fn closest_from_x(
        tree: BinarySearchTree, low: u256, high: u256, x: u256, headers_store_addr: ContractAddress
    ) -> Option<u256> {
        if low >= tree.size {
            return Option::Some(high);
        }
        if high < 0 {
            return Option::Some(low);
        }
        let tree_closest_low_val = tree.closest_low_val.unwrap();
        let tree_closest_high_val = tree.closest_high_val.unwrap();

        assert(tree_closest_low_val.index.into() == low, 'Unexpected proof index (low)');
        assert(tree_closest_high_val.index.into() == high, 'Unexpected proof index (high)');

        let is_valid_low_proof = IHeadersStoreDispatcher {
            contract_address: headers_store_addr
        }
            .verify_historical_mmr_inclusion(
                tree_closest_low_val.index,
                tree_closest_low_val.value.try_into().unwrap(),
                tree_closest_low_val.peaks,
                tree_closest_low_val.proof,
                tree.mmr_id,
                tree_closest_low_val.last_pos
            );
        assert(is_valid_low_proof, 'Invalid proof (low)');

        let is_valid_high_proof = IHeadersStoreDispatcher {
            contract_address: headers_store_addr
        }
            .verify_historical_mmr_inclusion(
                tree_closest_high_val.index,
                tree_closest_high_val.value.try_into().unwrap(),
                tree_closest_high_val.peaks,
                tree_closest_high_val.proof,
                tree.mmr_id,
                tree_closest_high_val.last_pos
            );
        assert(is_valid_high_proof, 'Invalid proof (high)');

        let low_val: u256 = tree_closest_low_val.value;
        let high_val: u256 = tree_closest_high_val.value;

        let mut a = 0;
        if low_val > x {
            a = low_val - x;
        } else {
            a = x - low_val;
        }

        let mut b = 0;
        if high_val > x {
            b = high_val - x;
        } else {
            b = x - high_val;
        }

        if a < b {
            return Option::Some(low);
        }

        return Option::Some(high);
    }

    fn extract_header_block_number(header: @Bytes) -> u256 {
        let (decoded_rlp, _) = rlp_decode(*header).unwrap();
        let block_number: u256 = match decoded_rlp {
            RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
            RLPItem::List(l) => {
                // Block number is the ninth's element in the list
                // TODO error handling
                (*l.at(9)).try_into().unwrap()
            },
        };

        block_number
    }

    fn extract_header_timestamp(header: @Bytes) -> u256 {
        let (decoded_rlp, _) = rlp_decode(*header).unwrap();
        let timestamp: u256 = match decoded_rlp {
            RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
            RLPItem::List(l) => {
                // Timestamp is the twelfth's element in the list
                // TODO error handling
                (*l.at(12)).try_into().unwrap()
            },
        };

        timestamp
    }

    // TODO: port helper functions below to cairo-lib

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
}
