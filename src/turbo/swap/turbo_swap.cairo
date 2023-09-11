#[starknet::interface]
trait ITurboSwap<TContractState> {
    fn set_multiple_header_props(
        ref self: TContractState, attestations: Span<TurboSwap::HeaderPropertiesAttestation>
    );
    fn clear_multiple_header_slots(ref self: TContractState, resets: Span<TurboSwap::HeaderReset>);
    fn set_multiple_storage_slots(
        ref self: TContractState, attestations: Span<TurboSwap::StorageSlotAttestation>
    );
    fn clear_multiple_storage_slots(
        ref self: TContractState, attestations: Span<TurboSwap::StorageSlotAttestation>
    );
    fn set_multiple_accounts(
        ref self: TContractState, attestations: Span<TurboSwap::AccountAttestation>
    );
    fn clear_multiple_accounts(
        ref self: TContractState, attestations: Span<TurboSwap::AccountAttestation>
    );
    fn upgrade(ref self: TContractState, impl_hash: starknet::class_hash::ClassHash);
    fn storage_slots(
        ref self: TContractState, chain_id: u256, block_number: u256, account: felt252, slot: u256
    ) -> u256;
    fn accounts(
        ref self: TContractState,
        chain_id: u256,
        block_number: u256,
        account: felt252,
        property: u256
    ) -> u256;
    fn headers(
        ref self: TContractState, chain_id: u256, block_number: u256, property: u256
    ) -> u256;
}


