use core::clone::Clone;
use core::array::SpanTrait;
use cairo_lib::data_structures::mmr::proof::Proof;
use cairo_lib::data_structures::mmr::peaks::Peaks;
use cairo_lib::utils::types::words64::Words64;

type Headers = Span<Words64>;

#[derive(Drop, Serde)]
struct OriginElement {
    tree_id: usize,
    tree_size: usize,
    leaf_idx: usize,
    leaf_value: felt252,
    inclusion_proof: Proof,
    peaks: Peaks,
    header: Words64
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
    mapper_id: usize,
    mmr_id: usize,
    proofs: Span<ProofElement>,
    left_neighbor: Option<ProofElement>,
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

    fn mmr_binary_search(self: @TContractState, tree: BinarySearchTree, x: u256) -> Option<u256>;

    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Option<u256>;
}

#[starknet::contract]
mod TimestampRemappers {
    use super::{
        ITimestampRemappers, Headers, OriginElement, Proof, Peaks, SpanTrait, Words64, ProofElement,
        BinarySearchTree
    };
    use starknet::{ContractAddress};
    use zeroable::Zeroable;
    use option::OptionTrait;
    use result::ResultTrait;
    use traits::{Into, TryInto};

    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    use array::{ArrayTrait};
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use cairo_lib::encoding::rlp::{RLPItem, rlp_decode};
    use cairo_lib::utils::types::words64::{reverse_endianness, bytes_used};
    use clone::Clone;
    use debug::PrintTrait;

    #[derive(Drop, Clone, starknet::Store)]
    struct Mapper {
        start_block: u256,
        elements_count: u256,
        mmr: MMR
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MapperCreated: MapperCreated,
        RemappedBlocks: RemappedBlocks
    }

    #[derive(Drop, starknet::Event)]
    struct MapperCreated {
        mapper_id: usize,
        start_block: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RemappedBlocks {
        mapper_id: usize,
        start_block: u256,
        end_block: u256,
        mmr_root: felt252,
        mmr_size: usize
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
            let mapper = Mapper { start_block, elements_count: 0, mmr: Default::default(),  };

            let mapper_id = self.mappers_count.read();
            self.mappers.write(mapper_id, mapper);
            self.mappers_count.write(mapper_id + 1);

            self.emit(Event::MapperCreated(MapperCreated { mapper_id, start_block }));

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
            let mut mapper_mmr = mapper.mmr.clone();
            let mut mapper_peaks = mapper_peaks;

            let mut expected_block: u256 = mapper.start_block + mapper.elements_count + 1;
            if (mapper.elements_count == 0) {
                expected_block = mapper.start_block;
            }

            let mut idx = 0;
            let len = origin_elements.len();
            loop {
                if idx == len {
                    break ();
                }
                let origin_element: @OriginElement = origin_elements.at(idx);
                let origin_element_block_number = extract_header_block_number(
                    *origin_element.header
                );
                assert(origin_element_block_number == expected_block, 'Unexpected block number');

                let current_hash = InternalFunctions::poseidon_hash_rlp(*origin_element.header);
                assert(current_hash == *origin_element.leaf_value.into(), 'Invalid header rlp');

                let is_valid_proof = IHeadersStoreDispatcher {
                    contract_address: headers_store_addr
                }
                    .verify_historical_mmr_inclusion(
                        *origin_element.leaf_idx,
                        *origin_element.leaf_value,
                        *origin_element.peaks,
                        *origin_element.inclusion_proof,
                        *origin_element.tree_id,
                        *origin_element.tree_size
                    );
                assert(is_valid_proof, 'Invalid proof');

                let origin_element_timestamp = extract_header_timestamp(*origin_element.header);
                mapper_mmr.append(origin_element_timestamp.try_into().unwrap(), mapper_peaks);

                expected_block += 1;
                idx += 1;
            };

            mapper.elements_count += len.into();
            mapper.mmr = mapper_mmr.clone();

            self.mappers.write(mapper_id, mapper.clone());
            self
                .emit(
                    Event::RemappedBlocks(
                        RemappedBlocks {
                            mapper_id,
                            start_block: mapper.start_block,
                            end_block: expected_block,
                            mmr_root: mapper_mmr.root,
                            mmr_size: mapper_mmr.last_pos
                        }
                    )
                );
        }

