// SPDX-License-Identifier: GPL-3.0

use starknet::ContractAddress;
use cairo_lib::data_structures::mmr::proof::Proof;
use cairo_lib::data_structures::mmr::peaks::Peaks;
use cairo_lib::utils::types::words64::Words64;

#[derive(Drop, Serde)]
enum AccountField {
    StorageHash: (),
    CodeHash: (),
    Balance: (),
    Nonce: ()
}

//
// Interface
//

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    // Returns the address of the contract that stores the headers.
    fn get_headers_store(self: @TContractState) -> ContractAddress;

    // Returns the value of the given field of the given account at the given block.
    fn get_account_field(
        self: @TContractState, account: felt252, block: u256, field: AccountField
    ) -> Option<u256>;

    // Returns the value of the given slot of the given account at the given block.
    fn get_slot_value(
        self: @TContractState, account: felt252, block: u256, slot: u256
    ) -> Option<u256>;

    // Returns the value of the given field(s) of the given account at the given block.
    // @param fields: The fields to return.
    // @param block_header_rlp: The RLP of the block header.
    // @param account: The account to query.
    // @param mpt_proof: The MPT proof of the account.
    // @param mmr_index: The index of the block in the MMR.
    // @param mmr_peaks: The peaks of the MMR.
    // @param mmr_proof: The proof of the MMR.
    // @param mmr_id: The id of the MMR.
    // @param last_pos The size of the MMR at the time of the proof generation (i.e., leaves count).
    fn get_account(
        self: @TContractState,
        fields: Span<AccountField>,
        block_header_rlp: Words64,
        account: felt252,
        mpt_proof: Span<Words64>,
        mmr_index: usize,
        mmr_peaks: Peaks,
        mmr_proof: Proof,
        mmr_id: usize,
        last_pos: usize,
    ) -> Span<u256>;

    // Returns the value of the given slot of the given account at the given block.
    // @param block: The block number.
    // @param account: The account to query.
    // @param slot: The slot to query.
    // @param slot_len: The length of the slot.
    // @param mpt_proof: The MPT proof of the account.
    fn get_storage(
        self: @TContractState,
        block: u256,
        account: felt252,
        slot: u256,
        slot_len: usize,
        mpt_proof: Span<Words64>
    ) -> u256;

    // Proves the value of the given field(s) of the given account at the given block.
    // @param fields: The fields to prove.
    // @param block_header_rlp: The RLP of the block header.
    // @param account: The account to prove.
    // @param mpt_proof: The MPT proof of the account.
    // @param mmr_index: The index of the block in the MMR.
    // @param mmr_peaks: The peaks of the MMR.
    // @param mmr_proof: The proof of the MMR.
    // @param mmr_id: The id of the MMR.
    // @param last_pos The size of the MMR at the time of the proof generation (i.e., leaves count).
    fn prove_account(
        ref self: TContractState,
        fields: Span<AccountField>,
        block_header_rlp: Words64,
        account: felt252,
        mpt_proof: Span<Words64>,
        mmr_index: usize,
        mmr_peaks: Peaks,
        mmr_proof: Proof,
        mmr_id: usize,
        last_pos: usize,
    );

    // Proves the value of the given slot of the given account at the given block.
    // @param block: The block number.
    // @param account: The account to prove.
    // @param slot: The slot to prove.
    // @param slot_len: The length of the slot.
    // @param mpt_proof: The MPT proof of the account.
    fn prove_storage(
        ref self: TContractState,
        block: u256,
        account: felt252,
        slot: u256,
        slot_len: usize,
        mpt_proof: Span<Words64>
    );
}

//
// Contract
//