#[starknet::contract]
mod TurboSwap {
    use array::{ArrayTrait, SpanTrait};
    use poseidon::poseidon_hash_span;
    use traits::Into;
    use starknet::{ContractAddress, SyscallResultTrait, get_caller_address, class_hash::ClassHash};
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use herodotus_eth_starknet::turbo::proving_slot_assignment::turbo_auctioning_system::{
        ITurboAuctioningSystemDispatcher, ITurboAuctioningSystemDispatcherTrait
    };
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcher, IHeadersStoreDispatcherTrait
    };
    use herodotus_eth_starknet::core::evm_facts_registry::{
        IEVMFactsRegistryDispatcher, IEVMFactsRegistryDispatcherTrait, AccountField
    };
    use cairo_lib::utils::types::words64::{Words64, Words64Trait};
    use cairo_lib::encoding::rlp_word64::{rlp_decode_word64, RLPItemWord64};

    #[storage]
    struct Storage {
        facts_registries: LegacyMap<u256, ContractAddress>,
        headers_processors: LegacyMap<u256, ContractAddress>,
        auctioning_system: ContractAddress,
        _headers: LegacyMap<(u256, u256, u256), u256>,
        _accounts: LegacyMap<(u256, u256, felt252, u256), u256>,
        _storage_slots: LegacyMap::<(u256, u256, felt252, u256), u256>
    }

    #[derive(Drop, Serde)]
    enum HeaderProperty {
        TIMESTAMP: (),
        STATE_ROOT: (),
        RECEIPTS_ROOT: (),
        TRANSACTIONS_ROOT: (),
        GAS_USED: (),
        BASE_FEE_PER_GAS: (),
        PARENT_HASH: (),
        MIX_HASH: ()
    }

    #[derive(Drop, Serde)]
    enum AccountProperty {
        NONCE: (),
        BALANCE: (),
        STORAGE_HASH: (),
        CODE_HASH: ()
    }

    #[derive(Drop, Serde)]
    enum Property {
        Account: AccountProperty,
        Header: HeaderProperty,
    }


    #[derive(Drop, Serde)]
    struct HeaderPropertiesAttestation {
        chain_id: u256,
        properties: Span<Property>,
        recipient: ContractAddress,
        // proof section
        tree_id: usize,
        block_proof_leaf_index: u32,
        block_proof_leaf_value: felt252,
        mmr_tree_size: u256,
        inclusion_proof: Span<felt252>,
        mmr_peaks: Span<felt252>,
        header_serialized: Words64
    }

    #[derive(Drop, Serde)]
    struct HeaderReset {
        chain_id: u256,
        block_number: u256,
        properties: Span<Property>
    }

    #[derive(Drop, Serde)]
    struct StorageSlotAttestation {
        chainId: u256,
        account: felt252,
        block_number: u256,
        slot: u256
    }


    #[derive(Drop, Serde)]
    struct AccountAttestation {
        chain_id: u256,
        account: felt252,
        block_number: u256,
        property: Property
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }


    #[constructor]
    fn constructor(ref self: ContractState, _auctioning_system: ContractAddress) {
        self.auctioning_system.write(_auctioning_system);
    }

    #[external(v0)]
    impl TurboSwap of super::ITurboSwap<ContractState> {
        fn set_multiple_header_props(
            ref self: ContractState, attestations: Span<HeaderPropertiesAttestation>
        ) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only'
            );

            let mut i = 0;
            loop {
                if (i >= attestations.len()) {
                    break;
                };

                let attestation = attestations.at(i);
                let headers_processor = InternalFunctions::_get_headers_processor_for_chain(
                    ref self, *attestation.chain_id
                );
                assert(
                    headers_processor.contract_address != starknet::contract_address_const::<0>(),
                    'TurboSwap: Unknown chain Id'
                );

                let mmr_root = headers_processor.get_mmr_root(*attestation.tree_id);
                assert(mmr_root != 0, 'ERR_EMPTY_MMR_ROOT');

                let block_proof_leaf_index: felt252 = (*attestation.block_proof_leaf_index).into();
                let mut bplf_arr = ArrayTrait::new();
                bplf_arr.append(block_proof_leaf_index);

                assert(
                    poseidon_hash_span(bplf_arr.span()) == *attestation.block_proof_leaf_value,
                    'ERR_INVALID_PROOF_LEAF'
                );

                let mmr = headers_processor.get_mmr(*attestation.tree_id);

                match mmr
                    .verify_proof(
                        *attestation.block_proof_leaf_index,
                        *attestation.block_proof_leaf_value,
                        *attestation.mmr_peaks,
                        *attestation.inclusion_proof
                    ) {
                    Result::Ok(_) => {
                        match rlp_decode_word64(*attestation.header_serialized) {
                            Result::Ok((
                                decoded_data, len
                            )) => {
                                match decoded_data {
                                    RLPItemWord64::Bytes => {
                                        panic_with_felt252('Unexpected rlp match');
                                    },
                                    RLPItemWord64::List(rlp_data_list) => {
                                        assert(
                                            rlp_data_list.at(8).len() == 1,
                                            'Block number does not fit' // TODO improve msg
                                        );
                                        let block_number: u256 = rlp_data_list
                                            .at(8)
                                            .at(0); // TODO this is only assumption, modify!

                                        let mut j = 0;
                                        loop {
                                            if (i >= (*attestation.properties).len()) {
                                                break;
                                            }
                                            let property = (*attestation.properties).at(j);
                                            match InternalFunctions::_property_to_uint(property) {
                                                Result::Ok(property_uint) => {
                                                    // TODO: implement: let value = self.header_serialized. get_header_property?(property)
                                                    self
                                                        ._headers
                                                        .write(
                                                            (
                                                                *attestation.chain_id,
                                                                block_number,
                                                                property_uint
                                                            ),
                                                            0
                                                        );
                                                },
                                                Result::Err(_) => {
                                                    assert(false, 'ERR_ENUM_UINT_CONV');
                                                }
                                            };
                                        }
                                    }
                                }
                            },
                            Result::Err(e) => {
                                assert(false, e);
                            }
                        }
                    },
                    Result::Err(_) => {
                        assert(false, 'ERR_MMR_PROOF_FAILED');
                    }
                };
            }
        }

        fn clear_multiple_header_slots(ref self: ContractState, resets: Span<HeaderReset>) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only.'
            );

            let mut i: usize = 0;
            loop {
                if i >= resets.len() {
                    break;
                }

                let reset = resets.at(i);
                let mut j = 0;
                loop {
                    if j >= (*reset.properties).len() {
                        break;
                    }

                    match InternalFunctions::_property_to_uint((*reset.properties).at(j)) {
                        Result::Ok(property_uint) => {
                            self
                                ._headers
                                .write((*reset.chain_id, *reset.block_number, property_uint), 0);
                        },
                        Result::Err(_) => {
                            assert(false, 'ERR_ENUM_UINT_CONV');
                        }
                    };
                // TODO pay out fees
                };
            }
        }

        fn set_multiple_storage_slots(
            ref self: ContractState, attestations: Span<StorageSlotAttestation>
        ) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only.'
            );

            let mut i = 0;
            loop {
                if i >= attestations.len() {
                    break;
                }

                let attestation = attestations.at(i);

                let facts_registry = InternalFunctions::_get_facts_registry_for_chain(ref self, attestation.chainId);
                assert(
                    facts_registry.contract_address != starknet::contract_address_const::<0>(),
                    'TurboSwap: Unknown chain id'
                );
                match facts_registry
                    .get_slot_value(
                        *attestation.account, *attestation.block_number, *attestation.slot
                    ) {
                    Result::Ok(account_address) => {
                        let value = account_address;

                        self
                            ._storage_slots
                            .write(
                                (
                                    *attestation.chainId,
                                    *attestation.block_number,
                                    *attestation.account,
                                    *attestation.slot
                                ),
                                value
                            );
                    },
                    Result::Err(_) => {
                        assert(false, 'ERR_REGISTRY_DATA_READ')
                    }
                };
            }
        }

        fn clear_multiple_storage_slots(
            ref self: ContractState, attestations: Span<StorageSlotAttestation>
        ) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only.'
            );

            let mut i: usize = 0;
            loop {
                if i >= attestations.len() {
                    break;
                }
                let attestation = attestations.at(i);
                self
                    ._storage_slots
                    .write(
                        (
                            *attestation.chainId,
                            *attestation.block_number,
                            *attestation.account,
                            *attestation.slot
                        ),
                        0
                    );
            // TODO pay out fees
            }
        }

        fn set_multiple_accounts(ref self: ContractState, attestations: Span<AccountAttestation>) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only.'
            );

            let mut i = 0;
            loop {
                if (i >= attestations.len()) {
                    break;
                }
                let attestation = attestations.at(i);

                let facts_registry = InternalFunctions::_get_facts_registry_for_chain(
                    ref self, *attestation.chain_id
                );

                assert(
                    facts_registry.contract_address != starknet::contract_address_const::<0>(),
                    'TurboSwap: Unknown chain id'
                );

                let value = 0;
                match InternalFunctions::_property_to_uint(attestation.property) {
                    Result::Ok(property_uint) => {
                        let mut value = 0;
                        if (property_uint == 0) {
                            match facts_registry
                                .get_account_field(
                                    *attestation.account,
                                    *attestation.block_number,
                                    AccountField::Nonce
                                ) {
                                Result::Ok(account_value) => {
                                    value = account;
                                },
                                Result::Err(_) => {
                                    assert(false, 'ERR_REGISTRY_DATA_READ')
                                }
                                };
                        } else if (property_uint == 1) {
                            match facts_registry
                                .get_account_field(
                                    *attestation.account,
                                    *attestation.block_number,
                                    AccountField::Balance
                                ) {
                                    Result::Ok(account_value) => {
                                        value = account;
                                    },
                                    Result::Err(_) => {
                                        assert(false, 'ERR_REGISTRY_DATA_READ')
                                    }
                                };
                        } else if (property_uint == 2) {
                            match facts_registry
                                .get_account_field(
                                    *attestation.account,
                                    *attestation.block_number,
                                    AccountField::StorageHash
                                ) => {
                                    Result::Ok(account_value) => {
                                        value = account;
                                    },
                                    Result::Err(_) => {
                                        assert(false, 'ERR_REGISTRY_DATA_READ')
                                    }
                                };
                        } else if (property_uint == 3) {
                            match facts_registry
                                .get_account_field(
                                    *attestation.account,
                                    *attestation.block_number,
                                    AccountField::CodeHash
                                ) => {
                                    Result::Ok(account_value) => {
                                        value = account;
                                    },
                                    Result::Err(_) => {
                                        assert(false, 'ERR_REGISTRY_DATA_READ')
                                    }
                                };
                        } else {
                            assert(false, 'TurboSwap: Unknown property')
                        }

                        self
                            ._accounts
                            .write(
                                (
                                    *attestation.chain_id,
                                    *attestation.block_number,
                                    *attestation.account,
                                    property_uint
                                ),
                                value
                            );
                    },
                    Result::Err(_) => {
                        assert(false, 'ERR_ENUM_UINT_CONV');
                    }
                };
            }
        }

        fn clear_multiple_accounts(
            ref self: ContractState, attestations: Span<AccountAttestation>
        ) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(ref self),
                'TurboSwap: Winner-only.'
            );

            let mut i: usize = 0;
            loop {
                if i >= attestations.len() {
                    break;
                }
                let attestation = attestations.at(i);
                match InternalFunctions::_property_to_uint(attestation.property) {
                    Result::Ok(property_uint) => {
                        self
                            ._storage_slots
                            .write(
                                (
                                    *attestation.chain_id,
                                    *attestation.block_number,
                                    *attestation.account,
                                    property_uint
                                ),
                                0
                            );
                    // TODO pay out fees
                    },
                    Result::Err(_) => {
                        assert(false, 'ERR_ENUM_UINT_CONV');
                    }
                };
            }
        }


        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap_syscall();
            self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }))
        }

        fn storage_slots(
            ref self: ContractState,
            chain_id: u256,
            block_number: u256,
            account: felt252,
            slot: u256
        ) -> u256 {
            let value = self._storage_slots.read((chain_id, block_number, account, slot));
            assert(value != 0, 'TurboSwap: Storage slot not set');
            value
        }

        fn accounts(
            ref self: ContractState,
            chain_id: u256,
            block_number: u256,
            account: felt252,
            property: u256
        ) -> u256 {
            let value = self._accounts.read((chain_id, block_number, account, property));
            assert(value != 0, 'TurboSwap: Account property not set');
            value
        }

        fn headers(
            ref self: ContractState, chain_id: u256, block_number: u256, property: u256
        ) -> u256 {
            let value = self._headers.read((chain_id, block_number, account, property));
            assert(value != 0, 'TurboSwap: Account property not set');
            value
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_facts_registry_for_chain(
            ref self: ContractState, chain_id: u256
        ) -> IEVMFactsRegistryDispatcher {
            IEVMFactsRegistryDispatcher { contract_address: self.facts_registries.read(chain_id) }
        }
        fn _swap_fullfillment_assignee(ref self: ContractState) -> ContractAddress {
            ITurboAuctioningSystemDispatcher { contract_address: self.auctioning_system.read() }
                .get_current_assignee()
        }
        fn _get_headers_processor_for_chain(
            ref self: ContractState, chain_id: u256
        ) -> IHeadersStoreDispatcher {
            IHeadersStoreDispatcher { contract_address: self.headers_processors.read(chain_id) }
        }

        fn _property_to_uint(enum_value: @Property) -> Result<u256, felt252> {
            match enum_value {
                Property::Account(v) => {
                    match v {
                        AccountProperty::NONCE => Result::Ok(0),
                        AccountProperty::BALANCE => Result::Ok(1),
                        AccountProperty::STORAGE_HASH => Result::Ok(2),
                        AccountProperty::CODE_HASH => Result::Ok(3)
                    }
                },
                Property::Header(v) => {
                    match v {
                        HeaderProperty::TIMESTAMP => Result::Ok(0),
                        HeaderProperty::STATE_ROOT => Result::Ok(1),
                        HeaderProperty::RECEIPTS_ROOT => Result::Ok(2),
                        HeaderProperty::TRANSACTIONS_ROOT => Result::Ok(3),
                        HeaderProperty::GAS_USED => Result::Ok(4),
                        HeaderProperty::BASE_FEE_PER_GAS => Result::Ok(5),
                        HeaderProperty::PARENT_HASH => Result::Ok(6),
                        HeaderProperty::MIX_HASH => Result::Ok(7),
                    }
                },
            }
        }
    }
}
