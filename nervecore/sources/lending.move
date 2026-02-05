module nervecore::lending {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;
    use nervecore::faucet::{MSUI, MUSDC};

    // Shared lending pool
    public struct LendingPool has key {
        id: UID,
        msui_reserve: Balance<MSUI>,
        musdc_reserve: Balance<MUSDC>,
        total_deposits: u64,
        total_borrows: u64,
    }

    // Receipt NFT
    public struct LendingReceipt has key, store {
        id: UID,
        depositor: address,
        deposit_amount: u64,
        borrowed_amount: u64,
        deposit_timestamp: u64,
    }

    // Events
    public struct PoolInitialized has copy, drop {
        pool_id: address,
    }

    public struct Deposited has copy, drop {
        receipt_id: address,
        depositor: address,
        amount: u64,
        timestamp: u64,
    }

    public struct Borrowed has copy, drop {
        receipt_id: address,
        borrower: address,
        amount: u64,
        total_borrowed: u64,
    }

    public struct Repaid has copy, drop {
        receipt_id: address,
        borrower: address,
        amount: u64,
        remaining_borrowed: u64,
    }

    public struct Withdrawn has copy, drop {
        receipt_id: address,
        depositor: address,
        amount: u64,
    }

    // Constants
    const LTV_PERCENT: u64 = 80; // 80% LTV
    const APY_PERCENT: u64 = 5;  // 5% APY (display only)
    const PERCENT_DIVISOR: u64 = 100;

    // Errors
    const E_INSUFFICIENT_COLLATERAL: u64 = 1;
    const E_NOT_OWNER: u64 = 2;
    const E_OUTSTANDING_BORROW: u64 = 3;
    const E_INSUFFICIENT_POOL_LIQUIDITY: u64 = 4;
    const E_REPAY_EXCEEDS_BORROW: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;

    // Initialize function - creates the lending pool
    fun init(ctx: &mut TxContext) {
        let pool = LendingPool {
            id: object::new(ctx),
            msui_reserve: balance::zero<MSUI>(),
            musdc_reserve: balance::zero<MUSDC>(),
            total_deposits: 0,
            total_borrows: 0,
        };
        let pool_id = object::uid_to_address(&pool.id);

        transfer::share_object(pool);

        event::emit(PoolInitialized {
            pool_id,
        });
    }

    // Deposit MSUI and receive a LendingReceipt
    public entry fun deposit(
        pool: &mut LendingPool,
        msui_coin: Coin<MSUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&msui_coin);
        assert!(amount > 0, E_ZERO_AMOUNT);

        let depositor = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Add MSUI to pool reserve
        let msui_balance = coin::into_balance(msui_coin);
        balance::join(&mut pool.msui_reserve, msui_balance);
        pool.total_deposits = pool.total_deposits + amount;

        // Create receipt NFT
        let receipt = LendingReceipt {
            id: object::new(ctx),
            depositor,
            deposit_amount: amount,
            borrowed_amount: 0,
            deposit_timestamp: timestamp,
        };
        let receipt_id = object::uid_to_address(&receipt.id);

        // Transfer receipt to depositor
        transfer::transfer(receipt, depositor);

        // Emit event
        event::emit(Deposited {
            receipt_id,
            depositor,
            amount,
            timestamp,
        });
    }

    // Borrow MUSDC against deposited MSUI (up to 80% LTV)
    public entry fun borrow(
        pool: &mut LendingPool,
        receipt: &mut LendingReceipt,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let borrower = tx_context::sender(ctx);
        assert!(receipt.depositor == borrower, E_NOT_OWNER);
        assert!(amount > 0, E_ZERO_AMOUNT);

        // Calculate max borrow: deposit_amount * LTV_PERCENT / 100
        let max_borrow = (receipt.deposit_amount * LTV_PERCENT) / PERCENT_DIVISOR;
        let new_borrowed_amount = receipt.borrowed_amount + amount;
        assert!(new_borrowed_amount <= max_borrow, E_INSUFFICIENT_COLLATERAL);

        // Check pool has enough MUSDC liquidity
        let pool_liquidity = balance::value(&pool.musdc_reserve);
        assert!(pool_liquidity >= amount, E_INSUFFICIENT_POOL_LIQUIDITY);

        // Withdraw MUSDC from pool
        let borrowed_balance = balance::split(&mut pool.musdc_reserve, amount);
        let borrowed_coin = coin::from_balance(borrowed_balance, ctx);

        // Update receipt and pool
        receipt.borrowed_amount = new_borrowed_amount;
        pool.total_borrows = pool.total_borrows + amount;

        // Transfer borrowed MUSDC to borrower
        transfer::public_transfer(borrowed_coin, borrower);

        // Emit event
        event::emit(Borrowed {
            receipt_id: object::uid_to_address(&receipt.id),
            borrower,
            amount,
            total_borrowed: new_borrowed_amount,
        });
    }

    // Repay borrowed MUSDC
    public entry fun repay(
        pool: &mut LendingPool,
        receipt: &mut LendingReceipt,
        musdc_coin: Coin<MUSDC>,
        ctx: &mut TxContext
    ) {
        let borrower = tx_context::sender(ctx);
        assert!(receipt.depositor == borrower, E_NOT_OWNER);

        let repay_amount = coin::value(&musdc_coin);
        assert!(repay_amount > 0, E_ZERO_AMOUNT);
        assert!(repay_amount <= receipt.borrowed_amount, E_REPAY_EXCEEDS_BORROW);

        // Add MUSDC back to pool
        let musdc_balance = coin::into_balance(musdc_coin);
        balance::join(&mut pool.musdc_reserve, musdc_balance);

        // Update receipt and pool
        receipt.borrowed_amount = receipt.borrowed_amount - repay_amount;
        pool.total_borrows = pool.total_borrows - repay_amount;

        // Emit event
        event::emit(Repaid {
            receipt_id: object::uid_to_address(&receipt.id),
            borrower,
            amount: repay_amount,
            remaining_borrowed: receipt.borrowed_amount,
        });
    }

    // Withdraw deposited MSUI (must repay all borrows first)
    public entry fun withdraw(
        pool: &mut LendingPool,
        receipt: LendingReceipt,
        ctx: &mut TxContext
    ) {
        let depositor = tx_context::sender(ctx);
        assert!(receipt.depositor == depositor, E_NOT_OWNER);
        assert!(receipt.borrowed_amount == 0, E_OUTSTANDING_BORROW);

        let LendingReceipt {
            id,
            depositor: _,
            deposit_amount,
            borrowed_amount: _,
            deposit_timestamp: _,
        } = receipt;

        let receipt_id = object::uid_to_address(&id);

        // Withdraw MSUI from pool
        let msui_balance = balance::split(&mut pool.msui_reserve, deposit_amount);
        let msui_coin = coin::from_balance(msui_balance, ctx);

        // Update pool
        pool.total_deposits = pool.total_deposits - deposit_amount;

        // Delete receipt (burn NFT)
        object::delete(id);

        // Transfer MSUI back to depositor
        transfer::public_transfer(msui_coin, depositor);

        // Emit event
        event::emit(Withdrawn {
            receipt_id,
            depositor,
            amount: deposit_amount,
        });
    }

    // View functions
    public fun get_deposit_amount(receipt: &LendingReceipt): u64 {
        receipt.deposit_amount
    }

    public fun get_borrowed_amount(receipt: &LendingReceipt): u64 {
        receipt.borrowed_amount
    }

    public fun get_deposit_timestamp(receipt: &LendingReceipt): u64 {
        receipt.deposit_timestamp
    }

    public fun get_depositor(receipt: &LendingReceipt): address {
        receipt.depositor
    }

    public fun get_max_borrow(receipt: &LendingReceipt): u64 {
        (receipt.deposit_amount * LTV_PERCENT) / PERCENT_DIVISOR
    }

    public fun get_available_to_borrow(receipt: &LendingReceipt): u64 {
        let max_borrow = get_max_borrow(receipt);
        max_borrow - receipt.borrowed_amount
    }

    public fun get_pool_msui_reserve(pool: &LendingPool): u64 {
        balance::value(&pool.msui_reserve)
    }

    public fun get_pool_musdc_reserve(pool: &LendingPool): u64 {
        balance::value(&pool.musdc_reserve)
    }

    public fun get_total_deposits(pool: &LendingPool): u64 {
        pool.total_deposits
    }

    public fun get_total_borrows(pool: &LendingPool): u64 {
        pool.total_borrows
    }

    public fun ltv_percent(): u64 { LTV_PERCENT }
    public fun apy_percent(): u64 { APY_PERCENT }

    // Test-only functions
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun create_lending_pool_for_testing(ctx: &mut TxContext): LendingPool {
        LendingPool {
            id: object::new(ctx),
            msui_reserve: balance::zero<MSUI>(),
            musdc_reserve: balance::zero<MUSDC>(),
            total_deposits: 0,
            total_borrows: 0,
        }
    }
}
