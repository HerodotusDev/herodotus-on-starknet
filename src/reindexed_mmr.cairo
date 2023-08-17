use starknet::ContractAddress;
use cairo_lib::utils::types::bytes::Bytes;

type Peaks = Span<felt252>;
type Proofs = Span<felt252>;
type Headers = Span<Bytes>;

#[starknet::interface]
trait IReindexedMMR<TContractState> {
    fn reindex_batch(
        ref self: TContractState,
        reference_mmr_branch_id: usize,
        reference_mmr_size: usize,
        header_hash_inclusion_proofs: Proofs,
        headers: Headers,
        reindexed_mmr_id: usize,
        reindexed_mmr_peaks: Peaks
    );
}

#[starknet::contract]
mod ReindexedMMR {
    use starknet::{ContractAddress, get_caller_address};
    use cairo_lib::data_structures::mmr::mmr::{MMR, MMRTrait};
    use cairo_lib::utils::types::bytes::Bytes;

    type Peaks = Span<felt252>;
    type Proofs = Span<felt252>;
    type Headers = Span<Bytes>;

    #[storage]
    struct Storage {
        headers_store: ContractAddress,
        mmrs: LegacyMap::<usize, MMR>
    }

    #[constructor]
    fn constructor(ref self: ContractState, headers_store: ContractAddress) {
        self.headers_store.write(headers_store);
    }

    #[external(v0)]
    impl ReindexedMMR of super::IReindexedMMR<ContractState> {
        fn reindex_batch(
            ref self: ContractState,
            reference_mmr_branch_id: usize,
            reference_mmr_size: usize,
            header_hash_inclusion_proofs: Proofs,
            headers: Headers,
            reindexed_mmr_id: usize,
            reindexed_mmr_peaks: Peaks
        ) {}
    }
}
