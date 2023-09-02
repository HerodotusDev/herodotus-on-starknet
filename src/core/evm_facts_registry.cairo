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

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    fn get_headers_store(self: @TContractState) -> ContractAddress;

    fn get_account_field(
        self: @TContractState, account: felt252, block: u256, field: AccountField
    ) -> u256;
    fn get_slot_value(self: @TContractState, account: felt252, block: u256, slot: u256) -> u256;

    fn get_account(
        self: @TContractState,
        fields: Span<AccountField>,
        block_header_rlp: Words64,
        account: Words64,
        mpt_proof: Span<Words64>,
        mmr_index: usize,
        mmr_peaks: Peaks,
        mmr_proof: Proof,
        mmr_id: usize,
    ) -> Span<u256>;
    fn get_storage(
        self: @TContractState, block: u256, account: felt252, slot: Words64, mpt_proof: Span<Words64>
    ) -> u256;

    fn prove_account(
        ref self: TContractState,
        fields: Span<AccountField>,
        block_header_rlp: Words64,
        account: Words64,
        mpt_proof: Span<Words64>,
        mmr_index: usize,
        mmr_peaks: Peaks,
        mmr_proof: Proof,
        mmr_id: usize,
    );
    fn prove_storage(
        ref self: TContractState, block: u256, account: felt252, slot: Words64, mpt_proof: Span<Words64>
    );
}

