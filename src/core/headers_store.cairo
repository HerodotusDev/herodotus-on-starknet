// SPDX-License-Identifier: GPL-3.0

use starknet::ContractAddress;
use cairo_lib::data_structures::mmr::peaks::Peaks;
use cairo_lib::data_structures::mmr::proof::Proof;
use cairo_lib::utils::types::words64::Words64;
use cairo_lib::data_structures::mmr::mmr::MMR;

//
// Interface
//

#[starknet::interface]
trait IHeadersStore<TContractState> {
    // Returns the address of the CommitmentsInbox contract.
    fn get_commitments_inbox(self: @TContractState) -> ContractAddress;

    // Returns the MMR with the given id.
    fn get_mmr(self: @TContractState, mmr_id: usize) -> MMR;

    // Returns the root of the MMR with the given id.
    fn get_mmr_root(self: @TContractState, mmr_id: usize) -> felt252;

    // Returns the size of the MMR with the given id.
    fn get_mmr_size(self: @TContractState, mmr_id: usize) -> usize;

    // Returns the blockhash of the block with the given number (if previously received).
    fn get_received_block(self: @TContractState, block_number: u256) -> u256;

    // Returns the latest MMR id.
    fn get_latest_mmr_id(self: @TContractState) -> usize;

    // Returns the root of the MMR with the given id and size.
    fn get_historical_root(self: @TContractState, mmr_id: usize, size: usize) -> felt252;

    // Receives a blockhash of a specific block number.
    // @notice Only the CommitmentsInbox contract can call this function.
    fn receive_hash(ref self: TContractState, blockhash: u256, block_number: u256);

    // Verifies an inclusion proof in the MMR with the given id.
    // @param index The index of the element in the MMR.
    // @param poseidon_blockhash The Poseidon hash of the blockhash.
    // @param peaks The peaks of the MMR.
    // @param proof The inclusion proof (i.e., siblings path to the root hash).
    // @param mmr_id The id of the MMR.
    fn verify_mmr_inclusion(
        self: @TContractState,
        index: usize,
        poseidon_blockhash: felt252,
        peaks: Peaks,
        proof: Proof,
        mmr_id: usize,
    ) -> bool;

    // Verifies an inclusion proof in a historical MMR.
    // @notice This type of proof does not expire even if the MMR grows after its generation.
    // @param index The index of the element in the MMR.
    // @param poseidon_blockhash The Poseidon hash of the blockhash.
    // @param peaks The peaks of the MMR.
    // @param proof The inclusion proof (i.e., siblings path to the root hash).
    // @param mmr_id The id of the MMR.
    // @param last_pos The size of the MMR at the time of the proof generation (i.e., leaves count).
    fn verify_historical_mmr_inclusion(
        self: @TContractState,
        index: usize,
        poseidon_blockhash: felt252,
        peaks: Peaks,
        proof: Proof,
        mmr_id: usize,
        last_pos: usize,
    ) -> bool;

    // Processes a received block and appends it to the MMR with the given id.
    // @param block_number The block number of the received block.
    // @param header_rlp The RLP of the block header.
    // @param mmr_peaks The peaks of the MMR.
    // @param mmr_id The id of the MMR.
    fn process_received_block(
        ref self: TContractState,
        block_number: u256,
        header_rlp: Words64,
        mmr_peaks: Peaks,
        mmr_id: usize,
    );

    // Processes a batch of received blocks and appends them to the MMR with the given id.
    // @param headers_rlp The RLP of the block headers.
    // @param mmr_peaks The peaks of the MMR.
    // @param mmr_id The id of the MMR.
    // @param reference_block The block number of a received block used as reference to process the batch.
    // @param mmr_index The MMR index of an existing block used as reference to process the batch.
    // @param mmr_proof The inclusion proof of the reference block.
    fn process_batch(
        ref self: TContractState,
        headers_rlp: Span<Words64>,
        mmr_peaks: Peaks,
        mmr_id: usize,
        reference_block: Option<u256>,
        mmr_index: Option<usize>,
        mmr_proof: Option<Proof>,
    );

