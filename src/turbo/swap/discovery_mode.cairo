#[starknet::interface]
trait IDiscoveryMode<TContractState> {
    fn storage_slots(ref self: TContractState, chain_id: u256, block_number: u256, account: felt252, slot: u256) -> u256;
    fn accounts(ref self: TContractState, chain_id: u256, block_number: u256, property: u256) -> u256;
    fn headers(ref self: TContractState, chain_id: u256, block_number: u256, property: u256) -> u256;
    fn read_slots(ref self: TContractState, slotKeys: Array<felt252>);
    fn write_slot(ref self: TContractState, slotKey: felt252, slotValue: felt252);
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
        IdentifiedUnsetHeaderProperty, IdentifiedUnsetHeaderProperty,
        SlotWrite: SlotWrite,
        SlotsRead: SlotsRead
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


    #[derive(Drop, starknet::Event)]
    struct SlotsRead {
        nonExistingSlots: Array<felt252>
    }

    #[derive(Drop, starknet::Event)]
    struct SlotWrite {
        slotKey: felt252,
        slotValue: felt252
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
                self.emit(Event::IdentifiedUnsetStorageSlot(IdentifiedUnsetStorageSlot { chain_id: _chain_id, block_number: _block_number, account: _account, slot: _slot }));
                return -1;
            }
            value
        }

        fn accounts(ref self: ContractState, _chain_id: u256, _block_number: u256, _account: felt252, _property: u256) -> u256 {
            let value = ITurboSwapDispatcher { contract_address: self.swap_addr.read()}.accounts(_chain_id, _block_number, _account, _property);
            if(value == 0) {
                 self.emit(Event::IdentifiedUnsetAccountProperty(IdentifiedUnsetIdentifiedUnsetAccountPropertyStorageSlot { chain_id: _chain_id, block_number: _block_number, account: _account, property: _property }));
                return -1;
            }
            value
        }

        fn headers(ref self: ContractState, _chain_id: u256, _block_number: u256, _property: u256) -> u256 {
            let value =  ITurboSwapDispatcher { contract_address: self.swap_addr.read()}.headers(_chain_id, _block_number, _property);
            if(value == 0) {
                 self.emit(Event::IdentifiedUnsetHeaderProperty(IdentifiedUnsetHeaderProperty { chain_id: _chain_id, block_number: _block_number, property: _property }));
            }
            value
        }

        fn read_slots(ref self: ContractState, slotKeys: Array<felt252>) {
            let domain_address = 0_u32;
            let numberOfSlots = slotKeys.len();
            let mut nonExistingSlots = ArrayTrait::<felt252>::new();

            let mut i: usize = 0;
            loop {
                if i >= numberOfSlots {
                    break;
                }
                let storage_address = storage_address_from_base_and_offset(
                    storage_base_address_from_felt252(*slotKeys[i]), 0_u8
                );
                let value = storage_read_syscall(domain_address, storage_address).unwrap_syscall();
                if value == 0 {
                    nonExistingSlots.append(*slotKeys.at(i))
                };
                i = i + 1;
            };
            self.emit(Event::SlotsRead(SlotsRead { nonExistingSlots }));
        }

        fn write_slot(ref self: ContractState, slotKey: felt252, slotValue: felt252) {
            let domain_address = 0_u32;
            let storage_address = storage_address_from_base_and_offset(
                storage_base_address_from_felt252(slotKey), 0_u8
            );
            storage_write_syscall(domain_address, storage_address, slotValue);
            self.emit(Event::SlotWrite(SlotWrite { slotKey, slotValue }));
        }
    }

}
