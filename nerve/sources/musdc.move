module nerve::musdc {
    use sui::coin::{Self, TreasuryCap, Coin};

    // One-time witness for MUSDC
    public struct MUSDC has drop {}

    // Shared treasury for MUSDC
    public struct MUSDCTreasury has key {
        id: UID,
        cap: TreasuryCap<MUSDC>,
    }

    #[allow(deprecated_usage)]
    fun init(witness: MUSDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"MUSDC",
            b"Mock USDC",
            b"Mock USDC stablecoin for testing on Sui Network",
            option::none(),
            ctx
        );

        let treasury = MUSDCTreasury {
            id: object::new(ctx),
            cap: treasury_cap,
        };

        transfer::public_freeze_object(metadata);
        transfer::share_object(treasury);
    }

    // Mint MUSDC tokens (callable by faucet module)
    public fun mint(treasury: &mut MUSDCTreasury, amount: u64, ctx: &mut TxContext): Coin<MUSDC> {
        coin::mint(&mut treasury.cap, amount, ctx)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MUSDC {}, ctx);
    }
}
