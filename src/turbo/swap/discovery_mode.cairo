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
    use herodotus_eth_starknet::turbo::swap::turbo_swap::{ITurboSwapDispatcher, ITurboSwapDispatcherTrait};


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
    struct NonExistingSlotsRead {
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
            self.emit(Event::NonExistingSlotsRead(NonExistingSlotsRead { nonExistingSlots }));
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

#[cfg(test)]
mod test_DiscoveryMode {
    use super::{
        TurboSwapDiscoveryMode, ITurboSwapDiscoveryModeDispatcher,
        ITurboSwapDiscoveryModeDispatcherTrait
    };

    use starknet::class_hash::{Felt252TryIntoClassHash, class_hash_const};
    use starknet::{
        deploy_syscall, ContractAddress, get_caller_address, get_contract_address,
        contract_address_const
    };
    use starknet::testing::{set_caller_address, set_contract_address};

    use option::OptionTrait;
    use array::ArrayTrait;
    use traits::TryInto;
    use result::ResultTrait;
    use core::array::SpanTrait;


    fn deploy_contract() -> (IDiscoveryModeDispatcher, ContractAddress) {
        let mut calldata = ArrayTrait::new();
        let (address, _) = deploy_syscall(
            DiscoveryMode::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let contract = IDiscoveryModeDispatcher { contract_address: address };
        (contract, address)
    }

    fn assert_eq<T, impl TPartialEq: PartialEq<T>>(a: @T, b: @T, err_code: felt252) {
        assert(a == b, err_code);
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_write_slot() {
        let (dispatcher, addr) = deploy_contract();

        let slotKey = 1234;
        let slotValue = 2345;
        dispatcher.write_slot(slotKey, slotValue);

        let (mut keys, mut data) = starknet::testing::pop_log_raw(addr).unwrap();
        assert_eq(@keys.len(), @1, 'unexpected event keys size');
        assert_eq(@data.len(), @2, 'unexpected event data size');
        assert_eq(data.at(0), @slotKey, 'unexpected slot key');
        assert_eq(data.at(1), @slotValue, 'unexpected slot key');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_read_slots() {
        let (dispatcher, addr) = deploy_contract();

        let mut slotsToRead = ArrayTrait::<felt252>::new();
        let slotKey1 = 13;
        let slotKey2 = 37;
        let slotKey3 = 23;

        slotsToRead.append(slotKey1);
        slotsToRead.append(slotKey2);
        slotsToRead.append(slotKey3);

        dispatcher.read_slots(slotsToRead);
        let (mut keys, mut data) = starknet::testing::pop_log_raw(addr).unwrap();
        assert_eq(@keys.len(), @1, 'unexpected event keys size');
        assert_eq(@data.len(), @4, 'unexpected event data size');
        assert_eq(data.at(0), @3, 'unexpected num of elements');
        assert_eq(data.at(1), @slotKey1, 'unexpected slot key');
        assert_eq(data.at(2), @slotKey2, 'unexpected slot key');
        assert_eq(data.at(3), @slotKey3, 'unexpected slot key');
    }


    #[test]
    #[available_gas(2000000000)]
    fn test_write_and_read_slots() {
        let (dispatcher, addr) = deploy_contract();

        let slotKey1 = 13;
        let slotKey2 = 37;
        let slotKey3 = 23;

        dispatcher.write_slot(slotKey2, 45);

        let (mut keys, mut data) = starknet::testing::pop_log_raw(addr).unwrap();
        assert_eq(@keys.len(), @1, 'unexpected event keys size');
        assert_eq(@data.len(), @2, 'unexpected event data size');

        let mut slotsToRead = ArrayTrait::<felt252>::new();
        slotsToRead.append(slotKey1);
        slotsToRead.append(slotKey2);
        slotsToRead.append(slotKey3);

        dispatcher.read_slots(slotsToRead);

        let (mut readEventKeys, mut readEventData) = starknet::testing::pop_log_raw(addr).unwrap();
        assert_eq(@readEventKeys.len(), @1, 'unexpected event keys size');
        assert_eq(@readEventData.len(), @3, 'unexpected event data size');
        assert_eq(readEventData.at(0), @2, 'unexpected num of elements');
        assert_eq(readEventData.at(1), @slotKey1, 'unexpected slot key');
        assert_eq(readEventData.at(2), @slotKey3, 'unexpected slot key');
    }

}
