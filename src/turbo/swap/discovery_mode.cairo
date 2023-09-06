#[starknet::interface]
trait IDiscoveryMode<TContractState> {
    fn storage_slots(ref self: TContractState, chain_id: u256, block_number: u256, account: felt252, slot: u256) -> u256;
    fn accounts(ref self: TContractState, chain_id: u256, block_number: u256, property: u256) -> u256;
    fn headers(ref self: TContractState, chain_id: u256, block_number: u256, property: u256) -> u256;
}


#[starknet::contract]
mod DiscoveryMode {
    use starknet::{ContractAddress};
    use herodotus_eth_starknet::turbo::swap::turbo_swap::{ITurboSwapDispatcher, ITurboSwapDispatcherTrait}


    #[storage]
    struct Storage {
        swap_addr: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        IdentifiedUnsetStorageSlot: IdentifiedUnsetStorageSlot,
        IdentifiedUnsetAccountProperty: IdentifiedUnsetAccountProperty,
        IdentifiedUnsetHeaderProperty, IdentifiedUnsetHeaderProperty
    }

    #[derive(Drop, starknet::Event)]
    struct IdentifiedUnsetStorageSlot {
        chain_id: u256,
        block_number: u256,
        account: felt252,
        slot: u256
    }

    #[derive(Drop, starknet::Event)]
    struct IdentifiedUnsetAccountProperty {
        chain_id: u256,
        block_number: u256,
        account: felt252,
        property: u256
    }


    #[derive(Drop, starknet::Event)]
    struct IdentifiedUnsetHeaderProperty {
        chain_id: u256,
        block_number: u256,
        property: u256
    }



    #[constructor]
    fn constructor(ref self: ContractState, _swap_addr: ContractAddress) {
        self.swap_addr.write(_swap_addr);
    }

    #[external(v0)]
    impl DiscoveryMode of super::IDiscoveryMode<ContractState> {

        fn storage_slots(ref self: ContractState, _chain_id: u256, _block_number: u256, _account: _felt252, _slot: u256)  -> u256 {
            let value = ITurboSwapDispatcher { contract_address: self.swap_addr.read()}.storage_slots(_chain_id, _block_number, _account, _slot);
            if(value == 0) {
                self.emit(Event::IdentifiedUnsetStorageSlot(IdentifiedUnsetStorageSlot { chain_id: _chain_id, block_number: _block_number, account: _account, slot: _slot }))
            }
            value
        }

        fn accounts(ref self: ContractState, _chain_id: u256, _block_number: u256, _account: felt252, _property: u256) -> u256 {
            let value = ITurboSwapDispatcher { contract_address: self.swap_addr.read()}.accounts(_chain_id, _block_number, _account, _property);
            if(value == 0) {
                 self.emit(Event::IdentifiedUnsetAccountProperty(IdentifiedUnsetIdentifiedUnsetAccountPropertyStorageSlot { chain_id: _chain_id, block_number: _block_number, account: _account, property: _property }))
            }
            value
        }

        fn headers(ref self: ContractState, _chain_id: u256, _block_number: u256, _property: u256) -> u256 {
            let value =  ITurboSwapDispatcher { contract_address: self.swap_addr.read()}.headers(_chain_id, _block_number, _property);
            if(value == 0) {
                 self.emit(Event::IdentifiedUnsetHeaderProperty(IdentifiedUnsetHeaderProperty { chain_id: _chain_id, block_number: _block_number, property: _property }))
            }
            value
        }
    }

}
