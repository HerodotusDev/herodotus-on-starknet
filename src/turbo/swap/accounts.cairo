#[starknet::interface]
trait IAccounts<TContractState> {
    fn set_multiple_accounts(
        ref self: TContractState, attestations: Array<Accounts::AccountAttestation>
    );
    fn clear_multiple_accounts(
        ref self: TContractState, attestations: Array<Accounts::AccountAttestation>
    );
}


#[starknet::contract]
mod Accounts {
    use serde::Serde;
    use array::ArrayTrait;
    use starknet::{ContractAddress, get_caller_address};
    use herodotus_eth_starknet::turbo::swap::turbo_swap::TurboSwap::{HeaderProperty, AccountProperty};
    use herodotus_eth_starknet::core::evm_facts_registry::EVMFactsRegistry;

    #[storage]
    struct Storage {
        _storageSlots: LegacyMap::<(u256, u256, ContractAddress, AccountProperty), u32>
    }

    #[derive(Copy, Drop, Serde)]
    struct AccountAttestation {
        chainId: u256,
        account: ContractAddress,
        block_number: u256,
        property: AccountProperty
    }

        #[external(v0)]
        impl Accounts of super::IAccounts<ContractState> {
            fn set_multiple_accounts(ref self: ContractState, attestations: Array<AccountAttestation>) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(),
                'TurboSwap: Winner-only'
            );

            let mut i: usize = 0;
            loop {
                if i >= attestations.len() {
                    break;
                }

                let attestation: AccountAttestation = *attestations.at(i);

                let factsRegistry: EVMFactsRegistry = InternalFunctions::_get_facts_registry_for_chain(
                    attestation.chainId
                );
                assert(
                    factsRegistry != starknet::contract_address_const::<0>(),
                    'TurboSwap: Unknown chain id'
                ); // address(factsRegistry)

                let mut value: u32 = 0;

                match attestation.property {
                    AccountProperty::NONCE(_) => {},
                    AccountProperty::BALANCE(_) => {},
                    AccountProperty::STORAGE_HASH(_) => {},
                    AccountProperty::CODE_HASH(_) => {},
                    _ => {
                        assert(false, 'TurboSwap: Unknown property');
                    }
                }

                self
                    ._storageSlots
                    .write(
                        (
                            attestation.chainId,
                            attestation.block_number,
                            attestation.account,
                            attestation.property
                        ),
                        value
                    );

                i = i + 1;
            };
        }

        fn clear_multiple_accounts(
            ref self: ContractState, attestations: Array<AccountAttestation>
        ) {
            assert(
                get_caller_address() == InternalFunctions::_swap_fullfillment_assignee(),
                'TurboSwap: Winner-only'
            );
            let mut i: usize = 0;
            loop {
                if i >= attestations.len() {
                    break;
                }

                let attestation: AccountAttestation = *attestations.at(i);
                self
                    ._storageSlots
                    .write(
                        (
                            attestation.chainId,
                            attestation.block_number,
                            attestation.account,
                            attestation.property
                        ),
                        0
                    );
            //  TODO pay out fees
            }
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_facts_registry_for_chain(chainId: u256) -> ContractAddress {
            EVMFactsRegistry(chainId)
        }
        fn _swap_fullfillment_assignee() -> ContractAddress {}
    }
}
