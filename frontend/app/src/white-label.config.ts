/**
 * WHITE-LABEL CONFIGURATION
 * 
 * This is the master configuration file for customizing the platform for different clients.
 * When creating a new fork, update all values in this file according to the client's requirements.
 */

export const WHITE_LABEL_CONFIG = {
  brandColors: {
    primary: "black:700" as const,
    primaryContent: "white" as const,
    primaryContentAlt: "gray:300" as const,
    
    secondary: "silver:100" as const,
    secondaryContent: "black:700" as const,
    secondaryContentAlt: "black:400" as const,
    
    accent1: "blue:500" as const,  
    accent1Content: "white" as const,
    accent1ContentAlt: "blue:100" as const,
    
    accent2: "green:500" as const,
    accent2Content: "black:700" as const,
    accent2ContentAlt: "green:800" as const,
  },

  // ===========================
  // TYPOGRAPHY
  // ===========================
  typography: {
    // Font family for CSS (used in Panda config)
    fontFamily: "Geist, sans-serif",
    // Next.js font import name (should match the import)
    fontImport: "GeistSans" as const,
  },

  // ===========================
  // UNIFIED TOKENS CONFIGURATION
  // ===========================
  tokens: {
    // Main protocol stablecoin
    mainToken: {
      name: "Base Dollar",
      symbol: "BD" as const, 
      ticker: "BD",
      decimals: 18,
      description: "USD-pegged stablecoin on Base",
      icon: "main-token",
      // Core protocol contracts
      deployments: {
        8453: { // Base
          token: "0x252d36f435582ecb01686448d21e8c9ea0b2ca65",
          collateralRegistry: "0x7551ebfc8340b7f91874942be9c653733d4fb04f",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0x9d8fb1d1e2121e86375c07f0ba65dd54cb6ca333",
          multiTroveGetter: "0xad0469046cfcc4806384e3263ace6c11d005d608",
          debtInFrontHelper: "0xc4a5393d6b96bc77e5a80098ed08fdeeff70b974",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
          exchangeHelpersV2: "0x0000000000000000000000000000000000000000",
          redemptionHelper: "0x438d0edb577997898bbef4fe1c798247d7eb5c4f",
        },
      },
    },

    // Governance token (exists but no functionality at launch)
    governanceToken: {
      name: "BaseD Governance Token",
      symbol: "BASED" as const,
      ticker: "BASED",
      icon: "governance-token",
      deployments: {
        8453: {
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0000000000000000000000000000000000000000"
        },
      },
    },

    // Collateral tokens (for borrowing) - Multi-chain support
    collaterals: [
      // === Base Collaterals ===
      {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "100000000",
        maxLTV: 0.9091,
        deployments: {
          8453: {
            collToken: "0x4200000000000000000000000000000000000006",
            borrowerOperations: "0x1867772fba1bcc13d94eb22f1d100ce524148a3f",
            troveManager: "0xa957d42c4c43eb97d5f71b8435eb638e5dd9f639",
            troveNFT: "0xaed689cf95802fbbd9c8a787379d4dc66768c802",
            stabilityPool: "0x7d837bf114785642d225d1101145ddb8af4ba438",
            priceFeed: "0x40b4199347af7738643ef4a12a771f7421b84e7f",
            activePool: "0x254a8267d4e12a8c0f283274632a18a33e49f7c0",
            defaultPool: "0xf5bba496a225211b102201bb54b57a29863ec876",
            collSurplusPool: "0xa304b224e332685bb741cf3d9877172e754983dd",
            sortedTroves: "0x4f1d9102448fde06955a6cd20d085d6b468e92ad",
            addressesRegistry: "0xdad2735973d29e3a8ce26667774a624e0ea97556",
            leverageZapper: "0xcf117d9ea7f4be2c5dd5616abb9890a21b447a84",
          },
        },
      },
      {
        symbol: "WSTETH" as const,
        name: "wstETH",
        icon: "wsteth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "25000000",
        maxLTV: 0.9091,
        deployments: {
          8453: {
            collToken: "0xc1cba3fcea344f92d9239c08c0568f6f2f0ee452",
            borrowerOperations: "0xc4b0a1011f2cb0438429724594d2ab3d4d8ef54a",
            troveManager: "0x79a6a3361eae4d4b80939206426f2320c11a4bfb",
            troveNFT: "0xdb5747eaca2c4283ac56fe2b6ce84cb16c259990",
            stabilityPool: "0xc65a05737d31e0f42c0806c739f3c88dd009c05f",
            priceFeed: "0x176363a20ba1dc75b418d7954f5222499b276186",
            activePool: "0x1021fefc406c9573ab3579fc55be13e3300ef6b1",
            defaultPool: "0x38062c11f7b89b234ca71f4fb39f8f8d32844a20",
            collSurplusPool: "0xdc87cef2be8e9f7f1ad90260e5584e56835d43b3",
            sortedTroves: "0x4dad0339c1c33a247fc137f44bbc5dbe8df80ee1",
            addressesRegistry: "0x3e35fcc70d2ed82adce6c1e8f111554a04b74f3f",
            leverageZapper: "0x87f5a53dffc2137dd05070ac2970e35f7e925d28",
          },
        },
      },
      {
        symbol: "RETH" as const,
        name: "rETH",
        icon: "reth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "25000000",
        maxLTV: 0.9091,
        deployments: {
          8453: {
            collToken: "0xb6fe221fe9eef5aba221c348ba20a1bf5e73624c",
            borrowerOperations: "0x69e933767974fcd7cabeea976226783f4b952521",
            troveManager: "0xd31987fcba98f471b6e4220c52f7741b11b2fc5e",
            troveNFT: "0xec22e1dd649a98d2718cc2d9afb69dbf25ed3fa6",
            stabilityPool: "0x4eb3b6970fd358d34195b5d40e4eb64e0e3c0b6a",
            priceFeed: "0x6627b94533be5bba42d1aaaf982330e9746b6133",
            activePool: "0x1b9a62798e8bae0cea4eb21b4b3775359beb819f",
            defaultPool: "0x3d4eb96fb79ea0d79953423914b2a1472dbdc3cd",
            collSurplusPool: "0x08699bd503d890ce7fd7bf216d7a6e9da1a179e4",
            sortedTroves: "0x637344c0634626bb5d3c8fd5cc0fb332558778f8",
            addressesRegistry: "0xd4763ae6021927784a7a787c1a98b287f919d165",
            leverageZapper: "0xad3fe8eacf1c56e9c1a757df8f2fb2b4f8898d35",
          },
        },
      },
      {
        symbol: "CBBTC" as const,
        name: "cbBTC",
        icon: "cbbtc",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "10000000",
        maxLTV: 0.9091,
        deployments: {
          8453: {
            collToken: "0x92a7aee8afaa71ba0a9cc04a3dbe1f34237c33e0",
            borrowerOperations: "0xb9a3c82486d0b6d72dec55fcc9192af09aaa393b",
            troveManager: "0x835b04eefbb0e32d8f75cfe96acb527a42f1a0d9",
            troveNFT: "0x9bac1f53bb7d309df424f16ee8a0bbb5803b9776",
            stabilityPool: "0x6bd55dd953507641c84a03956760f83d29d65726",
            priceFeed: "0x9e191d9f3f3c138c81753acf6f4ec32e84daa89e",
            activePool: "0xcaa72df531554087318eaf24646958500668b230",
            defaultPool: "0x2019453c36c7272bdea78a0901d448595d8127d2",
            collSurplusPool: "0xeddcfb454f8756e992601666df5adb3389ef15e4",
            sortedTroves: "0xe55530a4205ec2eda84adf9f5efb2f456d5cb721",
            addressesRegistry: "0x1fdea10dc1f6ff27ed9881bdf464fe070dda6f76",
            leverageZapper: "0x7b465f7c3753f4a54583a34b82db8018ed5a24ae",
          },
        },
      },
      {
        symbol: "CBETH" as const,
        name: "cbETH",
        icon: "cbeth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "10000000",
        maxLTV: 0.9091,
        deployments: {
          8453: {
            collToken: "0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22",
            borrowerOperations: "0xfa6e7e44e538b2cf7d73720b2b1942ab28abd1d5",
            troveManager: "0x482de97e667330afba99f8ced527118aec66f15d",
            troveNFT: "0x2c3a69fe04c976a05e72033ac2433bcfaa15b68a",
            stabilityPool: "0x25afbb09d9804482ed8e24295be4a12704fe93ea",
            priceFeed: "0x23bb111e94ec68009da6b8fc50c19628a972b9e0",
            activePool: "0xddac84ab417677f553cced8ababf497226112218",
            defaultPool: "0xc8eb254aabd8a64193fea55aac36087393baf81b",
            collSurplusPool: "0x2d63ae9808cfabdab5cf6aa0202683726e46310f",
            sortedTroves: "0x2792304889f35b60ccd79c3e173837bc6ec3ab44",
            addressesRegistry: "0x98f5ddda4c0250966a446d39167d0bfb8e4ca1b6",
            leverageZapper: "0xa65cacbda151f8c23af7bb62f771f9d5de2a3f83",
          },
        },
      },
    ],

    // Other tokens in the protocol
    otherTokens: {
      // ETH for display purposes
      eth: {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
      },
      // SBOLD - yield-bearing version of the main token
      sbold: {
        symbol: "sBD" as const,
        name: "sBD Token",
        icon: "sbold",
      },
      // Staked version of main token
      staked: {
        symbol: "sBD" as const,
        name: "Staked BD",
        icon: "staked-main-token",
      },
      lusd: {
        symbol: "LUSD" as const,
        name: "LUSD",
        icon: "legacy-stablecoin",
      },
      
      // Additional tokens needed for AMM pairs
      usdc: {
        symbol: "USDC" as const,
        name: "USDC",
        icon: "usdc",
      },
      weth: {
        symbol: "wETH" as const,
        name: "wETH",
        icon: "weth",
      },
      mseth: {
        symbol: "msETH" as const,
        name: "msETH",
        icon: "mseth",
      },
      msusd: {
        symbol: "msUSD" as const,
        name: "msUSD",
        icon: "msusd",
      },
      well: {
        symbol: "WELL" as const,
        name: "WELL",
        icon: "well",
      },
      virtual: {
        symbol: "VIRTUAL" as const,
        name: "VIRTUAL",
        icon: "virtual",
      },
      cbbtc: {
        symbol: "cbBTC" as const,
        name: "cbBTC",
        icon: "cbbtc",
      },
      bold: {
        symbol: "BOLD" as const,
        name: "BOLD",
        icon: "bold",
      },
    },
  },

  // ===========================
  // BRANDING & CONTENT
  // ===========================
  branding: {
    // Core app identity
    appName: "Basedollar",        // Full app name for titles, about pages
    brandName: "Basedollar",      // Core brand name for protocol/version references
    appTagline: "USD-pegged stablecoin on Base",
    appDescription: "Borrow BD against multiple collateral types with AERO synergy",
    appUrl: "https://basedollar.org/",
    
    // External links
    links: {
      docs: {
        base: "https://docs.basedollar.org/",
        redemptions: "https://docs.basedollar.org/redemptions",
        liquidations: "https://docs.basedollar.org/liquidations",
        delegation: "https://docs.basedollar.org/delegation",
        interestRates: "https://docs.basedollar.org/interest-rates",
        earn: "https://docs.basedollar.org/earn",
        staking: "https://docs.basedollar.org/staking",
        aeroManager: "https://docs.basedollar.org/docs/technical-documentation/aero-manager",
      },
      dune: "https://dune.com/basedollar",
      discord: "https://discord.gg/basedollar",
      github: "https://github.com/basedollar/basedollar",
      x: "https://x.com/basedollar",
      friendlyForkProgram: "https://basedollar.org/ecosystem",
      aeroLaunchArticle: "https://aero.xyz/"
    },
    
    // Feature flags and descriptions
    features: {
      showV1Legacy: false, // No V1 legacy content
      friendlyFork: {
        enabled: false,
        title: "Learn more about the Friendly Fork Program",
        description: "A program for collaborative protocol development",
      },
      aeroLaunch: {
        enabled: true,
        title: "Learn more about the upcoming Aero launch",
        description: "The successor of Aerodrome and Velodrome",
      },
    },
    
    // Navigation configuration  
    navigation: {
      showBorrow: true,
      showMultiply: false,
      showEarn: true,
      showStake: false,
    },
    
    // Menu labels (can be customized per deployment)
    menu: {
      dashboard: "Dashboard",
      borrow: "Borrow",
      multiply: "Multiply", 
      earn: "Earn",
      stake: "Stake"
    },
    
    // Common UI text
    ui: {
      connectWallet: "Connect",
      wrongNetwork: "Wrong network",
      loading: "Loading...",
      error: "Error",
    },
  },

  // ===========================
  // EARN POOLS CONFIGURATION
  // ===========================
  earnPools: {
    enableStakedMainToken: false,
    
    // Enable/disable stability pools for collaterals
    enableStabilityPools: true,
    
    // Custom pools configuration (beyond collateral stability pools)
    customPools: [
      // FsBaseD - opt-in layer for AERO rewards
      // TODO: Enable when FsBaseD contracts are deployed
      /*{
        symbol: "fsBaseD",
        name: "FsBaseD (AERO Rewards)",
        enabled: true,
      },*/
    ] as Array<{
      symbol: string;
      name: string;
      enabled: boolean;
    }>,
  },

  // ===========================
  // BASEDOLLAR SPECIFIC FEATURES
  // ===========================
  basedollarFeatures: {
    // Governance configuration
    governance: {
      // Governor address (will be Aragon DAO later)
      governorAddress: "0x519ca17dae2e2a23396ebec12da1f645accec196",
    },

    // AeroManager contract - manages AERO rewards from LP collateral
    aeroManager: {
      address: "0xe8900c7aebca7d212717fe2f4df9f567e3f4d7f4" as `0x${string}`,
      // AERO token address on Base
      aeroTokenAddress: "0x940181a94a35a4569e4529a3cdfb74e38fd98631" as `0x${string}`,
    },
    
    // AERO synergy configuration
    aeroSynergy: {
      enabled: true,
      aeroFarmingTax: 0.10, // 10% of AERO farmed (max 50% cap)
      distribution: {
        POL: 0.80, // 80% to Protocol Owned Liquidity
        FsBaseD: 0.10, // 10% to FsBaseD holders
        GovToken: 0.10, // 10% to BASED stakers
      },
    },
    
    // LP Token collaterals
    lpTokens: {
      sAMM: [],
      vAMM: [],
    },
    
    // Redemption protected branches
    redemptionProtected: {
      enabled: false,
      branches: [],
    },
    
    // Revenue distribution (different from Liquity V2)
    revenueDistribution: {
      sBaseD: 0.80, // 80% to stability pool
      POL: 0.10, // 10% to protocol owned liquidity
      GovToken: 0.10, // 10% to BASED stakers
    },
  },
};

// Type exports for TypeScript support
export type WhiteLabelConfig = typeof WHITE_LABEL_CONFIG;

// Utility functions for dynamic configuration
export function getAvailableEarnPools() {
  const pools: Array<{ symbol: string; name: string; type: 'stability' | 'staked' | 'custom' }> = [];
  
  // Add stability pools for enabled collaterals
  if (WHITE_LABEL_CONFIG.earnPools.enableStabilityPools) {
    WHITE_LABEL_CONFIG.tokens.collaterals.forEach(collateral => {
      pools.push({
        symbol: collateral.symbol.toLowerCase(),
        name: `${collateral.name} Stability Pool`,
        type: 'stability',
      });
    });
  }
  
  // Add custom pools
  WHITE_LABEL_CONFIG.earnPools.customPools.forEach(pool => {
    if (pool.enabled) {
      pools.push({
        symbol: pool.symbol.toLowerCase(),
        name: pool.name,
        type: 'custom',
      });
    }
  });
  
  return pools;
}

export function getEarnPoolSymbols() {
  return getAvailableEarnPools().map(pool => pool.symbol);
}

export function getCollateralSymbols() {
  return WHITE_LABEL_CONFIG.tokens.collaterals.map(collateral => collateral.symbol.toLowerCase());
}
