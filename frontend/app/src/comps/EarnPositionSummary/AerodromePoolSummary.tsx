"use client";

import { Amount } from "@/src/comps/Amount/Amount";
import { useBaseDollarYieldSources } from "@/src/liquity-utils";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { css } from "@/styled-system/css";
import { InfoTooltip, TokenIcon } from "@liquity2/uikit";
import { EarnPositionSummaryBase } from "./EarnPositionSummaryBase";

const AERODROME_POOL_URL = "https://aerodrome.finance/deposit?token0=0x252d36f435582ecb01686448d21e8c9ea0b2ca65&token1=0x833589fcd6edb6e08f4c7c32d4f71b54bda02913&type=0&chain0=8453&chain1=8453&factory=0x420DD381b31aEf6683db6B902084cB0FFECe40Da";

export function AerodromePoolSummary() {
  const yieldSources = useBaseDollarYieldSources();
  const pool = yieldSources.data?.[0];

  return (
    <EarnPositionSummaryBase
      action={{
        label: "Deposit to the Aerodrome BD/USDC pool",
        path: pool?.link ?? AERODROME_POOL_URL,
        external: true,
      }}
      active={false}
      icon={
        <div
          className={css({
            position: "relative",
            width: 34,
            height: 34,
          })}
        >
          <TokenIcon symbol="AERO" size={34} />
          <div
            className={css({
              position: "absolute",
              right: -8,
              bottom: -5,
              padding: 2,
              background: "infoSurface",
              borderRadius: 999,
            })}
          >
            <TokenIcon.Group size="mini">
              <TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} />
              <TokenIcon symbol="USDC" />
            </TokenIcon.Group>
          </div>
        </div>
      }
      poolToken={WHITE_LABEL_CONFIG.tokens.mainToken.symbol}
      title="Aerodrome BD/USDC Pool"
      poolInfo={
        <div
          className={css({
            display: "flex",
            gap: 6,
          })}
        >
          <div
            className={css({
              color: "contentAlt2",
            })}
          >
            APR
          </div>
          <Amount
            fallback="-%"
            format="1z"
            percentage
            value={pool?.apr}
          />
          <InfoTooltip
            content={{
              heading: "Current APR",
              body: "The annualized percentage rate earned by the Aerodrome BD/USDC pool.",
            }}
          />
        </div>
      }
      subtitle={
        <>
          <div>TVL</div>
          <Amount
            fallback="-"
            format="compact"
            prefix="$"
            value={pool?.tvl}
          />
          <InfoTooltip heading="Total Value Locked (TVL)">
            Total value deposited in the Aerodrome BD/USDC pool.
          </InfoTooltip>
        </>
      }
    />
  );
}
