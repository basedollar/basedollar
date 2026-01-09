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
      name: "BaseD",
      symbol: "BaseD" as const, 
      ticker: "BaseD",
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
        icon: "superoethb",
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
      {
        symbol: "SAMM_WETH_MSETH" as const,
        name: "wETH/msETH",
        icon: "samm-lp",
        collateralRatio: 1.212, // 82.5% LTV
        maxDeposit: "18500000", // $18.5M TVL
        maxLTV: 0.825,
        type: "samm" as const,
        token1: { 
          symbol: "wETH", 
          name: "wETH",
          address: "0x4200000000000000000000000000000000000006"
        },
        token2: { 
          symbol: "msETH", 
          name: "msETH",
          address: "0x7Ba6F01772924a82D9626c126347A28299E98c98"
        },
        poolData: { 
          tvl: "$18.5M", 
          apr: "10.64%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x4200000000000000000000000000000000000006&chain0=8453&token1=0x7Ba6F01772924a82D9626c126347A28299E98c98&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - Aerodrome LP token address (the pair itself)
            leverageZapper: "0x0000000000000000000000000000000000000000", // TBD
            stabilityPool: "0x0000000000000000000000000000000000000000", // TBD
            troveManager: "0x0000000000000000000000000000000000000000", // TBD
          },
        },
      },
      {
        symbol: "SAMM_MSUSD_USDC" as const,
        name: "msUSD/USDC",
        icon: "samm-lp",
        collateralRatio: 1.212,
        maxDeposit: "10000000",
        maxLTV: 0.825,
        type: "samm" as const,
        token1: { 
          symbol: "msUSD", 
          name: "msUSD",
          address: "0x526728dbc96689597f85ae4cd716d4f7fccbae9d"
        },
        token2: { 
          symbol: "USDC", 
          name: "USDC",
          address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        },
        poolData: { 
          tvl: "$10M", 
          apr: "12.71%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x526728dbc96689597f85ae4cd716d4f7fccbae9d&chain0=8453&token1=0x833589fcd6edb6e08f4c7c32d4f71b54bda02913&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "SAMM_BD_USDC" as const,
        name: "BaseD/USDC",
        icon: "samm-lp",
        collateralRatio: 1.212,
        maxDeposit: "4000000",
        maxLTV: 0.825,
        type: "samm" as const,
        token1: { 
          symbol: "BaseD", 
          name: "BaseD",
          address: "0x0000000000000000000000000000000000000000" // TBD - Your token
        },
        token2: { 
          symbol: "USDC", 
          name: "USDC",
          address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        },
        poolData: { 
          tvl: "$4M", 
          apr: "8.5%",
          // aerodromePoolLink: "https://aerodrome.finance/pools?token0=TBD&chain0=8453&token1=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913&chain1=8453" // TODO: Enable when BaseD token is deployed
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "SAMM_BD_LUSD" as const,
        name: "BaseD/LUSD",
        icon: "samm-lp",
        collateralRatio: 1.212,
        maxDeposit: "2000000",
        maxLTV: 0.825,
        type: "samm" as const,
        token1: { 
          symbol: "BaseD", 
          name: "BaseD",
          address: "0x0000000000000000000000000000000000000000" // TBD - Your token
        },
        token2: { 
          symbol: "LUSD", 
          name: "LUSD",
          address: "0x368181499736d0c0cc614dbb145e2ec1ac86b8c6"
        },
        poolData: { 
          tvl: "$2M", 
          apr: "9.8%",
          // aerodromePoolLink: "https://aerodrome.finance/pools?token0=TBD&chain0=8453&token1=0x368181499736d0c0cc614dbb145e2ec1ac86b8c6&chain1=8453" // TODO: Enable when BaseD token is deployed
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      
      // === vAMM LP Tokens (70% LTV) ===
      {
        symbol: "VAMM_USDC_AERO" as const,
        name: "USDC/AERO",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "62000000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "USDC", 
          name: "USDC",
          address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        },
        token2: { 
          symbol: "AERO", 
          name: "AERO",
          address: "0x940181a94A35A4569E4529a3CDfB74e38FD98631"
        },
        poolData: { 
          tvl: "$62M", 
          apr: "40%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913&chain0=8453&token1=0x940181a94A35A4569E4529a3CDfB74e38FD98631&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_USDC_ETH" as const,
        name: "USDC/ETH",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "22300000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "USDC", 
          name: "USDC",
          address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        },
        token2: { 
          symbol: "ETH", 
          name: "ETH",
          address: "0x4200000000000000000000000000000000000006" // WETH
        },
        poolData: { 
          tvl: "$22.3M", 
          apr: "11.5%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913&chain0=8453&token1=0x4200000000000000000000000000000000000006&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_WETH_WELL" as const,
        name: "wETH/WELL",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "11300000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "wETH", 
          name: "wETH",
          address: "0x4200000000000000000000000000000000000006"
        },
        token2: { 
          symbol: "WELL", 
          name: "WELL",
          address: "0xA88594D404727625A9437C3f886C7643872296AE"
        },
        poolData: { 
          tvl: "$11.3M", 
          apr: "9.1%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x4200000000000000000000000000000000000006&chain0=8453&token1=0xA88594D404727625A9437C3f886C7643872296AE&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_VIRTUAL_WETH" as const,
        name: "VIRTUAL/wETH",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "8800000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "VIRTUAL", 
          name: "VIRTUAL",
          address: "0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b"
        },
        token2: { 
          symbol: "wETH", 
          name: "wETH",
          address: "0x4200000000000000000000000000000000000006"
        },
        poolData: { 
          tvl: "$8.8M", 
          apr: "28.8%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b&chain0=8453&token1=0x4200000000000000000000000000000000000006&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_WETH_CBBTC" as const,
        name: "wETH/cbBTC",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "5000000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "wETH", 
          name: "wETH",
          address: "0x4200000000000000000000000000000000000006"
        },
        token2: { 
          symbol: "cbBTC", 
          name: "cbBTC",
          address: "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf"
        },
        poolData: { 
          tvl: "$5M", 
          apr: "4.2%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x4200000000000000000000000000000000000006&chain0=8453&token1=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_WETH_AERO" as const,
        name: "wETH/AERO",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "5000000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "wETH", 
          name: "wETH",
          address: "0x4200000000000000000000000000000000000006"
        },
        token2: { 
          symbol: "AERO", 
          name: "AERO",
          address: "0x940181a94A35A4569E4529a3CDfB74e38FD98631"
        },
        poolData: { 
          tvl: "$5M", 
          apr: "27.9%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x4200000000000000000000000000000000000006&chain0=8453&token1=0x940181a94A35A4569E4529a3CDfB74e38FD98631&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
          },
        },
      },
      {
        symbol: "VAMM_VIRTUAL_CBBTC" as const,
        name: "VIRTUAL/cbBTC",
        icon: "vamm-lp",
        collateralRatio: 1.429,
        maxDeposit: "4400000",
        maxLTV: 0.70,
        type: "vamm" as const,
        token1: { 
          symbol: "VIRTUAL", 
          name: "VIRTUAL",
          address: "0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b"
        },
        token2: { 
          symbol: "cbBTC", 
          name: "cbBTC",
          address: "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf"
        },
        poolData: { 
          tvl: "$4.4M", 
          apr: "28%",
          aerodromePoolLink: "https://aerodrome.finance/pools?token0=0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b&chain0=8453&token1=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf&chain1=8453"
        },
        deployments: {
          8453: {
            collToken: "0x0000000000000000000000000000000000000000", // TBD - LP token (get this from Aerodrome after pool is created)
            leverageZapper: "0x0000000000000000000000000000000000000000",
            stabilityPool: "0x0000000000000000000000000000000000000000",
            troveManager: "0x0000000000000000000000000000000000000000",
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
      // Dummy governor address for now (will be Aragon DAO later)
      governorAddress: "0x0000000000000000000000000000000000000000",
    },

    // AeroManager contract - manages AERO rewards from LP collateral
    aeroManager: {
      address: "0x0000000000000000000000000000000000000000" as `0x${string}`, // TBD - deployed AeroManager address
      // AERO token address on Base
      aeroTokenAddress: "0x940181a94A35A4569E4529a3CDfB74e38FD98631" as `0x${string}`,
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