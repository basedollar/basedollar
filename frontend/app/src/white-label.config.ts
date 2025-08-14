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
      name: "LOL",
      symbol: "LOL" as const, 
      ticker: "LOL",
      decimals: 18,
      description: "USD-pegged stablecoin",
      icon: "main-token",
      // Core protocol contracts
      deployments: {
        1: { // Mainnet
          token: "0xb01dd87b29d187f3e3a4bf6cdaebfb97f3d9ab98",
          collateralRegistry: "0xd99de73b95236f69a559117ecd6f519af780f3f7",
          governance: "0x636deb767cd7d0f15ca4ab8ea9a9b26e98b426ac",
          hintHelpers: "0xbbdbf5e15e81e5a3e8f973d4551d20e87e60b53a",
          multiTroveGetter: "0xedf6eb3fa7ae48ddb0c0d97bd526b0738c6dd860",
          exchangeHelpers: "0xbc47901f4d2a20b96d61e8198a2e88a8c4b9dda6",
        },
        11155111: { // Sepolia
          token: "0xb01d32c05f4aa066eef2bfd4d461833fddd56d0a",
          collateralRegistry: "0x55cefb9c04724ba3c67d92df5e386c6f1585a83b",
          governance: "0xe3f9ca5398cc3d0099c3ad37d3252e37431555b8",
          hintHelpers: "0xc3adf59a37ce2332bb0e21093a56e5b4e8c91f7a",
          multiTroveGetter: "0x907a56ebb7798f8c2771ad15be3ffd32c3cf4ae9",
          exchangeHelpers: "0x814b5e9dac30f2df8794bbef8a10e8a6e1ca3c03",
        },
      },
    },

    // Governance token
    governanceToken: {
      name: "LQTY",
      symbol: "LQTY" as const,
      ticker: "LQTY",
      icon: "lqty",
      // Contract addresses per chain
      deployments: {
        1: { // Mainnet
          token: "0x6dea81c8171d0ba574754ef6f8b412f2ed88c54d",
          staking: "0x4f9fbb3f1e99b56e0fe2892e623ed36a76fc605d",
        },
        11155111: { // Sepolia
          token: "0x3b7f247f68ff5b18fcd4a87c7e669b46dd1ad4a5",
          staking: "0x9f80c885f8d9e8b3e9ca3e1c9e1c6e3e3e3e3e3e", // Example address
        },
      },
    },

    // Collateral tokens (for borrowing)
    collaterals: [
      {
        symbol: "ETH" as const,
        name: "ETH",
        icon: "eth",
        collateralRatio: 1.1,
        // Protocol limits
        maxDeposit: "100000000", // 100M ETH
        maxLTV: 0.916, // 91.6% max LTV
        // Deployment info (per chain)
        deployments: {
          // Mainnet
          1: {
            collToken: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
            leverageZapper: "0x978d7188ae01881d254ad7e94874653b0c268004",
            stabilityPool: "0xf69eb8c0d95d4094c16686769460f678727393cf",
            troveManager: "0x81d78814df42da2cab0e8870c477bc3ed861de66",
          },
          // Sepolia
          11155111: {
            collToken: "0x8116d0a0e8d4f0197b428c520953f302adca0b50",
            leverageZapper: "0x482bf4d6a2e61d259a7f97ef6aac8b3ce5dd9f99",
            stabilityPool: "0x89fb98c98792c8b9e9d468148c6593fa0fc47b40",
            troveManager: "0x364038750236739e0cd96d5754516c9b8168fb0c",
          },
        },
      },
      {
        symbol: "RETH" as const,
        name: "rETH", 
        icon: "reth",
        collateralRatio: 1.2,
        maxDeposit: "100000000",
        maxLTV: 0.916,
        deployments: {
          1: {
            collToken: "0xae78736cd615f374d3085123a210448e74fc6393",
            leverageZapper: "0x7d5f19a1e48479a95c4eb40fd1a534585026e7e5",
            stabilityPool: "0xc4463b26be1a6064000558a84ef9b6a58abe4f7a",
            troveManager: "0xde026433882a9dded65cac4fff8402fafff40fca",
          },
          11155111: {
            collToken: "0xbdb72f78302e6174e48aa5872f0dd986ed6d98d9",
            leverageZapper: "0x251dfe2078a910c644289f2344fac96bffea7c02",
            stabilityPool: "0x8492ad1df9f89e4b6c54c81149058172592e1c94",
            troveManager: "0x310fa1d1d711c75da45952029861bcf0d330aa81",
          },
        },
      },
      {
        symbol: "WSTETH" as const,
        name: "wstETH",
        icon: "wsteth",
        collateralRatio: 1.2,
        maxDeposit: "100000000",
        maxLTV: 0.916,
        deployments: {
          1: {
            collToken: "0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
            leverageZapper: "0xc3d864adc2a9b49d52e640b697241408d896179f",
            stabilityPool: "0xcf46dab575c364a8b91bda147720ff4361f4627f",
            troveManager: "0xb47ef60132deabc89580fd40e49c062d93070046",
          },
          11155111: {
            collToken: "0xff9f477b09c6937ff6313ae90e79022609851a9c",
            leverageZapper: "0xea7fb1919bf9bae007df10ad8b748ee75fd5971d",
            stabilityPool: "0x68320bd4bbc16fe14f91501380edaa9ffe5890e1",
            troveManager: "0xa7b57913b5643025a15c80ca3a56eb6fb59d095d",
          },
        },
      },
    ],

    // Other tokens in the protocol
    otherTokens: {
      // Legacy Liquity USD token
      lusd: {
        symbol: "LUSD" as const,
        name: "LUSD",
        icon: "lusd",
      },
      // Staked version of main token
      staked: {
        symbol: "SBOLD" as const,
        name: "sLOL", // s + mainToken symbol
        icon: "sbold",
      },
    },
  },

  // ===========================
  // BRANDING & CONTENT
  // ===========================
  branding: {
    // Core app identity
    appName: "NEW NAME V2",        // Full app name for titles, about pages
    brandName: "New Name",         // Core brand name for protocol/version references
    appTagline: "Next-gen borrowing protocol",
    appDescription: "A new borrowing protocol that lets users deposit ETH or LSTs as collateral",
    appUrl: "https://www.newname.org/",
    
    // External links
    links: {
      docs: {
        base: "https://docs.liquity.org/v2-faq/",
        redemptions: "https://docs.liquity.org/v2-faq/redemptions-and-delegation",
        liquidations: "https://docs.liquity.org/v2-faq/liquidations",
        delegation: "https://docs.liquity.org/v2-faq/batch-managers-and-delegation",
        interestRates: "https://docs.liquity.org/v2-faq/interest-rates",
        earn: "https://docs.liquity.org/v2-faq/bold-and-earn",
        staking: "https://docs.liquity.org/v2-faq/lqty-staking",
      },
      dune: "https://dune.com/liquity/liquity-v2",
      discord: "https://discord.gg/liquity",
      github: "https://github.com/liquity/liquity-v2",
      x: "https://x.com/liquityprotocol",
      friendlyForkProgram: "https://www.liquity.org/friendly-fork-program",
    },
    
    // Feature flags and descriptions
    features: {
      showV1Legacy: true, // Show legacy V1 related content
      friendlyFork: {
        enabled: true,
        title: "Learn more about the Friendly Fork Program",
        description: "A program for collaborative protocol development",
      },
      staking: {
        enabled: true,
        title: "Direct protocol incentives", 
        description: "Direct protocol incentives with governance token while earning from V1",
        showV1Earnings: true,
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
      stake: "Stake",
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
    // Enable/disable the staked main token pool (sSBOLD/etc)
    enableStakedMainToken: true,
    
    // Enable/disable stability pools for collaterals
    enableStabilityPools: true,
    
    // Custom pools configuration (beyond collateral stability pools)
    customPools: [] as Array<{
      symbol: string;
      name: string;
      enabled: boolean;
    }>,
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
  
  // Add staked main token pool
  if (WHITE_LABEL_CONFIG.earnPools.enableStakedMainToken) {
    pools.push({
      symbol: WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol.toLowerCase(),
      name: `${WHITE_LABEL_CONFIG.tokens.otherTokens.staked.name} Pool`,
      type: 'staked',
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