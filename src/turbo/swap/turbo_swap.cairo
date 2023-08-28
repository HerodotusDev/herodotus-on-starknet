#[starknet::interface]
trait ITurboSwap<TContractState> {
    fn storage_slots(
        ref self: TContractState,
        chainId: u256,
        block_number: u256,
        account: starknet::ContractAddress,
        slot: u32
    ) -> u32;
    fn accounts(
        ref self: TContractState,
        chainId: u256,
        block_number: u256,
        account: starknet::ContractAddress
    ) -> u32;
    fn headers(
        ref self: TContractState,
        chainId: u256,
        block_number: u256,
        property: TurboSwap::HeaderProperty
    ) -> u32;
}


#[starknet::contract]
mod TurboSwap {
    use starknet::ContractAddress;
    use starknet::SyscallResult;

    #[storage]
    struct Storage {
        factsRegistries: LegacyMap::<u256, FactsRegistry>,
        auctioning_system: ContractAddress
    }

    #[derive(Drop)]
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

    #[constructor]
    fn constructor(ref self: ContractState, _auctioning_system: ContractAddress) {
        self.auctioning_system.write(_auctioning_system);
    }

    #[external(v0)]
    impl TurboSwap of super::ITurboSwap<ContractState> {
        fn storage_slots(
            ref self: ContractState,
            chainId: u256,
            block_number: u256,
            account: ContractAddress,
            slot: u32
        ) -> u32 {
            let value = self
                ._storageSlots
                .read(chainId, block_number, account, slot); // read from another inherited contract
            assert(value != 0, 'TurboSwap: Property not set');
            value
        }

        fn accounts(
            ref self: ContractState, chainId: u256, block_number: u256, account: ContractAddress
        ) -> u32 {
            let value = self
                ._accounts
                .read(chainId, block_number, account); // read from another inherited contract
            assert(value != 0, 'TurboSwap: Property not set');
            value
        }


        fn headers(
            ref self: ContractState, chainId: u256, block_number: u256, property: HeaderProperty
        ) -> u32 {
            let value = self
                ._headers
                .read(chainId, block_number, account); // read from another inherited contract
            assert(value != 0, 'TurboSwap: Property not set');
            value
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_facts_registry_for_chain(chainId: u256) -> FactsRegistry {}
        fn _swap_fullfillment_assignee() -> ContractAddress {}
        fn _get_headers_processor_for_chain(chainId: u256) -> HeadersProcessor {}
    }
}
