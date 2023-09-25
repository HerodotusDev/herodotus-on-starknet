#[starknet::interface]
trait ITurboAuctioningSystem<TContractState> {
    fn current_slot_id(ref self: TContractState) -> u256;
    fn get_current_assignee(ref self: TContractState) -> starknet::ContractAddress;
    fn get_missed_slots_count(ref self: TContractState) -> u256;
    fn deposit_to_state_channel(ref self: TContractState, amount: u256);
    fn initiate_withdrawal(
        ref self: TContractState, amount: u256, recipient: starknet::ContractAddress
    );
    fn withdraw(ref self: TContractState, withdrawal_request_id: u256);
    fn settle_bids(
        ref self: TContractState,
        bidder_address: starknet::ContractAddress,
        bids: Array<TurboAuctioningSystem::SlotAssignmentBid>
    );
}

#[starknet::interface]
trait IAccount<TContractState> {
    fn get_public_key(self: @TContractState) -> felt252;
}


#[starknet::contract]
mod TurboAuctioningSystem {
    use core::option::OptionTrait;
    use core::starknet::SyscallResultTrait;
    use traits::{Into, TryInto};
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use keccak::{keccak_u256s_le_inputs};
    use herodotus_eth_starknet::turbo::proving_slot_assignment::turbo_auctioning_system::ITurboAuctioningSystem;
    use ecdsa::{recover_public_key};


