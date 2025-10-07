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
    
    accent1: "red:500" as const,  
    accent1Content: "white" as const,
    accent1ContentAlt: "red:100" as const,
    
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
      name: "Basedollar",
      symbol: "BD" as const, 
      ticker: "BD",
      decimals: 18,
      description: "USD-pegged stablecoin on Base",
      icon: "main-token",
      // Core protocol contracts (deployment addresses TBD)
      deployments: {
        8453: { // Base
          token: "0x0000000000000000000000000000000000000000", // TBD - BD deployment
          collateralRegistry: "0x0000000000000000000000000000000000000000", // TBD
          governance: "0x0000000000000000000000000000000000000000", // TBD
          hintHelpers: "0x0000000000000000000000000000000000000000", // TBD
          multiTroveGetter: "0x0000000000000000000000000000000000000000", // TBD
          exchangeHelpers: "0x0000000000000000000000000000000000000000", // TBD
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
          token: "0x0000000000000000000000000000000000000000", // TBD - BASED token
          staking: "0x0000000000000000000000000000000000000000" // TBD - staking contract
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
        maxDeposit: "100000000", // $100M initial debt limit
        maxLTV: 0.9091, // 90.91% max LTV
        deployments: {
          8453: {
            collToken: "0x4200000000000000000000000000000000000006", // WETH on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      {
        symbol: "RETH" as const,
        name: "rETH", 
        icon: "reth",
        collateralRatio: 1.1, // 110% MCR for LSTs
        maxDeposit: "25000000", // $25M initial debt limit
        maxLTV: 0.9091, // 90.91% max LTV
        deployments: {
          8453: {
            collToken: "0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c", // rETH on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      // wstETH (87.5% LTV)
      {
        symbol: "WSTETH" as const,
        name: "wstETH",
        icon: "wsteth",
        collateralRatio: 1.143, // 87.5% LTV
        maxDeposit: "50000000", // $50M initial debt limit
        maxLTV: 0.875,
        deployments: {
          8453: {
            collToken: "0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452", // wstETH on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      // superOETHb (85% LTV)
      {
        symbol: "SUPEROETHB" as const,
        name: "superOETHb",
        icon: "oseth",
        collateralRatio: 1.176, // 85% LTV
        maxDeposit: "25000000", // $25M initial debt limit
        maxLTV: 0.85,
        deployments: {
          8453: {
            collToken: "0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3", // superOETHb on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      // cbBTC (87.5% LTV)
      {
        symbol: "CBBTC" as const,
        name: "cbBTC",
        icon: "cbbtc",
        collateralRatio: 1.143, // 87.5% LTV
        maxDeposit: "100000000", // $100M initial debt limit
        maxLTV: 0.875,
        deployments: {
          8453: {
            collToken: "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf", // cbBTC on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      // AERO (TBD LTV)
      {
        symbol: "AERO" as const,
        name: "AERO",
        icon: "aero",
        collateralRatio: 1.25, // 80% LTV (placeholder)
        maxDeposit: "10000000", // $10M initial debt limit
        maxLTV: 0.80,
        deployments: {
          8453: {
            collToken: "0x940181a94A35A4569E4529A3CDfB74e38FD98631", // AERO on Base
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
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
    // AERO synergy configuration
    aeroSynergy: {
      enabled: true,
      aeroFarmingTax: 0.35, // 35% of AERO farmed
      distribution: {
        POL: 0.80, // 80% to Protocol Owned Liquidity
        FsBaseD: 0.10, // 10% to FsBaseD holders
        GovToken: 0.10, // 10% to BASED stakers
      },
    },
    
    // LP Token collaterals
    lpTokens: {
      sAMM: [
        { symbol: "sAMM_wETH/msETH", tvl: "$18.5M", apr: "10.64%", ltv: 0.825 },
        { symbol: "sAMM_msUSD/USDC", tvl: "$10M", apr: "12.71%", ltv: 0.825 },
        { symbol: "sAMM_BD/USDC", tvl: "$4M", apr: "8.5%", ltv: 0.825 },
        { symbol: "sAMM_BD/LUSD", tvl: "$2M", apr: "9.8%", ltv: 0.825 },
      ],
      vAMM: [
        { symbol: "vAMM_USDC/AERO", tvl: "$62M", apr: "40%", ltv: 0.70 },
        { symbol: "vAMM_USDC/ETH", tvl: "$22.3M", apr: "11.5%", ltv: 0.70 },
        { symbol: "vAMM_wETH/WELL", tvl: "$11.3M", apr: "9.1%", ltv: 0.70 },
        { symbol: "vAMM_VIRTUAL/wETH", tvl: "$8.8M", apr: "28.8%", ltv: 0.70 },
        { symbol: "vAMM_wETH/cbBTC", tvl: "$5M", apr: "4.2%", ltv: 0.70 },
        { symbol: "vAMM_wETH/AERO", tvl: "$5M", apr: "27.9%", ltv: 0.70 },
        { symbol: "vAMM_VIRTUAL/cbBTC", tvl: "$4.4M", apr: "28%", ltv: 0.70 },
      ],
    },
    
    // Redemption protected branches
    redemptionProtected: {
      enabled: true,
      branches: ["sAMM", "vAMM"], // LP token branches are redemption protected
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