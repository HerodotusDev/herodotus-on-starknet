use starknet::ContractAddress;
use option::OptionTrait;

#[starknet::interface]
trait ICommitmentsInbox<TContractState> {
    fn get_headers_store(self: @TContractState) -> ContractAddress;
    fn get_l1_message_sender(self: @TContractState) -> felt252;
    fn get_owner(self: @TContractState) -> ContractAddress;

    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);

    fn receive_commitment_owner(ref self: TContractState, blockhash: u256, block_number: u256);
}

#[starknet::contract]
mod CommitmentsInbox {
    use starknet::{ContractAddress, get_caller_address};
    use zeroable::Zeroable;
    use herodotus_eth_starknet::core::headers_store::{
        IHeadersStoreDispatcherTrait, IHeadersStoreDispatcher
    };

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        l1_message_sender: felt252,
        owner: ContractAddress
    }

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
        last_pos: usize
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        headers_store: ContractAddress,
        l1_message_sender: felt252,
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
    impl CommitmentsInbox of super::ICommitmentsInbox<ContractState> {
        fn get_headers_store(self: @ContractState) -> ContractAddress {
            self.headers_store.read()
        }

        fn get_l1_message_sender(self: @ContractState) -> felt252 {
            self.l1_message_sender.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
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
        assert(from_address == self.l1_message_sender.read(), 'Invalid sender');

        let contract_address = self.headers_store.read();
        IHeadersStoreDispatcher { contract_address }.receive_hash(blockhash, block_number);

        self.emit(Event::CommitmentReceived(CommitmentReceived { blockhash, block_number }));
    }

    #[l1_handler]
    fn receive_mmr(ref self: ContractState, from_address: felt252, root: felt252, last_pos: usize) {
        assert(from_address == self.l1_message_sender.read(), 'Invalid sender');

        let contract_address = self.headers_store.read();
        IHeadersStoreDispatcher { contract_address }.create_branch_from_message(root, last_pos);

        self.emit(Event::MMRReceived(MMRReceived { root, last_pos }));
    }
}