#[starknet::contract]
mod EVMFactsRegistry {
    use starknet::ContractAddress;
    use super::AccountField;
    use cairo_lib::data_structures::mmr::proof::Proof;
    use cairo_lib::data_structures::mmr::peaks::Peaks;
    use cairo_lib::hashing::poseidon::hash_words64;
    use cairo_lib::data_structures::eth_mpt::MPTTrait;
    use cairo_lib::encoding::rlp::{RLPItem, rlp_decode};
    use cairo_lib::utils::types::words64::{
        Words64, Words64TryIntoU256LE, reverse_endianness_u64, bytes_used_u64
    };
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    //
    // Storage
    //

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        // Update to EthAddress when supported
        // (account_address, block_number) => value
        storage_hash: LegacyMap::<(felt252, u256), Option<u256>>,
        code_hash: LegacyMap::<(felt252, u256), Option<u256>>,
        balance: LegacyMap::<(felt252, u256), Option<u256>>,
        nonce: LegacyMap::<(felt252, u256), Option<u256>>,
        // (account_address, block_number, slot) => value
        slot_values: LegacyMap::<(felt252, u256, u256), Option<u256>>
    }

    //
    // Events
    //

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountProven: AccountProven,
        StorageProven: StorageProven
    }

    #[derive(Drop, starknet::Event)]
    struct AccountProven {
        account: felt252,
        block: u256,
        fields: Span<AccountField>
    }

    #[derive(Drop, starknet::Event)]
    struct StorageProven {
        account: felt252,
        block: u256,
        slot: u256,
        value: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, headers_store: ContractAddress) {
        self.headers_store.write(headers_store);
    }

    //
    // External
    //

    #[external(v0)]
    impl EVMFactsRegistry of super::IEVMFactsRegistry<ContractState> {
        fn get_headers_store(self: @ContractState) -> ContractAddress {
            self.headers_store.read()
        }

        fn get_account_field(
            self: @ContractState, account: felt252, block: u256, field: AccountField
        ) -> Option<u256> {
            match field {
                AccountField::StorageHash(_) => self.storage_hash.read((account, block)),
                AccountField::CodeHash(_) => self.code_hash.read((account, block)),
                AccountField::Balance(_) => self.balance.read((account, block)),
                AccountField::Nonce(_) => self.nonce.read((account, block))
            }
        }

        fn get_slot_value(
            self: @ContractState, account: felt252, block: u256, slot: u256
        ) -> Option<u256> {
            self.slot_values.read((account, block, slot))
        }

        fn get_account(
            self: @ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: felt252,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
            last_pos: usize,
        ) -> Span<u256> {
            let (_, fields) = InternalFunctions::get_account(
                self,
                fields,
                block_header_rlp,
                account,
                mpt_proof,
                mmr_index,
                mmr_peaks,
                mmr_proof,
                mmr_id,
                last_pos
            );

            fields
        }

        fn get_storage(
            self: @ContractState,
            block: u256,
            account: felt252,
            slot: u256,
            slot_len: usize,
            mpt_proof: Span<Words64>
        ) -> u256 {
            let storage_hash = self
                .storage_hash
                .read((account, block))
                .expect('Storage hash not proven');

            let mpt = MPTTrait::new(storage_hash);
            let value = mpt.verify(slot, slot_len, mpt_proof).expect('MPT verification failed');

            value.try_into().unwrap()
        }

        fn prove_account(
            ref self: ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: felt252,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
            last_pos: usize,
        ) {
            let (block, field_values) = InternalFunctions::get_account(
                @self,
                fields,
                block_header_rlp,
                account,
                mpt_proof,
                mmr_index,
                mmr_peaks,
                mmr_proof,
                mmr_id,
                last_pos
            );

            let mut i: usize = 0;
            loop {
                if i == field_values.len() {
                    break ();
                }

                let field = fields.at(i);
                let value = Option::Some(*field_values.at(i));

                match field {
                    AccountField::StorageHash(_) => {
                        self.storage_hash.write((account, block), value);
                    },
                    AccountField::CodeHash(_) => {
                        self.code_hash.write((account, block), value);
                    },
                    AccountField::Balance(_) => {
                        self.balance.write((account, block), value);
                    },
                    AccountField::Nonce(_) => {
                        self.nonce.write((account, block), value);
                    }
                };

                i += 1;
            };

            self.emit(Event::AccountProven(AccountProven { account, block, fields }));
        }

        fn prove_storage(
            ref self: ContractState,
            block: u256,
            account: felt252,
            slot: u256,
            slot_len: usize,
            mpt_proof: Span<Words64>
        ) {
            let value = EVMFactsRegistry::get_storage(
                @self, block, account, slot, slot_len, mpt_proof
            );
            self.slot_values.write((account, block, slot), Option::Some(value));

            self.emit(Event::StorageProven(StorageProven { account, block, slot, value: value }));
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        // returns (block_number, account_fields)
        fn get_account(
            self: @ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: felt252,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
            last_pos: usize,
        ) -> (u256, Span<u256>) {
            let blockhash = hash_words64(block_header_rlp);

            let contract_address = self.headers_store.read();
            let mmr_inclusion = IHeadersStoreDispatcher { contract_address }
                .verify_historical_mmr_inclusion(
                    mmr_index, blockhash, mmr_peaks, mmr_proof, mmr_id, last_pos
                );
            assert(mmr_inclusion, 'MMR inclusion not proven');

            let (decoded_rlp, _) = rlp_decode(block_header_rlp).expect('Invalid header rlp');
            let mut state_root: u256 = 0;
            let mut block_number: u256 = 0;
            match decoded_rlp {
                RLPItem::Bytes(_) => panic_with_felt252('Invalid header rlp'),
                RLPItem::List(l) => {
                    state_root = (*l.at(3)).try_into().unwrap();

                    let block_number_words = *l.at(8);
                    assert(block_number_words.len() == 1, 'Invalid block number');

                    let block_number_le = *block_number_words.at(0);
                    block_number =
                        reverse_endianness_u64(
                            block_number_le, Option::Some(bytes_used_u64(block_number_le))
                        )
                        .into();
                },
            };

            let mpt = MPTTrait::new(state_root);
            let rlp_account = mpt
                .verify(account.into(), 32, mpt_proof)
                .expect('MPT verification failed');

            let (decoded_account, _) = rlp_decode(rlp_account).expect('Invalid account rlp');
            let mut account_fields = ArrayTrait::new();
            match decoded_account {
                RLPItem::Bytes(_) => panic_with_felt252('Invalid account rlp'),
                RLPItem::List(l) => {
                    let mut i: usize = 0;
                    loop {
                        if i == fields.len() {
                            break ();
                        }

                        let field = fields.at(i);
                        let field_value = match field {
                            AccountField::StorageHash(_) => {
                                *l.at(2)
                            },
                            AccountField::CodeHash(_) => {
                                *l.at(3)
                            },
                            AccountField::Balance(_) => {
                                *l.at(0)
                            },
                            AccountField::Nonce(_) => {
                                *l.at(1)
                            },
                        };

                        account_fields.append(field_value.try_into().unwrap());

                        i += 1;
                    };
                },
            };

            (block_number, account_fields.span())
        }
    }
}
