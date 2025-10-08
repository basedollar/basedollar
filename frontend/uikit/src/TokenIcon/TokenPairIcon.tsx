"use client";

import type { ComponentProps } from "react";
import type { TokenSymbol } from "../tokens";

import { TokenIcon } from "./TokenIcon";

export function TokenPairIcon({
  token1,
  token2,
  size = "medium",
  title,
}: {
  token1: { symbol: TokenSymbol; name?: string };
  token2: { symbol: TokenSymbol; name?: string };
  size?: ComponentProps<typeof TokenIcon>["size"];
  title?: string;
}) {
  const pairTitle = title ?? `${token1.name || token1.symbol}/${token2.name || token2.symbol}`;

  return (
    <TokenIcon.Group size={size}>
      <TokenIcon
        symbol={token1.symbol}
        title={pairTitle}
      />
      <TokenIcon
        symbol={token2.symbol}
        title={pairTitle}
      />
    </TokenIcon.Group>
  );
}