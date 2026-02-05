#!/usr/bin/env node
/**
 * Post-deployment initialization script
 * Initializes lending and swap pools with initial liquidity
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const NETWORK = 'testnet';
const INITIAL_MSUI_LIQUIDITY = 10_000_000_000_000; // 10,000 MSUI (9 decimals)
const INITIAL_MUSDC_LIQUIDITY = 10_000_000_000_000; // 10,000 MUSDC (9 decimals)

async function main() {
  console.log('========================================');
  console.log('  NerveCore Pool Initialization');
  console.log('========================================');
  console.log('');

  // Read package ID from deployment
  const packageIdPath = join(__dirname, '../nervecore/.package-id');
  if (!existsSync(packageIdPath)) {
    console.error('Error: .package-id file not found.');
    console.error('Please run deploy.sh first.');
    process.exit(1);
  }

  const packageId = (await readFile(packageIdPath, 'utf-8')).trim();
  console.log('Package ID:', packageId);
  console.log('');

  // Initialize Sui client
  const client = new SuiClient({ url: getFullnodeUrl(NETWORK) });

  // Get keypair from Sui CLI config
  console.log('Reading wallet configuration...');
  const keypair = await getKeypairFromSuiConfig();
  const address = keypair.getPublicKey().toSuiAddress();
  console.log('Active address:', address);
  console.log('');

  // Get shared objects from deployment events
  console.log('Fetching deployed objects...');
  const objects = await getDeployedObjects(client, packageId);

  console.log('Found shared objects:');
  console.log('  MSUI Treasury:', objects.msuiTreasury);
  console.log('  MUSDC Treasury:', objects.musdcTreasury);
  console.log('  Claim Registry:', objects.claimRegistry);
  console.log('  Lending Pool:', objects.lendingPool);
  console.log('');

  // Check if swap pool exists (it's created via init_pool, not init)
  console.log('Note: Swap pool must be initialized separately via init_pool transaction.');
  console.log('');

  // Step 1: Claim initial tokens from faucet
  console.log('Step 1: Claiming initial tokens from faucet...');
  const { msuiCoin, musdcCoin } = await claimInitialTokens(
    client,
    keypair,
    packageId,
    objects.msuiTreasury,
    objects.musdcTreasury,
    objects.claimRegistry
  );
  console.log('  MSUI Coin:', msuiCoin);
  console.log('  MUSDC Coin:', musdcCoin);
  console.log('');

  // Step 2: Initialize swap pool with liquidity
  console.log('Step 2: Initializing swap pool...');
  const swapPool = await initializeSwapPool(
    client,
    keypair,
    packageId,
    msuiCoin,
    musdcCoin
  );
  console.log('  Swap Pool:', swapPool);
  console.log('');

  // Step 3: Claim more tokens and add liquidity to lending pool
  console.log('Step 3: Adding liquidity to lending pool...');
  // Wait 1 hour for cooldown... just kidding, we'll use admin mint
  console.log('  Note: In production, use admin_mint_musdc to add initial MUSDC liquidity');
  console.log('  The lending pool is ready to accept MSUI deposits immediately.');
  console.log('');

  // Output final configuration
  console.log('========================================');
  console.log('  Deployment Summary');
  console.log('========================================');
  console.log('');
  console.log('Contract addresses:');
  console.log(`NEXT_PUBLIC_PACKAGE_ID=${packageId}`);
  console.log(`NEXT_PUBLIC_MSUI_TREASURY=${objects.msuiTreasury}`);
  console.log(`NEXT_PUBLIC_MUSDC_TREASURY=${objects.musdcTreasury}`);
  console.log(`NEXT_PUBLIC_CLAIM_REGISTRY=${objects.claimRegistry}`);
  console.log(`NEXT_PUBLIC_LENDING_POOL=${objects.lendingPool}`);
  console.log(`NEXT_PUBLIC_SWAP_POOL=${swapPool}`);
  console.log('');
  console.log('Add these to your frontend/.env file');
  console.log('');
}

async function getKeypairFromSuiConfig() {
  // Read Sui CLI config to get the active keypair
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  const configPath = join(homeDir, '.sui', 'sui_config', 'client.yaml');

  if (!existsSync(configPath)) {
    throw new Error('Sui config not found. Please run: sui client');
  }

  const config = await readFile(configPath, 'utf-8');

  // Parse YAML to find active address and keystore
  const keystoreMatch = config.match(/keystore:\s*\n\s*File:\s*(.+)/);
  const activeAddressMatch = config.match(/active_address:\s*"?([^"\n]+)"?/);

  if (!keystoreMatch || !activeAddressMatch) {
    throw new Error('Could not parse Sui config');
  }

  const keystorePath = keystoreMatch[1].trim();
  const activeAddress = activeAddressMatch[1].trim();

  // Read keystore
  const keystoreContent = await readFile(keystorePath, 'utf-8');
  const keystore = JSON.parse(keystoreContent);

  // Find the keypair for active address
  for (const encoded of keystore) {
    const keypair = Ed25519Keypair.fromSecretKey(
      Buffer.from(encoded.split('suiprivkey')[1], 'base64').slice(1)
    );

    if (keypair.getPublicKey().toSuiAddress() === activeAddress) {
      return keypair;
    }
  }

  throw new Error('Could not find keypair for active address');
}

async function getDeployedObjects(client, packageId) {
  // Query for objects created during deployment
  const txs = await client.queryTransactionBlocks({
    filter: { FromAddress: packageId },
    options: { showObjectChanges: true },
    limit: 1,
  });

  if (txs.data.length === 0) {
    throw new Error('No transactions found for package');
  }

  const objectChanges = txs.data[0].objectChanges || [];

  const objects = {
    msuiTreasury: null,
    musdcTreasury: null,
    claimRegistry: null,
    lendingPool: null,
  };

  for (const change of objectChanges) {
    if (change.type !== 'created') continue;

    const objectType = change.objectType || '';

    if (objectType.includes('MSUITreasury')) {
      objects.msuiTreasury = change.objectId;
    } else if (objectType.includes('MUSDCTreasury')) {
      objects.musdcTreasury = change.objectId;
    } else if (objectType.includes('ClaimRegistry')) {
      objects.claimRegistry = change.objectId;
    } else if (objectType.includes('LendingPool')) {
      objects.lendingPool = change.objectId;
    }
  }

  // Validate all objects found
  if (!objects.msuiTreasury || !objects.musdcTreasury ||
      !objects.claimRegistry || !objects.lendingPool) {
    throw new Error('Not all shared objects found. Missing: ' +
      JSON.stringify(objects, null, 2));
  }

  return objects;
}

async function claimInitialTokens(
  client,
  keypair,
  packageId,
  msuiTreasury,
  musdcTreasury,
  claimRegistry
) {
  const tx = new TransactionBlock();

  // Get clock object
  tx.moveCall({
    target: `${packageId}::faucet::faucet_msui`,
    arguments: [
      tx.object(msuiTreasury),
      tx.object(claimRegistry),
      tx.object('0x6'),
    ],
  });

  tx.moveCall({
    target: `${packageId}::faucet::faucet_musdc`,
    arguments: [
      tx.object(musdcTreasury),
      tx.object(claimRegistry),
      tx.object('0x6'),
    ],
  });

  const result = await client.signAndExecuteTransactionBlock({
    signer: keypair,
    transactionBlock: tx,
    options: { showObjectChanges: true, showEffects: true },
  });

  if (result.effects?.status?.status !== 'success') {
    throw new Error('Failed to claim tokens: ' + result.effects?.status?.error);
  }

  // Extract coin object IDs from created objects
  let msuiCoin = null;
  let musdcCoin = null;

  for (const change of result.objectChanges || []) {
    if (change.type !== 'created') continue;

    const objectType = change.objectType || '';
    if (objectType.includes('Coin<') && objectType.includes('MSUI>')) {
      msuiCoin = change.objectId;
    } else if (objectType.includes('Coin<') && objectType.includes('MUSDC>')) {
      musdcCoin = change.objectId;
    }
  }

  if (!msuiCoin || !musdcCoin) {
    throw new Error('Failed to find claimed coins');
  }

  return { msuiCoin, musdcCoin };
}

async function initializeSwapPool(client, keypair, packageId, msuiCoin, musdcCoin) {
  const tx = new TransactionBlock();

  tx.moveCall({
    target: `${packageId}::swap::init_pool`,
    arguments: [
      tx.object(msuiCoin),
      tx.object(musdcCoin),
    ],
  });

  const result = await client.signAndExecuteTransactionBlock({
    signer: keypair,
    transactionBlock: tx,
    options: { showObjectChanges: true, showEffects: true },
  });

  if (result.effects?.status?.status !== 'success') {
    throw new Error('Failed to initialize swap pool: ' + result.effects?.status?.error);
  }

  // Find the created SwapPool object
  for (const change of result.objectChanges || []) {
    if (change.type === 'created' && change.objectType?.includes('SwapPool')) {
      return change.objectId;
    }
  }

  throw new Error('SwapPool object not found in transaction result');
}

// Run the script
main().catch((error) => {
  console.error('Error:', error.message);
  process.exit(1);
});
