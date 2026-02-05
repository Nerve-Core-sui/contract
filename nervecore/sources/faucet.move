module nervecore::faucet {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;
    use std::option;

    // One-time witness for MSUI
    public struct MSUI has drop {}

    // One-time witness for MUSDC
    public struct MUSDC has drop {}

    // Shared treasury for MSUI
    public struct MSUITreasury has key {
        id: UID,
        cap: TreasuryCap<MSUI>,
    }

    // Shared treasury for MUSDC
    public struct MUSDCTreasury has key {
        id: UID,
        cap: TreasuryCap<MUSDC>,
    }

    // Shared claim registry
    public struct ClaimRegistry has key {
        id: UID,
        last_claim_msui: Table<address, u64>,
        last_claim_musdc: Table<address, u64>,
    }

    // Admin capability for emergency controls
    public struct AdminCap has key, store {
        id: UID,
    }

    // Events
    public struct FaucetInitialized has copy, drop {
        registry_id: address,
        msui_treasury_id: address,
        musdc_treasury_id: address,
    }

    public struct TokensClaimed has copy, drop {
        recipient: address,
        token_type: vector<u8>,
        amount: u64,
        timestamp: u64,
    }

    // Constants
    const CLAIM_AMOUNT: u64 = 1_000_000_000_000; // 1000 tokens (9 decimals)
    const COOLDOWN_MS: u64 = 3_600_000; // 1 hour in milliseconds

    // Errors
    const E_COOLDOWN_NOT_PASSED: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;

    // Initialize function - called once on publish
    fun init(ctx: &mut TxContext) {
        // Create MSUI coin metadata and treasury
        let (msui_treasury_cap, msui_metadata) = coin::create_currency(
            MSUI {},
            9, // decimals
            b"MSUI",
            b"Mock SUI",
            b"Mock SUI token for testing on Sui Network",
            option::none(),
            ctx
        );

        // Create MUSDC coin metadata and treasury
        let (musdc_treasury_cap, musdc_metadata) = coin::create_currency(
            MUSDC {},
            9, // decimals
            b"MUSDC",
            b"Mock USDC",
            b"Mock USDC stablecoin for testing on Sui Network",
            option::none(),
            ctx
        );

        // Create and share MSUI treasury
        let msui_treasury = MSUITreasury {
            id: object::new(ctx),
            cap: msui_treasury_cap,
        };
        let msui_treasury_id = object::uid_to_address(&msui_treasury.id);

        // Create and share MUSDC treasury
        let musdc_treasury = MUSDCTreasury {
            id: object::new(ctx),
            cap: musdc_treasury_cap,
        };
        let musdc_treasury_id = object::uid_to_address(&musdc_treasury.id);

        // Create and share claim registry
        let registry = ClaimRegistry {
            id: object::new(ctx),
            last_claim_msui: table::new(ctx),
            last_claim_musdc: table::new(ctx),
        };
        let registry_id = object::uid_to_address(&registry.id);

        // Freeze the metadata objects (standard practice)
        transfer::public_freeze_object(msui_metadata);
        transfer::public_freeze_object(musdc_metadata);

        // Share the treasury objects
        transfer::share_object(msui_treasury);
        transfer::share_object(musdc_treasury);
        transfer::share_object(registry);

        // Create admin capability
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));

        // Emit initialization event
        event::emit(FaucetInitialized {
            registry_id,
            msui_treasury_id,
            musdc_treasury_id,
        });
    }

    // Faucet MSUI tokens
    public entry fun faucet_msui(
        treasury: &mut MSUITreasury,
        registry: &mut ClaimRegistry,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        // Check cooldown
        assert!(
            can_claim_internal(&registry.last_claim_msui, sender, current_time),
            E_COOLDOWN_NOT_PASSED
        );

        // Mint tokens
        let minted_coin = coin::mint(&mut treasury.cap, CLAIM_AMOUNT, ctx);

        // Update last claim time
        if (table::contains(&registry.last_claim_msui, sender)) {
            let last_claim = table::borrow_mut(&mut registry.last_claim_msui, sender);
            *last_claim = current_time;
        } else {
            table::add(&mut registry.last_claim_msui, sender, current_time);
        };

        // Transfer to sender
        transfer::public_transfer(minted_coin, sender);

        // Emit event
        event::emit(TokensClaimed {
            recipient: sender,
            token_type: b"MSUI",
            amount: CLAIM_AMOUNT,
            timestamp: current_time,
        });
    }

    // Faucet MUSDC tokens
    public entry fun faucet_musdc(
        treasury: &mut MUSDCTreasury,
        registry: &mut ClaimRegistry,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        // Check cooldown
        assert!(
            can_claim_internal(&registry.last_claim_musdc, sender, current_time),
            E_COOLDOWN_NOT_PASSED
        );

        // Mint tokens
        let minted_coin = coin::mint(&mut treasury.cap, CLAIM_AMOUNT, ctx);

        // Update last claim time
        if (table::contains(&registry.last_claim_musdc, sender)) {
            let last_claim = table::borrow_mut(&mut registry.last_claim_musdc, sender);
            *last_claim = current_time;
        } else {
            table::add(&mut registry.last_claim_musdc, sender, current_time);
        };

        // Transfer to sender
        transfer::public_transfer(minted_coin, sender);

        // Emit event
        event::emit(TokensClaimed {
            recipient: sender,
            token_type: b"MUSDC",
            amount: CLAIM_AMOUNT,
            timestamp: current_time,
        });
    }

    // Helper function: get cooldown remaining for MSUI in milliseconds
    public fun get_cooldown_remaining_msui(
        registry: &ClaimRegistry,
        addr: address,
        clock: &Clock
    ): u64 {
        let current_time = clock::timestamp_ms(clock);
        get_cooldown_remaining_internal(&registry.last_claim_msui, addr, current_time)
    }

    // Helper function: get cooldown remaining for MUSDC in milliseconds
    public fun get_cooldown_remaining_musdc(
        registry: &ClaimRegistry,
        addr: address,
        clock: &Clock
    ): u64 {
        let current_time = clock::timestamp_ms(clock);
        get_cooldown_remaining_internal(&registry.last_claim_musdc, addr, current_time)
    }

    // Helper function: check if address can claim MSUI
    public fun can_claim_msui(
        registry: &ClaimRegistry,
        addr: address,
        clock: &Clock
    ): bool {
        let current_time = clock::timestamp_ms(clock);
        can_claim_internal(&registry.last_claim_msui, addr, current_time)
    }

    // Helper function: check if address can claim MUSDC
    public fun can_claim_musdc(
        registry: &ClaimRegistry,
        addr: address,
        clock: &Clock
    ): bool {
        let current_time = clock::timestamp_ms(clock);
        can_claim_internal(&registry.last_claim_musdc, addr, current_time)
    }

    // Internal helper: check if can claim
    fun can_claim_internal(
        last_claim_table: &Table<address, u64>,
        addr: address,
        current_time: u64
    ): bool {
        if (!table::contains(last_claim_table, addr)) {
            return true
        };

        let last_claim = *table::borrow(last_claim_table, addr);
        let time_passed = current_time - last_claim;
        time_passed >= COOLDOWN_MS
    }

    // Internal helper: get cooldown remaining
    fun get_cooldown_remaining_internal(
        last_claim_table: &Table<address, u64>,
        addr: address,
        current_time: u64
    ): u64 {
        if (!table::contains(last_claim_table, addr)) {
            return 0
        };

        let last_claim = *table::borrow(last_claim_table, addr);
        let time_passed = current_time - last_claim;

        if (time_passed >= COOLDOWN_MS) {
            0
        } else {
            COOLDOWN_MS - time_passed
        }
    }

    // Admin function: emergency mint (bypasses cooldown)
    public entry fun admin_mint_msui(
        _admin: &AdminCap,
        treasury: &mut MSUITreasury,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let minted_coin = coin::mint(&mut treasury.cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
    }

    // Admin function: emergency mint MUSDC (bypasses cooldown)
    public entry fun admin_mint_musdc(
        _admin: &AdminCap,
        treasury: &mut MUSDCTreasury,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let minted_coin = coin::mint(&mut treasury.cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
    }

    // Getter functions
    public fun claim_amount(): u64 { CLAIM_AMOUNT }
    public fun cooldown_ms(): u64 { COOLDOWN_MS }

    // Test-only functions
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