        fn mmr_binary_search(
            self: @ContractState, tree: BinarySearchTree, x: u256
        ) -> Option<u256> {
            let mapper = self.mappers.read(tree.mapper_id);

            let mmr = mapper.mmr.clone();

            if mapper.elements_count == 0 {
                return Option::None(());
            }

            let elements_count = mapper.elements_count;
            let headers_store_addr = self.headers_store.read();

            let proofs: Span<ProofElement> = tree.proofs;
            let mut proof_idx = 0;

            let mut left: u256 = 0;
            let mut right: u256 = elements_count;
            loop {
                if left >= right {
                    break;
                }

                let mid: u256 = (left + right) / 2;
                let proof_element: ProofElement = *proofs.at(proof_idx);

                assert(
                    proof_element.index.into() == leaf_index_to_mmr_index(mid + 1),
                    'Unexpected proof index'
                );

                let mid_val: u256 = proof_element.value;
                let is_valid_proof = mapper
                    .mmr
                    .verify_proof(
                        index: proof_element.index,
                        hash: mid_val.try_into().unwrap(),
                        peaks: proof_element.peaks,
                        proof: proof_element.proof,
                    )
                    .unwrap();
                assert(is_valid_proof, 'Invalid proof');
                if x >= mid_val {
                    left = mid + 1;
                } else {
                    right = mid;
                }
                proof_idx += 1;
            };
            if left == 0 {
                return Option::None(());
            }
            let closest_idx: u256 = left - 1;
            let tree_closest_low_val = tree.left_neighbor.unwrap();

            assert(
                tree_closest_low_val.index.into() == leaf_index_to_mmr_index(closest_idx + 1),
                'Unexpected proof index (c)'
            );

            let is_valid_low_proof = mmr
                .verify_proof(
                    tree_closest_low_val.index,
                    tree_closest_low_val.value.try_into().unwrap(),
                    tree_closest_low_val.peaks,
                    tree_closest_low_val.proof,
                )
                .unwrap();
            assert(is_valid_low_proof, 'Invalid proof');
            return Option::Some(closest_idx);
        }

        fn get_closest_l1_block_number(
            self: @ContractState, tree: BinarySearchTree, timestamp: u256
        ) -> Option<u256> {
            let mapper = self.mappers.read(tree.mapper_id);
            let mapper_mmr = mapper.mmr;

            let mapper_idx = self.mmr_binary_search(tree, timestamp);
            if mapper_idx.is_none() {
                return Option::None(());
            }

            let corresponding_block_number: u256 = mapper.start_block + mapper_idx.unwrap();
            Option::Some(corresponding_block_number)
        }
    }

    fn extract_header_block_number(header: Words64) -> u256 {
        let (decoded_rlp, _) = rlp_decode(header).unwrap();
        let block_number: u64 = match decoded_rlp {
            RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
            RLPItem::List(l) => {
                // Block number is the eight's element in the list
                // TODO error handling
                *(*l.at(8)).at(0)
            },
        };
        reverse_endianness(block_number, Option::Some(bytes_used(block_number).into())).into()
    }

    fn extract_header_timestamp(header: Words64) -> u256 {
        let (decoded_rlp, _) = rlp_decode(header).unwrap();
        let timestamp: u64 = match decoded_rlp {
            RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
            RLPItem::List(l) => {
                // Timestamp is the eleventh's element in the list
                // TODO error handling
                *(*l.at(11)).at(0)
            },
        };
        reverse_endianness(timestamp, Option::Some(bytes_used(timestamp).into())).into()
    }

    // TODO: port to cairo-lib
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

    // TODO: port to cairo-lib
    fn leaf_index_to_mmr_index(n: u256) -> u256 {
        2 * n - 1 - count_ones(n - 1)
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn poseidon_hash_rlp(rlp: Words64) -> felt252 {
            // TODO refactor hashing logic
            let mut rlp_felt_arr: Array<felt252> = ArrayTrait::new();
            let mut i: usize = 0;
            loop {
                if i >= rlp.len() {
                    break ();
                }

                rlp_felt_arr.append((*rlp.at(i)).into());
                i += 1;
            };

            PoseidonHasher::hash_many(rlp_felt_arr.span())
        }
    }
}
