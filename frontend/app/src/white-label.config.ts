/**
 * WHITE-LABEL CONFIGURATION
 * 
 * This is the master configuration file for customizing the platform for different clients.
 * When creating a new fork, update all values in this file according to the client's requirements.
 */

export const WHITE_LABEL_CONFIG = {
  // ===========================
  // HEADER CONFIGURATION
  // ===========================
  header: {
    // App name displayed in header
    appName: "LMAO",
    
    // Navigation configuration
    navigation: {
      showBorrow: true,
      showEarn: true,
      showStake: false,
      
      // Navigation menu items
      items: {
        dashboard: {
          label: "Dashboard",
        },
        borrow: {
          label: "Borrow", 
        },
        earn: {
          label: "Earn",
        },
        stake: {
          label: "Stake",
        },
      },
    },
  },

  // ===========================
  // MAIN TOKEN (STABLECOIN)
  // ===========================
  mainToken: {
    name: "LMAO",
    symbol: "LMAO" as const, 
    ticker: "LMAO",
    decimals: 18,
    description: "USD-pegged stablecoin",
  },
};

// Type exports for TypeScript support
export type WhiteLabelConfig = typeof WHITE_LABEL_CONFIG;