    use starknet::{
        ContractAddress, SyscallResult, ClassHash, get_caller_address, get_contract_address
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::accesscontrol::AccessControl;
    use openzeppelin::access::accesscontrol::AccessControl::AccessControlImpl;
    use openzeppelin::account::interface::{
        AccountABI, AccountABIDispatcher, AccountABIDispatcherTrait
    };


    #[storage]
    struct Storage {
        bidding_state_channel_deposit: LegacyMap::<ContractAddress, u256>,
        withdrawal_requests: LegacyMap::<u256, WithdrawalRequest>,
        slot_assignments: LegacyMap::<u256, ContractAddress>,
        deployment_timestamp: u256,
        slot_duration_seconds: u256,
        bidding_token: ContractAddress,
        withdrawal_delay_seconds: u256,
        slot_assignments_count: u256,
        last_assigned_id: u256
    }


    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct WithdrawalRequest {
        amount: u256,
        timestamp: u256,
        recipient: ContractAddress,
    }


    #[derive(Copy, Drop, Serde)]
    struct SlotAssignmentBid {
        slotId: u256,
        amount: u256,
        assignee: ContractAddress,
        signature: Signature
    }

    #[derive(Copy, Drop, Serde)]
    struct Signature {
        r: felt252,
        s: felt252,
        y_parity: bool
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

    // Q: what about doing only-admin? there are no other roles?
    const AUCTION_OPERATOR_ROLE: felt252 = 'OP_ROLE';


    // I: no safe-erc20 for now: https://github.com/OpenZeppelin/cairo-contracts/releases/tag/v0.7.0-rc.0
    #[constructor]
    fn constructor(
        ref self: ContractState,
        _slot_duration_seconds: u256,
        _bidding_token: ContractAddress,
        _withdrawal_delay_seconds: u256
    ) {
        let timestamp: u256 = starknet::get_block_timestamp().into();
        self.deployment_timestamp.write(timestamp);

        self.slot_duration_seconds.write(_slot_duration_seconds);
        self.bidding_token.write(_bidding_token);
        self.withdrawal_delay_seconds.write(_withdrawal_delay_seconds);

        // Q: declaring unsafe_state or just passing the function param (self) state?
        let mut unsafe_state = AccessControl::unsafe_new_contract_state();
        AccessControl::InternalImpl::initializer(ref unsafe_state);
        AccessControl::InternalImpl::_grant_role(
            ref unsafe_state, AUCTION_OPERATOR_ROLE, get_caller_address()
        );
    }

    #[external(v0)]
    impl TurboAuctioningSystem of super::ITurboAuctioningSystem<ContractState> {
        fn current_slot_id(ref self: ContractState) -> u256 {
            // Q: is this safe or maybe declaring mutable unsafe state?
            InternalFunctions::_current_slot_id(ref self)
        }

        fn get_current_assignee(ref self: ContractState) -> ContractAddress {
            let current_slot_id = InternalFunctions::_current_slot_id(ref self);
            let assignee = self.slot_assignments.read(current_slot_id);

            if (assignee != starknet::contract_address_const::<0>()) {
                return assignee;
            }
            self.slot_assignments.read(self.last_assigned_id.read())
        }

        fn get_missed_slots_count(ref self: ContractState) -> u256 {
            let current_slot_id = InternalFunctions::_current_slot_id(ref self);
            let slot_assignments_count = self.slot_assignments_count.read();

            current_slot_id - slot_assignments_count
        }

        fn deposit_to_state_channel(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let erc20 = IERC20Dispatcher { contract_address: self.bidding_token.read() };
            erc20.transfer_from(caller, get_contract_address(), amount);

            let current_amount = self.bidding_state_channel_deposit.read(caller);
            self.bidding_state_channel_deposit.write(caller, current_amount + amount);
        }

        fn initiate_withdrawal(ref self: ContractState, amount: u256, recipient: ContractAddress) {
            let caller = get_caller_address();
            let current_value = self.bidding_state_channel_deposit.read(caller);
            assert(current_value >= amount, 'Not enough funds');

            let updatedValue = current_value - amount;
            self.bidding_state_channel_deposit.write(caller, updatedValue);
        }

        fn withdraw(ref self: ContractState, withdrawal_request_id: u256) {
            let request = self.withdrawal_requests.read(withdrawal_request_id);

            let current_timestamp: u256 = starknet::get_block_timestamp().into();
            assert(
                request.timestamp + self.withdrawal_delay_seconds.read() <= current_timestamp,
                'Withdrawal delay not passed'
            );
            assert(request.recipient == get_caller_address(), 'Only recipient can withdraw');

            let erc20 = IERC20Dispatcher { contract_address: self.bidding_token.read() };
            erc20.transfer(get_contract_address(), request.amount);

            self
                .withdrawal_requests
                .write(
                    withdrawal_request_id,
                    WithdrawalRequest {
                        amount: 0, timestamp: 0, recipient: starknet::contract_address_const::<0>()
                    }
                );
        }

        fn settle_bids(
            ref self: ContractState, bidder_address: ContractAddress, bids: Array<SlotAssignmentBid>
        ) {
            let unsafe_state = AccessControl::unsafe_new_contract_state();
            assert(
                AccessControlImpl::has_role(
                    @unsafe_state, AUCTION_OPERATOR_ROLE, get_caller_address()
                ),
                "Only auction operator can settle bids"
            );
            let bids_length = bids.len();

            assert(bids_length > 0, 'ERR_NO_BIDS_PROVIDED');

            let auctioned_slot_id = bids.at(0).slotId;
            let winning_bid_amount = bids.at(0).amount;

            let temp_bids = bids.clone();
            let mut i = 0;
            loop {
                if (i >= temp_bids.len()) {
                    break;
                }
                let bid = temp_bids.at(i);
                assert(*bid.slotId == *auctioned_slot_id, 'ERR_BID_FOR_DIFFERENT_SLOTS');
                assert(*bid.amount <= *winning_bid_amount, 'ERR_BIDS_NOT_ORDERED_DESC');
            };

            let mut serialized_msg = ArrayTrait::new();
            (*auctioned_slot_id, *winning_bid_amount, *bids.at(0).assignee)
                .serialize(ref serialized_msg);

            let mut formatted_serialized_msg = ArrayTrait::<u256>::new();
            let mut i = 0;
            loop {
                if (i >= serialized_msg.len()) {
                    break;
                };
                let output_formatted: u256 = (*serialized_msg.at(i)).into();
                formatted_serialized_msg.append(output_formatted);
            };

            // Q: big/little endian matters? what about sn_keccak? or ethereum compatibility?
            // Q: uint256 => felt252
            let hashed: felt252 = keccak_u256s_le_inputs(formatted_serialized_msg.span())
                .try_into()
                .unwrap();

            let signature = *bids.at(0).signature;
            let recovered_bidder_public_key = recover_public_key(
                hashed, signature.r, signature.s, signature.y_parity
            );
            match recovered_bidder_public_key {
                Option::Some(rbpk) => {
                    let account_contract = AccountABIDispatcher {
                        contract_address: bidder_address
                    };

                    let account_public_key = account_contract.get_public_key();
                    assert(account_public_key == rbpk, 'Wrong account address');

                    assert(
                        self
                            .bidding_state_channel_deposit
                            .read(bidder_address) >= *winning_bid_amount,
                        'ERR_NOT_ENOUGH_FUNDS'
                    );

                    let erc20 = IERC20Dispatcher { contract_address: self.bidding_token.read() };
                    erc20
                        .transfer_from(
                            get_caller_address(), get_contract_address(), *winning_bid_amount
                        );

                    self.slot_assignments.write(*auctioned_slot_id, *bids.at(0).assignee);

                    let current_slot_assignment_count = self.slot_assignments_count.read();
                    self.slot_assignments_count.write(current_slot_assignment_count + 1);

                    self.last_assigned_id.write(*auctioned_slot_id);
                },
                Option::None(_) => {
                    assert(false, 'Pub key recovery failed');
                }
            }
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _current_slot_id(ref self: ContractState) -> u256 {
            let timestamp: u256 = starknet::get_block_timestamp().into();
            timestamp - self.deployment_timestamp.read() / self.slot_duration_seconds.read()
        }
    }
}