#[starknet::contract]
mod EVMFactsRegistry {
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use super::AccountField;
    use cairo_lib::data_structures::mmr::proof::Proof;
    use cairo_lib::data_structures::mmr::peaks::Peaks;
    use cairo_lib::hashing::poseidon::PoseidonHasher;
    use cairo_lib::data_structures::eth_mpt_words64::MPTWords64Trait;
    use cairo_lib::encoding::rlp_word64::{RLPItemWord64, rlp_decode_word64};
    use cairo_lib::utils::types::words64::Words64;
    use result::ResultTrait;
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use array::{ArrayTrait, SpanTrait};
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        // Update to EthAddress when supported
        // (account_address, block_number) => value
        storage_hash: LegacyMap::<(felt252, u256), u256>,
        code_hash: LegacyMap::<(felt252, u256), u256>,
        balance: LegacyMap::<(felt252, u256), u256>,
        nonce: LegacyMap::<(felt252, u256), u256>,
        // (account_address, block_number, slot) => value
        slot_values: LegacyMap::<(felt252, u256, u256), u256>
    }

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

    #[external(v0)]
    impl EVMFactsRegistry of super::IEVMFactsRegistry<ContractState> {
        fn get_headers_store(self: @ContractState) -> ContractAddress {
            self.headers_store.read()
        }

        fn get_account_field(
            self: @ContractState, account: felt252, block: u256, field: AccountField
        ) -> u256 {
            match field {
                AccountField::StorageHash(_) => self.storage_hash.read((account, block)),
                AccountField::CodeHash(_) => self.code_hash.read((account, block)),
                AccountField::Balance(_) => self.balance.read((account, block)),
                AccountField::Nonce(_) => self.nonce.read((account, block))
            }
        }

        fn get_slot_value(self: @ContractState, account: felt252, block: u256, slot: u256) -> u256 {
            self.slot_values.read((account, block, slot))
        }

        fn get_account(
            self: @ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: Words64,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
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
                mmr_id
            );

            fields
        }

        fn get_storage(
            self: @ContractState,
            block: u256,
            account: felt252,
            slot: Words64,
            mpt_proof: Span<Words64>
        ) -> u256 {
            let storage_hash = self.storage_hash.read((account, block));
            assert(storage_hash != Zeroable::zero(), 'Storage hash not proven');

            let mpt = MPTWords64Trait::new(storage_hash);
            // TODO error handling
            let value = mpt.verify(slot, mpt_proof).unwrap();

            InternalFunctions::words64_to_u256(value)
        }

        fn prove_account(
            ref self: ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: Words64,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
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
                mmr_id
            );

            // TODO IMPORTANT! handle values bigger than u64
            let account_felt252: felt252 = (*account.at(0)).into();

            let mut i: usize = 0;
            loop {
                if i == field_values.len() {
                    break ();
                }

                let field = fields.at(i);
                let value = *field_values.at(i);

                match field {
                    AccountField::StorageHash(_) => {
                        self.storage_hash.write((account_felt252, block), value);
                    },
                    AccountField::CodeHash(_) => {
                        self.code_hash.write((account_felt252, block), value);
                    },
                    AccountField::Balance(_) => {
                        self.balance.write((account_felt252, block), value);
                    },
                    AccountField::Nonce(_) => {
                        self.nonce.write((account_felt252, block), value);
                    }
                };

                i += 1;
            };
            
            self
                .emit(
                    Event::AccountProven(
                        AccountProven { account: account_felt252, block, fields }
                    )
                );
        }

        fn prove_storage(
            ref self: ContractState,
            block: u256,
            account: felt252,
            slot: Words64,
            mpt_proof: Span<Words64>
        ) {

            let value = EVMFactsRegistry::get_storage(@self, block, account, slot, mpt_proof);
            let slot_u256 = InternalFunctions::words64_to_u256(slot);

            self.slot_values.write((account, block, slot_u256), value);

            self
                .emit(
                    Event::StorageProven(
                        StorageProven { account, block, slot: slot_u256, value: value }
                    )
                );
        }
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

        fn words64_to_u256(words64: Words64) -> u256 {
            // TODO IMPORTANT! handle values bigger than u64
            // TODO move to lib
            (*words64.at(0)).into()
        }

        // returns (block_number, account_fields)
        fn get_account(
            self: @ContractState,
            fields: Span<AccountField>,
            block_header_rlp: Words64,
            account: Words64,
            mpt_proof: Span<Words64>,
            mmr_index: usize,
            mmr_peaks: Peaks,
            mmr_proof: Proof,
            mmr_id: usize,
        ) -> (u256, Span<u256>) {
            let blockhash = InternalFunctions::poseidon_hash_rlp(block_header_rlp);

            let contract_address = self.headers_store.read();
            let mmr_inclusion = IHeadersStoreDispatcher {
                contract_address
            }.verify_mmr_inclusion(mmr_index, blockhash, mmr_peaks, mmr_proof, mmr_id);
            assert(mmr_inclusion, 'MMR inclusion not proven');

            let (decoded_rlp, _) = rlp_decode_word64(block_header_rlp).unwrap();
            let mut state_root: u256 = 0;
            let mut block_number: u256 = 0;
            match decoded_rlp {
                RLPItemWord64::Bytes(_) => panic_with_felt252('Invalid header rlp'),
                RLPItemWord64::List(l) => {
                    // State root is the fourth element in the list
                    // Block number is the ninth element in the list
                    // TODO IMPORTANT! handle values bigger than u64
                    // Write a Words64 to u256 in the lib
                    //state_root = InternalFun*l.at(3);
                    state_root = InternalFunctions::words64_to_u256(*l.at(3));
                    block_number = InternalFunctions::words64_to_u256(*l.at(8));
                },
            };

            let mpt = MPTWords64Trait::new(state_root);
            // TODO error handling
            let rlp_account = mpt.verify(account, mpt_proof).unwrap();

            let (decoded_account, _) = rlp_decode_word64(rlp_account).unwrap();
            let mut account_felt252 = 0;
            let mut account_fields = ArrayTrait::new();
            match decoded_account {
                RLPItemWord64::Bytes(_) => panic_with_felt252('Invalid account rlp'),
                RLPItemWord64::List(l) => {
                    let mut i: usize = 0;
                    // TODO IMPORTANT! handle values bigger than u64
                    let account_felt252: felt252 = (*account.at(0)).into();
                    loop {
                        if i == fields.len() {
                            break ();
                        }

                        let field = fields.at(i);
                        match field {
                            AccountField::StorageHash(_) => {
                                let storage_hash = InternalFunctions::words64_to_u256(*l.at(2));
                                account_fields.append(storage_hash);
                            },
                            AccountField::CodeHash(_) => {
                                let code_hash = InternalFunctions::words64_to_u256(*l.at(3));
                                account_fields.append(code_hash);
                            },
                            AccountField::Balance(_) => {
                                let balance = InternalFunctions::words64_to_u256(*l.at(0));
                                account_fields.append(balance);
                            },
                            AccountField::Nonce(_) => {
                                let nonce = InternalFunctions::words64_to_u256(*l.at(1));
                                account_fields.append(nonce);
                            },
                        };

                        i += 1;
                    };
                },
            };

            (block_number, account_fields.span())
        }
    }
}
