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
    appName: "BOLD",
    
    logo: {
      // Main logo (icon + text)
      main: "/brand/logo-main.svg",
      // Icon only (for mobile or compact views)  
      icon: "/brand/logo-icon.svg",
      // Alt text for accessibility
      alt: "BOLD Logo",
    },
    
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
};

// Type exports for TypeScript support
export type WhiteLabelConfig = typeof WHITE_LABEL_CONFIG;