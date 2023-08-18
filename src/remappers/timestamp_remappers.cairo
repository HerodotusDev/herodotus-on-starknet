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

#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    fn create_mapper(ref self: TContractState, start_block: u256) -> usize;

    fn reindex_batch(
        ref self: TContractState,
        mapper_id: usize,
        mapper_peaks: Peaks,
        origin_elements: Span<OriginElement>
    );
}

#[starknet::contract]
mod TimestampRemappers {
    use super::{
        ITimestampRemappers, Headers, OriginElement, Proof, Peaks, SpanTrait, Bytes,
        BytesTryIntoU256
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
}
