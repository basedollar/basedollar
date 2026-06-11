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
        84532: { // Base Sepolia
          token: "0x06a350096397728c8158baf5e80841b2aacb6eb1",
          collateralRegistry: "0x05744ab76ef4433ebb7a94a4d15245d71dce1f94",
          governance: "0xf4158Af18b1Fe05d3FC80E136a571de39D98be38",
          hintHelpers: "0x566715f497c00a8aac128c904eecc951e4c61505",
          multiTroveGetter: "0xf140bd519c20a5ec9b9a6b1efbde7ec957a64f6d",
          debtInFrontHelper: "0xa9445aabbb77595f9c7ac12f8145fe2aa4c9606f",
          exchangeHelpers: "0x87bd3597a043077e76017b4f0bf5fb77d1aa5c0d",
          exchangeHelpersV2: "0x377dc66d2638117884dc79bda44cbf1bda40a6df",
          redemptionHelper: "0xc229d7cd95a3185f7dbf573593117516346ee682",
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
        84532: {
          token: "0x0000000000000000000000000000000000000000",
          staking: "0x0000000000000000000000000000000000000000"
        },
      },
    },

    // Collateral tokens (for borrowing) - Multi-chain support
    collaterals: [
      // === Base Sepolia Collaterals ===
      {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
        collateralRatio: 1.1, // 110% MCR
        maxDeposit: "100000000",
        maxLTV: 0.9091,
        deployments: {
          84532: {
            collToken: "0xdec8b447b76afa012a001d2e3df4ebeb12f0b520",
            addressesRegistry: "0xd7dd54fce2158fe456eb3f2c64aa016ab8b3b018",
            borrowerOperations: "0x6682d437fc5ba5449a2cae9bcf04e6959fc14a7d",
            troveManager: "0x6452820e26c3552f87774d077bef9e52bc6b7f15",
            troveNFT: "0xf286a47af017786c89b93065670040852fa258ff",
            stabilityPool: "0x11728c3c1237a70b62124eaef7724b46ec656666",
            priceFeed: "0x537dc7e038cef15ff9cfef049f27468672e43e6d",
            activePool: "0x0abf926e363bb5193ea6fe55cb9138d3df1c53c8",
            defaultPool: "0xe5131925eec092636149c751efde3278f24eb840",
            collSurplusPool: "0xc84a5d63417614d28c003c2475d21c15dad594e0",
            sortedTroves: "0xfcc14bd3cc53260394e7f6d223ce0a0ecbe2c1b8",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
          84532: {
            collToken: "0x31e032cc438b9862a238c758288f89445fc30305",
            addressesRegistry: "0xfd8b4a6c7b6210dbb3d160475ffe6dfa3c83c187",
            borrowerOperations: "0x5b96b57efe0967dfc7fe7da1c8c3b194264a5daa",
            troveManager: "0xb408b0ae4e6db87df14c56622cd35f3c70c46ee3",
            troveNFT: "0x43b60109328788fb317e9a7d3244118ff5779bab",
            stabilityPool: "0xa4e5f177195e442a63549f8524117533c03158c5",
            priceFeed: "0x7582d692bbe3a34c60a111ddf85b723701001b39",
            activePool: "0x0035ff5c9705c77d5bbadddb6bc541b8f1e4b3f8",
            defaultPool: "0x8f17ce399ab143c672eab5d0508d348858fec650",
            collSurplusPool: "0x04e6a0a5d1fc18e617f8256fd748d262352cf736",
            sortedTroves: "0x6e6276de7b6d1905a6921c5db629d107ea30067a",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
          84532: {
            collToken: "0x1dd41ddf10dec4ab11da6fa4a0810a754769cd2d",
            addressesRegistry: "0xad58679c0ce74b50fc84a16617d42b60377820f3",
            borrowerOperations: "0x6f0e844ae66bcbd4ab497af9eecade041fe4d2d9",
            troveManager: "0x662dda19706bb11f6d67f1a254b440afe46a3dba",
            troveNFT: "0xdbe6b5c059ea8c136843f98578ed85ba0299310f",
            stabilityPool: "0xf816938c31680508e9c674bab8f5398959a60aba",
            priceFeed: "0xdc550e6817cca09a1073d24961a805a6e20c28f3",
            activePool: "0x349112c78c0b2508b0d6fc4cd3b8641988f93761",
            defaultPool: "0x188c4b0d41ba2ebbbfb8877f5a197e50e2c8614d",
            collSurplusPool: "0x8bdd206a617f9f3feaf50fdce45090a1d4933d1a",
            sortedTroves: "0x63b77426caaf6b5f8245f95cccdad6ffdb512301",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
          84532: {
            collToken: "0x86db8e58f51e2a4df35fbf65359de76112674002",
            addressesRegistry: "0xda02de6ff5d3779a20370aa142cd665fae51e3a0",
            borrowerOperations: "0x1dc5f1839a9a1bd1373106899b718b74d80c81ce",
            troveManager: "0x41d5e1b59900fcb7c16e1b10ba899d4d4950832d",
            troveNFT: "0x8dbdb3396da081187e39baf860ce5310ed308149",
            stabilityPool: "0xa03c9c4c892c35ac7da877e8e024b65d4db38e15",
            priceFeed: "0xbe582f14fb9538d41c6274fd9f83f9de276cb5ba",
            activePool: "0x275308a6220e73cf3466ba0e31130f69af2a5903",
            defaultPool: "0x1c58f5067d09df74b333001ff721109c827ccbc1",
            collSurplusPool: "0x0951bdbff4a5a045778c287828ada4261d5265a2",
            sortedTroves: "0xa3465a5e29079a4e16495675b08256e0b918dccc",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
          84532: {
            collToken: "0x235ec9e8ade578a101b53018777a4adfd122fbb3",
            addressesRegistry: "0x001f0bf95f8607b62c50384896ddac79e71547ee",
            borrowerOperations: "0x3141b4bc8a61ec5375387f71847ce9f0ceb91979",
            troveManager: "0xef2496bf3e91495dcc5f0bd4ddf2bc8ffa9cc0c5",
            troveNFT: "0x2160716225a0a03f27684eb318d850d2552e0e6d",
            stabilityPool: "0x8d2e7da3fe52f0d4a64068046cb48cccb02854b0",
            priceFeed: "0xeacb78cdbdced8462f1a0d1b8b0769305ee5f1dd",
            activePool: "0x34ca84bda24aeedfca8e181e9cca8651279ec873",
            defaultPool: "0x4be51cd21c5c9d9428bc304b2829aec8e1d2ab57",
            collSurplusPool: "0x8fc8f026d5c07b8c3f25039428ed3c959207b1bf",
            sortedTroves: "0xbfc3a9ca7ffe3b24d5f61186eead59b894ef5257",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
          84532: {
            collToken: "0x1e8428fd593c3c340a3980f204465b1e7d36671d",
            addressesRegistry: "0xc9aa713bb25475c04f595261801e48e301eab327",
            borrowerOperations: "0x57db06d95bb668f011ca746f3e01d943dde8e022",
            troveManager: "0x8078b2ba6852c7cead01b918ac7224ad0f768f11",
            troveNFT: "0xdcecdf8d5f5b3c035c5e5ee1ce20b9176ead2085",
            stabilityPool: "0xc14317847e9a4708400350e4c40354e066878f28",
            priceFeed: "0xa2e2e2967a215af0ec953ca6569d324f6afac080",
            activePool: "0xb109fca3a2c20ac11aac9ff1ea41d1220d780d2b",
            defaultPool: "0xfbd946f72c73e0f39574c0fd51de6d1cb6afacac",
            collSurplusPool: "0xfc3fd6a2e9ef3f095985e0eb8fb7e5e1b4cd3b4e",
            sortedTroves: "0x150c2810f8065e34faef6ef6d8c46c637e48ffd3",
            leverageZapper: "0x0000000000000000000000000000000000000000",
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
      governorAddress: "0xf4158Af18b1Fe05d3FC80E136a571de39D98be38",
    },

    // AeroManager contract - manages AERO rewards from LP collateral
    aeroManager: {
      address: "0x2b3c031b8829f75b1610ecf49b51e9a91cf26580" as `0x${string}`,
      // AERO token address on Base Sepolia
      aeroTokenAddress: "0x1e8428fd593c3c340a3980f204465b1e7d36671d" as `0x${string}`,
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