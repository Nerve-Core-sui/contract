module nerve::msui {
    use sui::coin::{Self, TreasuryCap, Coin};

    // One-time witness for MSUI
    public struct MSUI has drop {}

    // Shared treasury for MSUI
    public struct MSUITreasury has key {
        id: UID,
        cap: TreasuryCap<MSUI>,
    }

    #[allow(deprecated_usage)]
    fun init(witness: MSUI, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"MSUI",
            b"Mock SUI",
            b"Mock SUI token for testing on Sui Network",
            option::none(),
            ctx
        );

        let treasury = MSUITreasury {
            id: object::new(ctx),
            cap: treasury_cap,
        };

        transfer::public_freeze_object(metadata);
        transfer::share_object(treasury);
    }

    // Mint MSUI tokens (callable by faucet module)
    public fun mint(treasury: &mut MSUITreasury, amount: u64, ctx: &mut TxContext): Coin<MSUI> {
        coin::mint(&mut treasury.cap, amount, ctx)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MSUI {}, ctx);
    }
}
