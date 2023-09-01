#[starknet::interface]
trait ITurboSwap<TContractState> {
    fn set_multiple_header_props(
        ref self: TContractState, attestations: Span<TurboSwap::HeaderPropertiesAttestation>
    );
    fn clear_multiple_headers_storage_slots(
        ref self: TContractState, resets: Span<TurboSwap::HeaderReset>
    );
    fn set_multiple_storage_slots(ref self: TContractState, attestations: Span<TurboSwap::StorageSlotAttestation>);
    fn clear_multiple_storage_slots(ref self: TContractState,  attestations: Span<TurboSwap::StorageSlotAttestation>);
}


#[starknet::contract]
mod TurboSwap {
    use array::{ArrayTrait, SpanTrait};
    use poseidon::poseidon_hash_span;
    use traits::Into;
    use starknet::{ContractAddress, SyscallResult, get_caller_address};
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use herodotus_eth_starknet::turbo::proving_slot_assignment::turbo_auctioning_system::{
        ITurboAuctioningSystemDispatcher, ITurboAuctioningSystemDispatcherTrait
    };
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcher, IHeadersStoreDispatcherTrait
    };
    use herodotus_eth_starknet::core::evm_facts_registry::{
        IEVMFactsRegistryDispatcher, IEVMFactsRegistryDispatcherTrait
    };
    use cairo_lib::utils::types::words64::{Words64, Words64Trait};
    use cairo_lib::encoding::rlp_word64::{rlp_decode_word64, RLPItemWord64};


    #[storage]
    struct Storage {
        facts_registries: LegacyMap<u256, ContractAddress>,
        headers_processors: LegacyMap<u256, ContractAddress>,
        auctioning_system: ContractAddress,
        _headers: LegacyMap<(u256, u256, u64), usize>,
        _storageSlots: LegacyMap::<(u256, u256, felt252, u256), u256>
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
    struct HeaderPropertiesAttestation {
        chain_id: u256,
        properties: Span<HeaderProperty>,
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
        properties: Span<HeaderProperty>
    }

    #[derive(Drop, Serde)]
    struct StorageSlotAttestation {
        chainId: u256,
        account: felt252,
        block_number: u256,
        slot: u256
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
                                            'Block number does not fit'
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
                                            // TODO: implement => let value = self.header_serialized. get_header_property?(property)
                                            self
                                                ._headers
                                                .write(
                                                    (*attestation.chain_id, block_number, property),
                                                    0
                                                );
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

        fn clear_multiple_headers_storage_slots(
            ref self: ContractState, resets: Span<HeaderReset>
        ) {
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

                    match InternalFunctions::_enum_to_uint((*reset.properties).at(i)) {
                        Result::Ok(property_uint) => {
                            self
                                ._headers
                                .write((*reset.chain_id, *reset.block_number, property_uint), 0);
                        },
                        Result::Err(_) => {
                            assert(false, 'Failed to get enum');
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

                let facts_registry = InternalFunctions::_get_facts_registry_for_chain(
                    ref self, *attestation.chainId
                );
                assert(
                    facts_registry.contract_address != starknet::contract_address_const::<0>(),
                    'TurboSwap: Unknown chain id'
                );

                let value = facts_registry
                    .get_slot_value(
                        *attestation.account, *attestation.block_number, *attestation.slot
                    );
                self
                    ._storageSlots
                    .write(
                        (
                            *attestation.chainId,
                            *attestation.block_number,
                            *attestation.account,
                            *attestation.slot
                        ),
                        value
                    );
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
                    ._storageSlots
                    .write(
                        (
                            *attestation.chainId,
                            *attestation.block_number,
                            *attestation.account,
                            *attestation.slot
                        ),
                        0
                    );
            }
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

        fn _enum_to_uint(enum_value: @HeaderProperty) -> Result<u64, felt252> {
            match enum_value {
                HeaderProperty::TIMESTAMP => Result::Ok(0),
                HeaderProperty::STATE_ROOT => Result::Ok(1),
                HeaderProperty::RECEIPTS_ROOT => Result::Ok(2),
                HeaderProperty::TRANSACTIONS_ROOT => Result::Ok(3),
                HeaderProperty::GAS_USED => Result::Ok(4),
                HeaderProperty::BASE_FEE_PER_GAS => Result::Ok(5),
                HeaderProperty::PARENT_HASH => Result::Ok(6),
                HeaderProperty::MIX_HASH => Result::Ok(7),
            }
        }
    }
}
