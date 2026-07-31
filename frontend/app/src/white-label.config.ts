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
          token: "0xd93361b18f07ab25cc32b4cb5005c564a5446eeb",
          collateralRegistry: "0xff4d7de0fefc71ebbfec264a0e5c640080c3d352",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0xd2190a6a531bddb77e3bffc2a3c6d35e143e977f",
          multiTroveGetter: "0x70dafe5ce3523a5efc48dae9e49060f91c0d4315",
          debtInFrontHelper: "0x17d9fd77f42a1381feb51d9b6155fe208ae41ad6",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
          exchangeHelpersV2: "0x0000000000000000000000000000000000000000",
          redemptionHelper: "0xa129e8fb6399138120e441931c85ac50d41b2e3c",
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
            borrowerOperations: "0x573f39f47b3e2f57c8e207ff499d56f3624365a4",
            troveManager: "0x5525edc57f330c732a4a328b3bc390b6a50aecac",
            troveNFT: "0x342ab392194579ed39157aec0d21cd8fd91f090d",
            stabilityPool: "0xf5cef7815771c4c66942d593276a739e340df7ea",
            priceFeed: "0x1e4f3a042285a21497a578e9f16c09ce8d2d13e3",
            activePool: "0x1ec207fe0444aef9d120a41efacdb0862b57a861",
            defaultPool: "0x7f0ef2a573efd0d3e27b9946e2f06f605f93301c",
            collSurplusPool: "0xd97aa235cb63d26a8c89b26f15d81df36334b3bc",
            sortedTroves: "0x428db802a3a9560030e676b6ff614bc8936234eb",
            addressesRegistry: "0xbd63c9a0284992e1206d23d8f1bd3d45a9710a1c",
            leverageZapper: "0x5078635f420d470f0a6bbfbfb6b70357abfc7ccf",
          },
        },
      },
      {
        symbol: "WSTETH" as const,
        name: "wstETH",
        icon: "wsteth",
        collateralRatio: 1.2, // 120% MCR
        maxDeposit: "25000000",
        maxLTV: 0.8333,
        deployments: {
          8453: {
            collToken: "0xc1cba3fcea344f92d9239c08c0568f6f2f0ee452",
            borrowerOperations: "0xbc2c9c08949d739b12497b6d71f825e23837b54c",
            troveManager: "0x51786a5c681bd0cd4c19fe75646780edbcd7a32c",
            troveNFT: "0x31ff2c9744a2baa6a9796b8001a01785120032be",
            stabilityPool: "0xa84c3e838a3ae328fad5c2cd375e6a8295f5a907",
            priceFeed: "0x7654f5dcaf24fbc0dc3e458a57ad271fef5e88a4",
            activePool: "0xe5951cf10d35fb1bba73ddefd48a8cd93aeb1656",
            defaultPool: "0x078ee7130618b3ae36d245d8a33ecc1b1d12e24b",
            collSurplusPool: "0x91e4bdb4b2c650fd289c32c439c74e1ebc933f40",
            sortedTroves: "0x366a9f1923cfd65e2a20fce0bdd274ce98f7e1c5",
            addressesRegistry: "0x0bb478dd1aba51e9467e6be1f47b12b0ef75e261",
            leverageZapper: "0x6b877482f7c7b9647733c275fc8723c411fae9c9",
          },
        },
      },
      {
        symbol: "RETH" as const,
        name: "rETH",
        icon: "reth",
        collateralRatio: 1.2, // 120% MCR
        maxDeposit: "25000000",
        maxLTV: 0.8333,
        deployments: {
          8453: {
            collToken: "0xb6fe221fe9eef5aba221c348ba20a1bf5e73624c",
            borrowerOperations: "0x0468b55832368a419cd499d0c42ec483f6f58477",
            troveManager: "0xd36a6eb47c0ae193449a2ae580a069466ca3195f",
            troveNFT: "0xc197203a5e30f5679e4bb079a8a2ab5f73855d1f",
            stabilityPool: "0xbae0db79b94a6f7a08906e8010e514676436a84d",
            priceFeed: "0x52abd0e9ea72d9b88227c35ddba077e1c681175d",
            activePool: "0x98685fd59cd9f1d65b534d96d93e895453be4924",
            defaultPool: "0x2d8b76b3f1967436dcc759c3a9fae4052cf5579b",
            collSurplusPool: "0xac8cb85dfac16afa705bcc0bbee899e43c1a7f4c",
            sortedTroves: "0xd40e5bfadf859084931aab7fcc4ad5aef0fd6c6f",
            addressesRegistry: "0xf22a52d83cde23cc531ea97a9d51b0cfea01a490",
            leverageZapper: "0x6966d1d1b1b0743869c252092ca2398b0c5cece4",
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
            collToken: "0xf9828209732cd39ccc61b346aed656133c9a7cba",
            borrowerOperations: "0xd28d6a688c6370279166209dcac41a0b99b88cdc",
            troveManager: "0x4605e79fed0fcf1e3927d32cf1164fb73c82bd1c",
            troveNFT: "0xc032437a2c5168281372d3755545820f77cc4fbf",
            stabilityPool: "0x6624f7b1de64deae5a2fcad5ecca8345ea11e849",
            priceFeed: "0x1ffe897de290bcf81f5496ea53968605a390faf0",
            activePool: "0xce8878006640699c0990adeefe48a7e6a4b044cb",
            defaultPool: "0xba4be5d28208cfbe9c82d476ff1345615d455324",
            collSurplusPool: "0x0782d62833845c3f8241ea0c899eb1d801ecc976",
            sortedTroves: "0x60c138013994daca2884353ca6ec03f0e6054326",
            addressesRegistry: "0x188733dc2ebfe265090c32ba891a7d40501a7e82",
            leverageZapper: "0x61d181194e2b375b2498d9e79ef037d74743fc2f",
          },
        },
      },
      {
        symbol: "CBETH" as const,
        name: "cbETH",
        icon: "cbeth",
        collateralRatio: 1.2, // 120% MCR
        maxDeposit: "10000000",
        maxLTV: 0.8333,
        deployments: {
          8453: {
            collToken: "0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22",
            borrowerOperations: "0x6970765d8ddfae97a19e2dd78b78fd26b1a20bb0",
            troveManager: "0x67db926a406af2c1a3bafbb61356ffbab12af3e3",
            troveNFT: "0xede42f86c5b55cb2e8851c439fb33fdab7d25eb4",
            stabilityPool: "0x2e4a7fde211b8328dd4f299a46764bb3020c3e86",
            priceFeed: "0xa6c8daeacc8101dc70546c8c685683c22b250c8c",
            activePool: "0xbafd3d220ce7aa3e83aa85701126cfd1ee6de2ec",
            defaultPool: "0x611f336762175b8c8e36ddcec7cf07e69d122f05",
            collSurplusPool: "0x07c82c6cc1074f2dbbd348fd6b7da0b66c65d2c7",
            sortedTroves: "0x0b351c8bf7e73e91f22ba4b76a1d87c1eec71cc8",
            addressesRegistry: "0x76550499733b3541541aea4beb75157e5ca0eb3d",
            leverageZapper: "0xed5f189ca83505b8e81300ddcefd5864ac8299c3",
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
    },
    
    // Feature flags and descriptions
    features: {
      showV1Legacy: false, // No V1 legacy content
      friendlyFork: {
        enabled: true,
        title: "Learn more about the Friendly Fork Program",
        description: "A program for collaborative protocol development",
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
      address: "0x8daf079a4ff27a84cc392c67e879f8b0f7938a82" as `0x${string}`,
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
