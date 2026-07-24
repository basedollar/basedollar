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
          token: "0xb834d1f020de11ddb59bbd50a75419c67f8d43ef",
          collateralRegistry: "0x69ec880c7bdcff731ed7c956670276dc5a48a6cb",
          governance: "0x0000000000000000000000000000000000000000",
          hintHelpers: "0x1b41cf64cdba527278d49ea135cdbc2071133f2e",
          multiTroveGetter: "0xda9ea44f563f02e172c99939964f53b208606310",
          debtInFrontHelper: "0x697dc5e9be3d509820d0a0c7d459210e5c717d4e",
          exchangeHelpers: "0x0000000000000000000000000000000000000000",
          exchangeHelpersV2: "0x0000000000000000000000000000000000000000",
          redemptionHelper: "0xd1acb6ef0decc035089d034496a54dfcadab2eea",
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
            addressesRegistry: "0xe64b58c1a411fa7786f43067444b91c921ab947f",
            borrowerOperations: "0xa297b2576ab4171e31f0a2472cd3029e12f6e9dc",
            troveManager: "0x8d1ed1ebda8a25da3d4bdbf830068d3327f45b96",
            troveNFT: "0xac04d4c39ba59ee14fca47f534d77b9316cc0b14",
            stabilityPool: "0x99c13ea3fd8a3c0864d3598214370b698fd5bea1",
            priceFeed: "0x4b76c7287192f049896c887b2faa3c7d6321d4c8",
            activePool: "0x0e2b89800104c29547115455a280977dde4640f5",
            defaultPool: "0x7381385a3bae7b358357b2586bbdaaf18b11fa18",
            collSurplusPool: "0xd661f911bca496b6a06e9093f027572a12b3fb2f",
            sortedTroves: "0x7eb02f4ca85d0e8555a0b2ad89ddbbf6074aaf6e",
            leverageZapper: "0xcbd99c0b03e8803061855c1390f04ade83cdd85a",
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
            addressesRegistry: "0xba3e382865fc5e68bd70aeccd08578957eee5e89",
            borrowerOperations: "0x04a926166d1d6a01c98fff471757d930e9077a21",
            troveManager: "0x9961f7c49a731f8538d107870c5644ca0cee36e0",
            troveNFT: "0x2d36ce8df1f2ce390f124fb9c375d6decde2aafc",
            stabilityPool: "0x61abac63d00ab235f21b9f4308decbcd4e49a97e",
            priceFeed: "0xf8ad8bd84ef5d0df2794eaaa65f1a02585997b0c",
            activePool: "0x457cbbc8596b10d7d99fa18cb3f013b73eaa6a23",
            defaultPool: "0xa493386ed6fa7d6df565e713906d37437a99d601",
            collSurplusPool: "0x1a47ca055aaf977f5bee8f7c86864cde3922ef62",
            sortedTroves: "0x2d6f527f14d71ac074a4214faa5baf795e39a49f",
            leverageZapper: "0xdcdb208c55924d6aedabc0a4549caffd3d6283cd",
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
            addressesRegistry: "0xaed1fc5d07c8f95288cf4d0e5c99f6205ca7c867",
            borrowerOperations: "0x41d6b5429f62482321fc58665d95fc20e643ed3f",
            troveManager: "0xdd80be56f027a48a1324d6e309209f24bb2dea44",
            troveNFT: "0xe2cf906b84db5adc7687bdf837aeb80c367a9f8c",
            stabilityPool: "0x5bf2882637c00a36c19da52fe1398d7c6f6e6e84",
            priceFeed: "0x64165e7f8af7fcec0710e7e633a6d83239396649",
            activePool: "0x4f535325318bbb4f71da7709d57097bd45fa4f7e",
            defaultPool: "0x96be2b9190ab747d80bc24212374319d3416375e",
            collSurplusPool: "0xd9026f18d6305db6f4b689f4910705e526a8cadd",
            sortedTroves: "0xb4099f7213caa6eb27a4106b7e2169d72b4ae7f3",
            leverageZapper: "0x9284f23467b07ae623a48f7dc89551851631dfa5",
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
            collToken: "0xc23f03d12b9c3571b4f2dde6b000db19b08aa049",
            addressesRegistry: "0x1c034a531b1a6235dc3e749f9f2d0d4d23bb6cf5",
            borrowerOperations: "0x582717466003d523b309e2cdf450c9cd59a8675d",
            troveManager: "0x3fb3431465dcf03f74707ca6f93082d2a6551490",
            troveNFT: "0x57b3b04e9ac28b82add6f4aa801c2bca62cd13a4",
            stabilityPool: "0xb2667fbec60fced42b547bc47acdcd244509808d",
            priceFeed: "0x97f51dd909d9f5e1a7edc23dd54bb0a8a50c1771",
            activePool: "0xa720fc22315fd743f847ef38fc51afdb722fe5f2",
            defaultPool: "0x309266aeed2f4f20769219398a5aed892b67a7e0",
            collSurplusPool: "0x7d335b1229795a830cd004b9552f238df5088d2a",
            sortedTroves: "0xce73c4ad0a48fb799a8fac2040c2aa5f7d8e2654",
            leverageZapper: "0xca20ba8b169724afd7330b8bec4aacba1b6d04d6",
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
            addressesRegistry: "0x39dbbb5c2eb2a37b7f11bdc9fbe1e641606d9b52",
            borrowerOperations: "0xf82b8a1aa55873b3d1addf71d56ccfee0c118b42",
            troveManager: "0xc8fb6477edea65d3e9971196c5510d67f8200a35",
            troveNFT: "0x343d81b4b68ac04c1b13834658e3b81268a7974f",
            stabilityPool: "0xc2f813332dd9291d39c02cc4113bb263f8373396",
            priceFeed: "0xbe9b05c6722211ad41ff0e1fa1b7902e94bab41d",
            activePool: "0xbfba0c04deec373df73c4dc01608b71b9ecc9fa8",
            defaultPool: "0x08b4faec64109b523b991e7607b90d29464a77b9",
            collSurplusPool: "0x3a5b872e6240d60e77312938da02f97731dd5874",
            sortedTroves: "0xa3b2450212eccc6de577f6e780418d313f905643",
            leverageZapper: "0x6465f1e5e132f6fa924b9000e45206ea472fff4d",
          },
        },
      },
      {
        symbol: "AERO" as const,
        name: "AERO",
        icon: "aero",
        collateralRatio: 1.5, // 150% MCR
        maxDeposit: "5000000",
        maxLTV: 0.6667,
        deployments: {
          8453: {
            collToken: "0x940181a94a35a4569e4529a3cdfb74e38fd98631",
            addressesRegistry: "0x0faf9282df48c638be1f59e2ffdbe45b38df5d83",
            borrowerOperations: "0x33f2df184e1a2883cf3675348b546801778d12d6",
            troveManager: "0x12d8ddf234a0d472e895fffc1ade9734c6a0b55d",
            troveNFT: "0x9bf1907e3d88cf471051b3d0c0fa8ab0ec1e6db4",
            stabilityPool: "0x79481b230d30f26e5150a6c7a82022db62a631f1",
            priceFeed: "0xaf5365083c7c44afbfd3f599f9187084afb44ec9",
            activePool: "0x990c8f653d37b5db542531fe77efc373f353ae7b",
            defaultPool: "0x130f79e287e25192f948605a778d659cd515b534",
            collSurplusPool: "0xe78f9092ca1a81c6ee8163abd8a4d8b31619894c",
            sortedTroves: "0xe3119187e8c474f8bec14323baad29f902ea9882",
            leverageZapper: "0x7b07ebe91c22c79bb0db8c1b3e5368f92e09f416",
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
      governorAddress: "0x0e906eecab4506438714db59557d72b8d3a534cd",
    },

    // AeroManager contract - manages AERO rewards from LP collateral
    aeroManager: {
      address: "0xab1778ea04b4532ac8aa80a73eabc0b2d2247180" as `0x${string}`,
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
