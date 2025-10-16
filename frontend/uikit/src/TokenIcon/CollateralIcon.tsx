"use client";

import type { ComponentProps } from "react";
import type { CollateralSymbol } from "../tokens";

import { TokenIcon } from "./TokenIcon";
import { TokenPairIcon } from "./TokenPairIcon";
import { isAmmCollateral, getAmmTokenPair } from "./utils";

export function CollateralIcon({
  symbol,
  size = "medium",
  title,
}: {
  symbol: CollateralSymbol;
  size?: ComponentProps<typeof TokenIcon>["size"];
  title?: string;
}) {
  const ammTokenPair = getAmmTokenPair(symbol);
  
  // If it's an AMM collateral and we have the token pair info, show pair icons
  if (isAmmCollateral(symbol) && ammTokenPair) {
    return (
      <TokenPairIcon
        token1={{
          symbol: ammTokenPair.token1.symbol as any, // Cast since we know these should be valid
          name: ammTokenPair.token1.name,
        }}
        token2={{
          symbol: ammTokenPair.token2.symbol as any,
          name: ammTokenPair.token2.name,
        }}
        size={size}
        title={title}
      />
    );
  }
  
  // Otherwise show single token icon
  return (
    <TokenIcon 
      symbol={symbol} 
      size={size} 
      title={title}
    />
  );
}