    // Creates a new MMR with the given root and size based from a provided `root` and `last_pos`.
    // @notice Only the CommitmentsInbox contract can call this function.
    fn create_branch_from_message(
        ref self: TContractState, root: felt252, last_pos: usize, aggregator_id: usize
    );

    // Creates a new MMR with a single element based on another MMR.
    // @param index The index of the element in the MMR.
    // @param initial_poseidon_blockhash The Poseidon hash of the blockhash.
    // @param peaks The peaks of the MMR.
    // @param proof The inclusion proof (i.e., siblings path to the root hash).
    // @param mmr_id The id of the MMR.
    fn create_branch_single_element(
        ref self: TContractState,
        index: usize,
        initial_poseidon_blockhash: felt252,
        peaks: Peaks,
        proof: Proof,
        mmr_id: usize,
    );

    // Creates a new MMR with the same root and size as the MMR with the given id.
    fn create_branch_from(ref self: TContractState, mmr_id: usize);
}


//
// Contract
//

#[starknet::contract]
mod HeadersStore {
    use starknet::{ContractAddress, get_caller_address};
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use cairo_lib::data_structures::mmr::peaks::Peaks;
    use cairo_lib::data_structures::mmr::proof::Proof;
    use cairo_lib::utils::types::words64::{
        Words64, Words64TryIntoU256LE, reverse_endianness_u64, bytes_used_u64
    };
    use cairo_lib::hashing::keccak::keccak_cairo_words64;
    use cairo_lib::hashing::poseidon::hash_words64;
    use cairo_lib::utils::bitwise::reverse_endianness_u256;
    use cairo_lib::encoding::rlp::{RLPItem, rlp_decode};

    //
    // Constants
    //

    const MMR_INITIAL_ROOT: felt252 =
        0x6759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

    //
    // Storage
    //

    #[storage]
    struct Storage {
        commitments_inbox: ContractAddress,
        mmr: LegacyMap::<usize, MMR>,
        // (id, size) => root
        mmr_history: LegacyMap::<(usize, usize), felt252>,
        received_blocks: LegacyMap::<u256, u256>,
        latest_mmr_id: usize
    }

