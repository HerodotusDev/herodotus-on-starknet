// SPDX-License-Identifier: GPL-3.0

use starknet::{ContractAddress, EthAddress};

//
// Interface
//

#[starknet::interface]
trait IOptimismCommitmentsInbox<TContractState> {
    // Getters
    fn get_headers_store(self: @TContractState) -> ContractAddress;
    fn get_l1_message_sender(self: @TContractState) -> EthAddress;
    fn get_owner(self: @TContractState) -> ContractAddress;

    // Setters
    fn set_headers_store(ref self: TContractState, headers_store: ContractAddress);
    fn set_l1_message_sender(ref self: TContractState, l1_message_sender: EthAddress);

    // Ownership
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);

    // Receives a hash commitment from the contract owner
    fn receive_commitment_owner(ref self: TContractState, blockhash: u256, block_number: u256);
}

//
// Contract
//

#[starknet::contract]
mod OptimismCommitmentsInbox {
    use starknet::{ContractAddress, get_caller_address, EthAddress};
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    //
    // Storage
    //

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        l1_message_sender: EthAddress,
        owner: ContractAddress
    }

    //
    // Events
    //

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
        OwnershipRenounced: OwnershipRenounced,
        CommitmentReceived: CommitmentReceived,
        MMRReceived: MMRReceived
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipRenounced {
        previous_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentReceived {
        blockhash: u256,
        block_number: u256
    }

    #[derive(Drop, starknet::Event)]
    struct MMRReceived {
        root: felt252,
        last_pos: usize,
        aggregator_id: usize
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        headers_store: ContractAddress,
        l1_message_sender: EthAddress,
        owner: Option<ContractAddress>
    ) {
        self.headers_store.write(headers_store);
        self.l1_message_sender.write(l1_message_sender);

        match owner {
            Option::Some(o) => self.owner.write(o),
            Option::None(_) => self.owner.write(get_caller_address())
        };
    }

    #[external(v0)]
    impl OptimismCommitmentsInbox of super::IOptimismCommitmentsInbox<ContractState> {
        fn get_headers_store(self: @ContractState) -> ContractAddress {
            self.headers_store.read()
        }

        fn get_l1_message_sender(self: @ContractState) -> EthAddress {
            self.l1_message_sender.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn set_headers_store(ref self: ContractState, headers_store: ContractAddress) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');
            self.headers_store.write(headers_store);
        }

        fn set_l1_message_sender(ref self: ContractState, l1_message_sender: EthAddress) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');
            self.l1_message_sender.write(l1_message_sender);
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');
            self.owner.write(new_owner);

            self
                .emit(
                    Event::OwnershipTransferred(
                        OwnershipTransferred { previous_owner: caller, new_owner }
                    )
                );
        }

        fn renounce_ownership(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');
            self.owner.write(Zeroable::zero());

            self.emit(Event::OwnershipRenounced(OwnershipRenounced { previous_owner: caller }));
        }

        fn receive_commitment_owner(ref self: ContractState, blockhash: u256, block_number: u256) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner');

            let contract_address = self.headers_store.read();
            IHeadersStoreDispatcher { contract_address }.receive_hash(blockhash, block_number);

            self.emit(Event::CommitmentReceived(CommitmentReceived { blockhash, block_number }));
        }
    }

    #[l1_handler]
    fn receive_commitment(
        ref self: ContractState, from_address: felt252, blockhash: u256, block_number: u256
    ) {
        assert(from_address == self.l1_message_sender.read().into(), 'Invalid sender');

        let contract_address = self.headers_store.read();
        IHeadersStoreDispatcher { contract_address }.receive_hash(blockhash, block_number);

        self.emit(Event::CommitmentReceived(CommitmentReceived { blockhash, block_number }));
    }

    #[l1_handler]
    fn receive_mmr(
        ref self: ContractState,
        from_address: felt252,
        root: felt252,
        last_pos: usize,
        aggregator_id: usize
    ) {
        assert(from_address == self.l1_message_sender.read().into(), 'Invalid sender');

        let contract_address = self.headers_store.read();
        IHeadersStoreDispatcher { contract_address }
            .create_branch_from_message(root, last_pos, aggregator_id);

        self.emit(Event::MMRReceived(MMRReceived { root, last_pos, aggregator_id }));
    }
}