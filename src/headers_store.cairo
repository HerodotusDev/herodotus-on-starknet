use starknet::ContractAddress;
use cairo_lib::data_structures::mmr::peaks::Peaks;
use cairo_lib::data_structures::mmr::proof::Proof;
use cairo_lib::utils::types::bytes::Bytes;

#[starknet::interface]
trait IHeadersStore<TContractState> {
    fn get_commitments_inbox(self: @TContractState) -> ContractAddress;
    fn get_mmr_root(self: @TContractState, mmr_id: usize) -> felt252;
    fn get_mmr_size(self: @TContractState, mmr_id: usize) -> usize;
    fn get_received_block(self: @TContractState, block_number: u256) -> u256;

    fn receive_hash(ref self: TContractState, blockhash: u256, block_number: u256);
    fn process_received_block(
        ref self: TContractState,
        block_number: u256, 
        header_rlp: Bytes,
        mmr_peaks: Peaks,
        mmr_id: usize,
    );
    fn process_chunk(
        ref self: TContractState,
        initial_block: u256, 
        headers_rlp: Span<Bytes>,
        mmr_peaks: Peaks,
        mmr_id: usize,
    );

    fn verify_mmr_inclusion(
        self: @TContractState,
        index: usize,
        blockhash: felt252,
        peaks: Peaks,
        proof: Proof,
        mmr_id: usize,
    ) -> bool;
}

#[starknet::contract]
mod HeadersStore {
    use starknet::{ContractAddress, get_caller_address};
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use cairo_lib::data_structures::mmr::peaks::Peaks;
    use cairo_lib::data_structures::mmr::proof::Proof;
    use cairo_lib::utils::types::bytes::{Bytes, BytesTryIntoU256};
    use cairo_lib::hashing::keccak::KeccakTrait;
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use cairo_lib::encoding::rlp::{RLPItem, rlp_decode};
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;

    #[storage]
    struct Storage {
        commitments_inbox: ContractAddress,
        mmr: LegacyMap::<usize, MMR>,
        received_blocks: LegacyMap::<u256, u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        HashReceived: HashReceived,
        ProcessedBlock: ProcessedBlock
    }

    #[derive(Drop, starknet::Event)]
    struct HashReceived {
        block_number: u256,
        blockhash: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ProcessedBlock {
        block_number: u256,
        blockhash: u256,
        blockhash_poseidon: felt252
    }

    #[constructor]
    fn constructor(ref self: ContractState, commitments_inbox: ContractAddress) {
        self.commitments_inbox.write(commitments_inbox);
        self.mmr.write(0, Default::default());
    }

    #[external(v0)]
    impl HeadersStore of super::IHeadersStore<ContractState> {
        fn get_commitments_inbox(self: @ContractState) -> ContractAddress {
            self.commitments_inbox.read()
        }

        fn get_mmr_root(self: @ContractState, mmr_id: usize) -> felt252 {
            self.mmr.read(mmr_id).root
        }

        fn get_mmr_size(self: @ContractState, mmr_id: usize) -> usize {
            self.mmr.read(mmr_id).last_pos
        }

        fn get_received_block(self: @ContractState, block_number: u256) -> u256 {
            self.received_blocks.read(block_number)
        }

        fn receive_hash(ref self: ContractState, blockhash: u256, block_number: u256) {
            let caller = get_caller_address();
            assert(caller == self.commitments_inbox.read(), 'Only CommitmentsInbox');

            self.received_blocks.write(block_number, blockhash);

            self.emit(Event::HashReceived(HashReceived {
                block_number,
                blockhash
            }));
        }

        fn process_received_block(
            ref self: ContractState,
            block_number: u256, 
            header_rlp: Bytes,
            mmr_peaks: Peaks,
            mmr_id: usize,
        ) {
            let blockhash = self.received_blocks.read(block_number);
            assert(blockhash != Zeroable::zero(), 'Block not received');

            let rlp_hash = KeccakTrait::keccak_cairo(header_rlp);
            assert(rlp_hash == blockhash, 'Invalid header rlp');

            let poseidon_hash = InternalFunctions::poseidon_hash_rlp(header_rlp);

            let mut mmr = self.mmr.read(mmr_id);
            mmr.append(poseidon_hash, mmr_peaks);

            self.emit(Event::ProcessedBlock(ProcessedBlock {
                block_number,
                blockhash,
                blockhash_poseidon: poseidon_hash
            }));
        }

        fn process_chunk(
            ref self: ContractState,
            initial_block: u256, 
            headers_rlp: Span<Bytes>,
            mmr_peaks: Peaks,
            mmr_id: usize,
        ) {
            let initial_blockhash = self.received_blocks.read(initial_block);
            assert(initial_blockhash != Zeroable::zero(), 'Block not received');

            let mut rlp_hash = KeccakTrait::keccak_cairo(*headers_rlp.at(0));
            assert(rlp_hash == initial_blockhash, 'Invalid initial header rlp');

            let mut i: usize = 1;
            loop {
                if i == headers_rlp.len() {
                    break ();
                }

                let child_rlp = *headers_rlp.at(i - 1);
                // TODO error handling
                let (decoded_rlp, _) = rlp_decode(child_rlp).unwrap();
                let parent_hash: u256 = match decoded_rlp {
                    RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
                    RLPItem::List(l) => {
                        // Parent hash is the first element in the list
                        // TODO error handling
                        (*l.at(0)).try_into().unwrap()
                    },
                };

                let current_rlp = *headers_rlp.at(i);
                let current_hash = KeccakTrait::keccak_cairo(current_rlp);
                assert(current_hash == parent_hash, 'Invalid header rlp');

                let poseidon_hash = InternalFunctions::poseidon_hash_rlp(current_rlp);

                let mut mmr = self.mmr.read(mmr_id);
                mmr.append(poseidon_hash, mmr_peaks);

                self.emit(Event::ProcessedBlock(ProcessedBlock {
                    block_number: initial_block - i.into(),
                    blockhash: current_hash,
                    blockhash_poseidon: poseidon_hash
                }));

                i += 1;
            };
        }

        fn verify_mmr_inclusion(
            self: @ContractState,
            index: usize,
            blockhash: felt252,
            peaks: Peaks,
            proof: Proof,
            mmr_id: usize,
        ) -> bool {
            let mmr = self.mmr.read(mmr_id);
            // TODO error handling
            mmr.verify_proof(index, blockhash, peaks, proof).unwrap()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn poseidon_hash_rlp(rlp: Bytes) -> felt252 {
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