    //
    // Events
    //

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        HashReceived: HashReceived,
        ProcessedBlock: ProcessedBlock,
        ProcessedBatch: ProcessedBatch,
        BranchCreated: BranchCreated,
        BranchCreatedFromL1: BranchCreatedFromL1
    }

    #[derive(Drop, starknet::Event)]
    struct HashReceived {
        block_number: u256,
        blockhash: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ProcessedBlock {
        block_number: u256,
        new_root: felt252,
        new_size: usize,
        mmr_id: usize
    }

    #[derive(Drop, starknet::Event)]
    struct ProcessedBatch {
        block_start: u256,
        block_end: u256,
        new_root: felt252,
        new_size: usize,
        mmr_id: usize
    }

    #[derive(Drop, starknet::Event)]
    struct BranchCreated {
        mmr_id: usize,
        root: felt252,
        last_pos: usize,
        detached_from_mmr_id: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct BranchCreatedFromL1 {
        mmr_id: usize,
        root: felt252,
        last_pos: usize,
        aggregator_id: usize,
    }

    #[constructor]
    fn constructor(ref self: ContractState, commitments_inbox: ContractAddress) {
        self.commitments_inbox.write(commitments_inbox);

        let mmr: MMR = MMRTrait::new(MMR_INITIAL_ROOT, 1);
        let root = mmr.root;

        self.mmr.write(0, mmr);
        self.mmr_history.write((0, 1), root);
        self.latest_mmr_id.write(0);
    }


    //
    // External
    //

    #[external(v0)]
    impl HeadersStore of super::IHeadersStore<ContractState> {
        fn get_commitments_inbox(self: @ContractState) -> ContractAddress {
            self.commitments_inbox.read()
        }

        fn get_mmr(self: @ContractState, mmr_id: usize) -> MMR {
            self.mmr.read(mmr_id)
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

        fn get_latest_mmr_id(self: @ContractState) -> usize {
            self.latest_mmr_id.read()
        }

        fn get_historical_root(self: @ContractState, mmr_id: usize, size: usize) -> felt252 {
            self.mmr_history.read((mmr_id, size))
        }

        fn receive_hash(ref self: ContractState, blockhash: u256, block_number: u256) {
            let caller = get_caller_address();
            assert(caller == self.commitments_inbox.read(), 'Only CommitmentsInbox');

            self.received_blocks.write(block_number, blockhash);

            self.emit(Event::HashReceived(HashReceived { block_number, blockhash }));
        }

        fn process_received_block(
            ref self: ContractState,
            block_number: u256,
            header_rlp: Words64,
            mmr_peaks: Peaks,
            mmr_id: usize,
        ) {
            let blockhash = self.received_blocks.read(block_number);
            assert(blockhash != Zeroable::zero(), 'Block not received');

            let rlp_hash = InternalFunctions::keccak_hash_rlp(header_rlp, true);
            assert(rlp_hash == blockhash, 'Invalid header rlp');

            let poseidon_hash = hash_words64(header_rlp);

            let mut mmr = self.mmr.read(mmr_id);
            mmr.append(poseidon_hash, mmr_peaks).expect('Failed to append to MMR');
            self.mmr.write(mmr_id, mmr.clone());

            self.mmr_history.write((mmr_id, mmr.last_pos), mmr.root);

            self
                .emit(
                    Event::ProcessedBlock(
                        ProcessedBlock {
                            block_number, new_root: mmr.root, new_size: mmr.last_pos, mmr_id
                        }
                    )
                );
        }

        fn process_batch(
            ref self: ContractState,
            headers_rlp: Span<Words64>,
            mmr_peaks: Peaks,
            mmr_id: usize,
            reference_block: Option<u256>,
            mmr_index: Option<usize>,
            mmr_proof: Option<Proof>,
        ) {
            let mut mmr = self.mmr.read(mmr_id);
            let poseidon_hash = hash_words64(*headers_rlp.at(0));
            let mut peaks = mmr_peaks;
            let mut start_block = 0;

            if mmr_proof.is_some() {
                let valid_proof = mmr
                    .verify_proof(mmr_index.unwrap(), poseidon_hash, mmr_peaks, mmr_proof.unwrap())
                    .expect('MMR proof verification failed');
                assert(valid_proof, 'Invalid proof');
            } else {
                start_block = reference_block.unwrap();
                let initial_blockhash = self.received_blocks.read(start_block);
                assert(initial_blockhash != Zeroable::zero(), 'Block not received');

                let rlp_hash = InternalFunctions::keccak_hash_rlp(*headers_rlp.at(0), true);
                assert(rlp_hash == initial_blockhash, 'Invalid initial header rlp');

                let (_, p) = mmr.append(poseidon_hash, mmr_peaks).expect('Failed to append to MMR');
                peaks = p;
            }

            let mut i: usize = 1;
            loop {
                if i == headers_rlp.len() {
                    break ();
                }

                let child_rlp = *headers_rlp.at(i - 1);
                let (decoded_rlp, _) = rlp_decode(child_rlp).expect('Invalid header rlp');
                let parent_hash: u256 = match decoded_rlp {
                    RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
                    RLPItem::List(l) => {
                        if i == 1 && reference_block.is_none() {
                            let start_block_words = *l.at(8);
                            assert(start_block_words.len() == 1, 'Invalid start_block');

                            let start_block_le = *start_block_words.at(0);
                            start_block =
                                reverse_endianness_u64(
                                    start_block_le, Option::Some(bytes_used_u64(start_block_le))
                                )
                                .into();
                        }
                        let words = *l.at(0);
                        assert(words.len() == 4, 'Invalid parent_hash rlp');
                        words.try_into().unwrap()
                    },
                };

                let current_rlp = *headers_rlp.at(i);
                let current_hash = InternalFunctions::keccak_hash_rlp(current_rlp, false);
                assert(current_hash == parent_hash, 'Invalid header rlp');

                let poseidon_hash = hash_words64(current_rlp);

                let (_, p) = mmr.append(poseidon_hash, peaks).expect('Failed to append to MMR');
                peaks = p;

                i += 1;
            };

            self.mmr.write(mmr_id, mmr.clone());
            self.mmr_history.write((mmr_id, mmr.last_pos), mmr.root);

            self
                .emit(
                    Event::ProcessedBatch(
                        ProcessedBatch {
                            block_start: start_block,
                            block_end: start_block - headers_rlp.len().into() + 1,
                            new_root: mmr.root,
                            new_size: mmr.last_pos,
                            mmr_id
                        }
                    )
                );
        }

        fn verify_mmr_inclusion(
            self: @ContractState,
            index: usize,
            poseidon_blockhash: felt252,
            peaks: Peaks,
            proof: Proof,
            mmr_id: usize,
        ) -> bool {
            let mmr = self.mmr.read(mmr_id);

            mmr
                .verify_proof(index, poseidon_blockhash, peaks, proof)
                .expect('MMR proof verification failed')
        }

        fn verify_historical_mmr_inclusion(
            self: @ContractState,
            index: usize,
            poseidon_blockhash: felt252,
            peaks: Peaks,
            proof: Proof,
            mmr_id: usize,
            last_pos: usize,
        ) -> bool {
            let root = self.mmr_history.read((mmr_id, last_pos));
            let mmr = MMRTrait::new(root, last_pos);

            mmr
                .verify_proof(index, poseidon_blockhash, peaks, proof)
                .expect('MMR proof verification failed')
        }

        fn create_branch_from_message(
            ref self: ContractState, root: felt252, last_pos: usize, aggregator_id: usize
        ) {
            let caller = get_caller_address();
            assert(caller == self.commitments_inbox.read(), 'Only CommitmentsInbox');

            let mmr_id = self.latest_mmr_id.read() + 1;
            let mmr = MMRTrait::new(root, last_pos);
            self.mmr.write(mmr_id, mmr);
            self.mmr_history.write((mmr_id, last_pos), root);
            self.latest_mmr_id.write(mmr_id);

            self
                .emit(
                    Event::BranchCreatedFromL1(
                        BranchCreatedFromL1 { mmr_id, root, last_pos, aggregator_id }
                    )
                );
        }

        fn create_branch_single_element(
            ref self: ContractState,
            index: usize,
            initial_poseidon_blockhash: felt252,
            peaks: Peaks,
            proof: Proof,
            mmr_id: usize,
        ) {
            assert(
                HeadersStore::verify_mmr_inclusion(
                    @self, index, initial_poseidon_blockhash, peaks, proof, mmr_id
                ),
                'Invalid proof'
            );

            let mut mmr: MMR = Default::default();
            mmr.append(initial_poseidon_blockhash, array![].span());

            let root = mmr.root;
            let last_pos = mmr.last_pos;

            let latest_mmr_id = self.latest_mmr_id.read() + 1;
            self.mmr.write(latest_mmr_id, mmr);
            self.mmr_history.write((latest_mmr_id, last_pos), root);
            self.latest_mmr_id.write(latest_mmr_id);

            self
                .emit(
                    Event::BranchCreated(
                        BranchCreated {
                            mmr_id: latest_mmr_id, root, last_pos, detached_from_mmr_id: mmr_id
                        }
                    )
                );
        }

        fn create_branch_from(ref self: ContractState, mmr_id: usize) {
            let latest_mmr_id = self.latest_mmr_id.read() + 1;
            let mmr = self.mmr.read(mmr_id);

            let root = mmr.root;
            let last_pos = mmr.last_pos;

            self.mmr.write(latest_mmr_id, mmr.clone());
            self.mmr_history.write((latest_mmr_id, last_pos), root);
            self.latest_mmr_id.write(latest_mmr_id);

            self
                .emit(
                    Event::BranchCreated(
                        BranchCreated {
                            mmr_id: latest_mmr_id, root, last_pos, detached_from_mmr_id: mmr_id
                        }
                    )
                );
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn keccak_hash_rlp(rlp: Words64, big_endian: bool) -> u256 {
            let mut hash = keccak_cairo_words64(rlp);
            if big_endian {
                reverse_endianness_u256(hash)
            } else {
                hash
            }
        }
    }
}
