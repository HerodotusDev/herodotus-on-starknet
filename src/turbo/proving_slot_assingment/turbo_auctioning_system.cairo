#[starknet::interface]
trait IERC20<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: starknet::ContractAddress) -> u256;
    fn allowance(
        self: @TState, owner: starknet::ContractAddress, spender: starknet::ContractAddress
    ) -> u256;
    fn transfer(ref self: TState, recipient: starknet::ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState,
        sender: starknet::ContractAddress,
        recipient: starknet::ContractAddress,
        amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: starknet::ContractAddress, amount: u256) -> bool;
}


#[starknet::interface]
trait ITurboAuctioningSystem<TContractState> {
    fn current_slot_id(ref self: TContractState) -> u64;
    fn get_current_assignee(ref self: TContractState) -> starknet::ContractAddress;
}


#[starknet::contract]
mod TurboAuctioningSystem {
    use starknet::ContractAddress;
    use starknet::SyscallResult;
    use herodotus_eth_starknet::turbo::proving_slot_assingment::turbo_auctioning_system::{IERC20};

    #[storage]
    struct Storage {
        bidding_state_channel_deposit: LegacyMap::<ContractAddress, u256>,
        withdrawal_request: LegacyMap::<u256, WithdrawalRequest>,
        slot_assignments: LegacyMap::<u256, ContractAddress>,
        deployment_timestamp: u64,
        slot_duration_seconds: u64,
        bidding_token: IERC20,
        withdrawal_delay_seconds: u256,

        slot_assignments_count: u256,
        last_assigned_id: u256
    }


    #[derive(Copy, Drop)]
    struct WithdrawalRequest {
        amount: u256,
        timestamp: u256,
        recipient: ContractAddress,
    }


    #[derive(Copy, Drop)]
    struct SlotAssingmentBid {
        slotId: u256,
        amount: u256,
        assignee: ContractAddress,
        signature: usize
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SlotAssigned: SlotAssigned, 
    }

    #[derive(Drop, starknet::Event)]
    struct SlotAssigned {
        slotId: u256,
        assignee: ContractAddress,
        winningBidAmount: u256
    }

    const AUCTION_OPERATOR_ROLE: usize = 'AUCTION_OPERATOR_ROLE';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _slot_duration_seconds: u64,
        _bidding_token: IERC20,
        _withdrawal_delay_seconds: u256
    ) {
        self.deployment_timestamp.write(starknet::get_block_timestamp());
        self.slot_duration_seconds.write(_slot_duration_seconds);
        self.bidding_token.write(_bidding_token);
        self.withdrawal_delay_seconds.write(_withdrawal_delay_seconds);
        _setupRole(AUCTION_OPERATOR_ROLE, starknet::get_caller_address());
    }

    #[external(v0)]
    impl TurboAuctioningSystem of super::ITurboAuctioningSystem<ContractState> {
        fn current_slot_id(ref self: ContractState) -> u64 {
            starknet::get_block_timestamp()
                - self.deployment_timestamp.read() / self.slot_duration_seconds.read()
        }

        fn get_current_assignee(ref self: ContractState) -> ContractAddress {
            let assignee: ContractAddress = self.slot_assignments.read(current_slot_id());
            if(assignee != starknet::contract_address_const::<0>()) {
                assignee
            }
            self.slot_assignments.read(self.last_assigned_id.read())
        }

        fn get_missed_slots_count(ref self: ContractState) -> u256 {
            current_slot_id() - self.slot_assignments_count.read();
        }
    }
}
