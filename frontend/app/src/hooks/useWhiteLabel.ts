import { WHITE_LABEL_CONFIG } from "../../../../white-label.config";
import type { WhiteLabelConfig } from "../../../../white-label.config";

/**
 * Hook to access white-label header configuration
 */
export function useWhiteLabelHeader() {
  return WHITE_LABEL_CONFIG.header;
}

// Type exports
export type { WhiteLabelConfig };
export { WHITE_LABEL_CONFIG };