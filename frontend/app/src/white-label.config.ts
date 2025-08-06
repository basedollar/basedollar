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
    appName: "NEW NAME",
    
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
  // MAIN TOKEN (STABLECOIN)
  // ===========================
  mainToken: {
    name: "LOL",
    symbol: "LOL" as const, 
    ticker: "LOL",
    decimals: 18,
    description: "USD-pegged stablecoin",
  },
};

// Type exports for TypeScript support
export type WhiteLabelConfig = typeof WHITE_LABEL_CONFIG;