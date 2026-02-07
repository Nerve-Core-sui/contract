module nerve::swap {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    use nerve::msui::MSUI;
    use nerve::musdc::MUSDC;

    // ========== Structs ==========

    // Shared swap pool
    public struct SwapPool has key {
        id: UID,
        msui_reserve: Balance<MSUI>,
        musdc_reserve: Balance<MUSDC>,
        fee_bps: u64, // basis points (30 = 0.3%)
        lp_supply: u64,
    }

    // LP token receipt
    public struct LPReceipt has key, store {
        id: UID,
        provider: address,
        lp_amount: u64,
    }

    // ========== Events ==========

    public struct PoolCreated has copy, drop {
        pool_id: address,
        msui_initial: u64,
        musdc_initial: u64,
        lp_supply: u64,
    }

    public struct SwapExecuted has copy, drop {
        user: address,
        token_in: vector<u8>,
        token_out: vector<u8>,
        amount_in: u64,
        amount_out: u64,
        fee_charged: u64,
    }

    public struct LiquidityAdded has copy, drop {
        provider: address,
        msui_amount: u64,
        musdc_amount: u64,
        lp_minted: u64,
    }

    public struct LiquidityRemoved has copy, drop {
        provider: address,
        msui_returned: u64,
        musdc_returned: u64,
        lp_burned: u64,
    }

    // ========== Constants ==========

    const FEE_BPS: u64 = 30; // 0.3% = 30 basis points
    const BPS_DENOMINATOR: u64 = 10000;
    const FEE_MULTIPLIER: u64 = 997; // (1 - 0.003) * 1000 = 997
    const FEE_DIVISOR: u64 = 1000;
    const MINIMUM_LIQUIDITY: u64 = 1000; // Locked forever to prevent division by zero

    // ========== Errors ==========

    const E_INSUFFICIENT_OUTPUT: u64 = 1;
    const E_ZERO_AMOUNT: u64 = 2;
    const E_POOL_EMPTY: u64 = 3;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 4;
    const E_INSUFFICIENT_MSUI: u64 = 5;
    const E_INSUFFICIENT_MUSDC: u64 = 6;
    // ========== Admin Functions ==========

    /// Initialize the swap pool with initial liquidity
    /// This creates the pool as a shared object
    public fun init_pool(
        msui: Coin<MSUI>,
        musdc: Coin<MUSDC>,
        ctx: &mut TxContext
    ) {
        let msui_amount = coin::value(&msui);
        let musdc_amount = coin::value(&musdc);

        assert!(msui_amount > 0, E_ZERO_AMOUNT);
        assert!(musdc_amount > 0, E_ZERO_AMOUNT);

        // Calculate initial LP supply using geometric mean, avoiding overflow
        // Use u256 for intermediate calculation if msui_amount and musdc_amount are large
        let lp_supply = if (msui_amount >= 1_000_000_000_000 || musdc_amount >= 1_000_000_000_000) {
            // For large amounts, scale down the calculation
            let scaled_msui = msui_amount / 1_000_000_000;
            let scaled_musdc = musdc_amount / 1_000_000_000;
            sqrt(scaled_msui * scaled_musdc) * 31622  // ~sqrt(1e9)
        } else {
            sqrt(msui_amount * musdc_amount)
        };
        assert!(lp_supply > MINIMUM_LIQUIDITY, E_INSUFFICIENT_LIQUIDITY);

        // Create the pool
        let pool = SwapPool {
            id: object::new(ctx),
            msui_reserve: coin::into_balance(msui),
            musdc_reserve: coin::into_balance(musdc),
            fee_bps: FEE_BPS,
            lp_supply,
        };

        let pool_id = object::uid_to_address(&pool.id);

        // Emit event
        event::emit(PoolCreated {
            pool_id,
            msui_initial: msui_amount,
            musdc_initial: musdc_amount,
            lp_supply,
        });

        // Create LP receipt for initial provider
        let receipt = LPReceipt {
            id: object::new(ctx),
            provider: tx_context::sender(ctx),
            lp_amount: lp_supply - MINIMUM_LIQUIDITY, // Lock minimum liquidity
        };

        transfer::transfer(receipt, tx_context::sender(ctx));
        transfer::share_object(pool);
    }

    // ========== Swap Functions ==========

    /// Swap MSUI for MUSDC
    /// Returns MUSDC coin
    public fun swap_msui_to_musdc(
        pool: &mut SwapPool,
        msui_coin: Coin<MSUI>,
        min_out: u64,
        ctx: &mut TxContext
    ): Coin<MUSDC> {
        let amount_in = coin::value(&msui_coin);
        assert!(amount_in > 0, E_ZERO_AMOUNT);

        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        assert!(msui_reserve > 0 && musdc_reserve > 0, E_POOL_EMPTY);

        // Calculate output using constant product formula with fee
        let amount_out = get_amount_out(amount_in, msui_reserve, musdc_reserve);
        assert!(amount_out >= min_out, E_INSUFFICIENT_OUTPUT);

        // Calculate fee
        let fee_charged = (amount_in * FEE_BPS) / BPS_DENOMINATOR;

        // Add input to reserve
        balance::join(&mut pool.msui_reserve, coin::into_balance(msui_coin));

        // Remove output from reserve
        let musdc_balance = balance::split(&mut pool.musdc_reserve, amount_out);
        let musdc_out = coin::from_balance(musdc_balance, ctx);

        // Emit event
        event::emit(SwapExecuted {
            user: tx_context::sender(ctx),
            token_in: b"MSUI",
            token_out: b"MUSDC",
            amount_in,
            amount_out,
            fee_charged,
        });

        musdc_out
    }

    /// Swap MUSDC for MSUI
    /// Returns MSUI coin
    public fun swap_musdc_to_msui(
        pool: &mut SwapPool,
        musdc_coin: Coin<MUSDC>,
        min_out: u64,
        ctx: &mut TxContext
    ): Coin<MSUI> {
        let amount_in = coin::value(&musdc_coin);
        assert!(amount_in > 0, E_ZERO_AMOUNT);

        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        assert!(msui_reserve > 0 && musdc_reserve > 0, E_POOL_EMPTY);

        // Calculate output using constant product formula with fee
        let amount_out = get_amount_out(amount_in, musdc_reserve, msui_reserve);
        assert!(amount_out >= min_out, E_INSUFFICIENT_OUTPUT);

        // Calculate fee
        let fee_charged = (amount_in * FEE_BPS) / BPS_DENOMINATOR;

        // Add input to reserve
        balance::join(&mut pool.musdc_reserve, coin::into_balance(musdc_coin));

        // Remove output from reserve
        let msui_balance = balance::split(&mut pool.msui_reserve, amount_out);
        let msui_out = coin::from_balance(msui_balance, ctx);

        // Emit event
        event::emit(SwapExecuted {
            user: tx_context::sender(ctx),
            token_in: b"MUSDC",
            token_out: b"MSUI",
            amount_in,
            amount_out,
            fee_charged,
        });

        msui_out
    }

    /// Entry function wrapper for swap_msui_to_musdc
    public fun swap_msui_to_musdc_entry(
        pool: &mut SwapPool,
        msui_coin: Coin<MSUI>,
        min_out: u64,
        ctx: &mut TxContext
    ) {
        let musdc_out = swap_msui_to_musdc(pool, msui_coin, min_out, ctx);
        transfer::public_transfer(musdc_out, tx_context::sender(ctx));
    }

    /// Entry function wrapper for swap_musdc_to_msui
    public fun swap_musdc_to_msui_entry(
        pool: &mut SwapPool,
        musdc_coin: Coin<MUSDC>,
        min_out: u64,
        ctx: &mut TxContext
    ) {
        let msui_out = swap_musdc_to_msui(pool, musdc_coin, min_out, ctx);
        transfer::public_transfer(msui_out, tx_context::sender(ctx));
    }

    // ========== Liquidity Functions ==========

    /// Add liquidity to the pool
    /// Returns LP receipt
    public fun add_liquidity(
        pool: &mut SwapPool,
        msui: Coin<MSUI>,
        musdc: Coin<MUSDC>,
        ctx: &mut TxContext
    ): LPReceipt {
        let msui_amount = coin::value(&msui);
        let musdc_amount = coin::value(&musdc);

        assert!(msui_amount > 0, E_ZERO_AMOUNT);
        assert!(musdc_amount > 0, E_ZERO_AMOUNT);

        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        // Calculate LP tokens to mint
        // lp_minted = min(msui_amount * lp_supply / msui_reserve, musdc_amount * lp_supply / musdc_reserve)
        let lp_from_msui = (msui_amount * pool.lp_supply) / msui_reserve;
        let lp_from_musdc = (musdc_amount * pool.lp_supply) / musdc_reserve;
        let lp_minted = if (lp_from_msui < lp_from_musdc) { lp_from_msui } else { lp_from_musdc };

        assert!(lp_minted > 0, E_INSUFFICIENT_LIQUIDITY);

        // Add liquidity to reserves
        balance::join(&mut pool.msui_reserve, coin::into_balance(msui));
        balance::join(&mut pool.musdc_reserve, coin::into_balance(musdc));

        // Update LP supply
        pool.lp_supply = pool.lp_supply + lp_minted;

        // Emit event
        event::emit(LiquidityAdded {
            provider: tx_context::sender(ctx),
            msui_amount,
            musdc_amount,
            lp_minted,
        });

        // Create LP receipt
        LPReceipt {
            id: object::new(ctx),
            provider: tx_context::sender(ctx),
            lp_amount: lp_minted,
        }
    }

    /// Entry function wrapper for add_liquidity
    public fun add_liquidity_entry(
        pool: &mut SwapPool,
        msui: Coin<MSUI>,
        musdc: Coin<MUSDC>,
        ctx: &mut TxContext
    ) {
        let receipt = add_liquidity(pool, msui, musdc, ctx);
        transfer::transfer(receipt, tx_context::sender(ctx));
    }

    /// Remove liquidity from the pool
    /// Burns LP receipt and returns tokens
    public fun remove_liquidity(
        pool: &mut SwapPool,
        receipt: LPReceipt,
        ctx: &mut TxContext
    ): (Coin<MSUI>, Coin<MUSDC>) {
        let LPReceipt { id, provider: _, lp_amount } = receipt;
        object::delete(id);

        assert!(lp_amount > 0, E_ZERO_AMOUNT);
        assert!(lp_amount <= pool.lp_supply, E_INSUFFICIENT_LIQUIDITY);

        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        // Calculate tokens to return
        let msui_out = (lp_amount * msui_reserve) / pool.lp_supply;
        let musdc_out = (lp_amount * musdc_reserve) / pool.lp_supply;

        assert!(msui_out > 0, E_INSUFFICIENT_MSUI);
        assert!(musdc_out > 0, E_INSUFFICIENT_MUSDC);

        // Remove from reserves
        let msui_balance = balance::split(&mut pool.msui_reserve, msui_out);
        let musdc_balance = balance::split(&mut pool.musdc_reserve, musdc_out);

        // Update LP supply
        pool.lp_supply = pool.lp_supply - lp_amount;

        // Emit event
        event::emit(LiquidityRemoved {
            provider: tx_context::sender(ctx),
            msui_returned: msui_out,
            musdc_returned: musdc_out,
            lp_burned: lp_amount,
        });

        (coin::from_balance(msui_balance, ctx), coin::from_balance(musdc_balance, ctx))
    }

    /// Entry function wrapper for remove_liquidity
    public fun remove_liquidity_entry(
        pool: &mut SwapPool,
        receipt: LPReceipt,
        ctx: &mut TxContext
    ) {
        let (msui_out, musdc_out) = remove_liquidity(pool, receipt, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(msui_out, sender);
        transfer::public_transfer(musdc_out, sender);
    }

    // ========== View Functions ==========

    /// Get quote for MSUI to MUSDC swap
    public fun get_quote_msui_to_musdc(
        pool: &SwapPool,
        amount_in: u64
    ): u64 {
        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);
        get_amount_out(amount_in, msui_reserve, musdc_reserve)
    }

    /// Get quote for MUSDC to MSUI swap
    public fun get_quote_musdc_to_msui(
        pool: &SwapPool,
        amount_in: u64
    ): u64 {
        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);
        get_amount_out(amount_in, musdc_reserve, msui_reserve)
    }

    /// Get MSUI price in MUSDC (price of 1 MSUI in MUSDC)
    public fun get_msui_price(pool: &SwapPool): u64 {
        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        if (msui_reserve == 0) {
            return 0
        };

        // Price = musdc_reserve / msui_reserve
        // Multiply by 1e9 to maintain precision
        (musdc_reserve * 1_000_000_000) / msui_reserve
    }

    /// Get MUSDC price in MSUI (price of 1 MUSDC in MSUI)
    public fun get_musdc_price(pool: &SwapPool): u64 {
        let msui_reserve = balance::value(&pool.msui_reserve);
        let musdc_reserve = balance::value(&pool.musdc_reserve);

        if (musdc_reserve == 0) {
            return 0
        };

        // Price = msui_reserve / musdc_reserve
        // Multiply by 1e9 to maintain precision
        (msui_reserve * 1_000_000_000) / musdc_reserve
    }

    /// Get pool reserves
    public fun get_reserves(pool: &SwapPool): (u64, u64) {
        (
            balance::value(&pool.msui_reserve),
            balance::value(&pool.musdc_reserve)
        )
    }

    /// Get LP supply
    public fun get_lp_supply(pool: &SwapPool): u64 {
        pool.lp_supply
    }

    /// Get fee in basis points
    public fun get_fee_bps(pool: &SwapPool): u64 {
        pool.fee_bps
    }

    /// Get LP receipt info
    public fun get_lp_receipt_info(receipt: &LPReceipt): (address, u64) {
        (receipt.provider, receipt.lp_amount)
    }

    // ========== Internal Helper Functions ==========

    /// Calculate output amount using constant product formula with fee
    /// Formula: amount_out = (amount_in * 997 * reserve_out) / (reserve_in * 1000 + amount_in * 997)
    fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_in > 0, E_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, E_POOL_EMPTY);

        // Use u128 to prevent overflow in intermediate calculations
        let amount_in_with_fee = (amount_in as u128) * (FEE_MULTIPLIER as u128);
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = ((reserve_in as u128) * (FEE_DIVISOR as u128)) + amount_in_with_fee;

        ((numerator / denominator) as u64)
    }

    /// Integer square root using Newton's method
    fun sqrt(y: u64): u64 {
        if (y < 4) {
            if (y == 0) {
                return 0
            };
            return 1
        };

        let mut z = y;
        let mut x = y / 2 + 1;

        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        };

        z
    }

    // ========== Test-Only Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Test initialization function (empty for swap module)
    }

    #[test_only]
    public fun get_pool_info_for_testing(pool: &SwapPool): (u64, u64, u64, u64) {
        (
            balance::value(&pool.msui_reserve),
            balance::value(&pool.musdc_reserve),
            pool.lp_supply,
            pool.fee_bps
        )
    }
}
