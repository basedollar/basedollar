"use client";

import type { CollateralSymbol } from "@/src/types";
import type { ReactNode } from "react";

import { useBreakpoint } from "@/src/breakpoints";
import { Amount } from "@/src/comps/Amount/Amount";
import { LinkTextButton } from "@/src/comps/LinkTextButton/LinkTextButton";
import { Positions } from "@/src/comps/Positions/Positions";
import { FORKS_INFO } from "@/src/constants";
import content from "@/src/content";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { DNUM_1 } from "@/src/dnum-utils";
import {
  getBranch,
  getCollToken,
  getToken,
  useAverageInterestRate,
  useBranchDebt,
  useEarnPool,
} from "@/src/liquity-utils";
import { useLpApy, isLpToken } from "@/src/services/LpApy";
import { getAvailableEarnPools } from "@/src/white-label.config";
import { infoTooltipProps } from "@/src/uikit-utils";
import { useAccount } from "@/src/wagmi-utils";
import { css } from "@/styled-system/css";
import { 
  IconBorrow, 
  IconEarn, 
  IconExternal,
  InfoTooltip,
  TokenIcon, 
  CollateralIcon,
  CollateralSectionHeader,
  groupCollaterals
} from "@liquity2/uikit";
import * as dn from "dnum";
import Image from "next/image";
import { useMemo, useState } from "react";
import { HomeTable } from "./HomeTable";
import { YieldSourceTable } from "./YieldSourceTable";

type ForkInfo = (typeof FORKS_INFO)[number];

export function HomeScreen() {
  const account = useAccount();

  const [compact, setCompact] = useState(false);
  useBreakpoint(({ medium }) => {
    setCompact(!medium);
  });

  return (
    <div
      className={css({
        flexGrow: 1,
        display: "flex",
        flexDirection: "column",
        gap: {
          base: 40,
          medium: 40,
          large: 64,
        },
        width: "100%",
      })}
    >
      <Positions address={account.address ?? null} />
      <div
        className={css({
          display: "grid",
          gap: 24,
          gridTemplateColumns: {
            base: "1fr",
            large: "1fr 1fr",
          },
          gridTemplateAreas: {
            base: `
              "borrow"
              "earn"
              "yield"
            `,
            large: `
              "borrow earn"
              "borrow yield"
            `,
          },
        })}
      >
        <BorrowTable compact={compact} />
        <EarnTable compact={compact} />
        <YieldSourceTable compact={compact} />
      </div>
    </div>
  );
}

function BorrowTable({
  compact,
}: {
  compact: boolean;
}) {
  const columns: ReactNode[] = [
    "Collateral",
    <span
      key="avg-interest-rate"
      title="Average interest rate, per annum"
    >
      {compact ? "Rate" : "Avg rate, p.a."}
    </span>,
    <span
      key="max-ltv"
      title="Maximum Loan-to-Value ratio"
    >
      Max LTV
    </span>,
    <span
      key="lp-apy"
      title="Liquidity Provider Annual Percentage Yield (for LP tokens)"
    >
      LP APY
    </span>,
    <span
      key="total-debt"
      title="Total debt"
    >
      {compact ? "Debt" : "Total debt"}
    </span>,
  ];

  if (!compact) {
    columns.push(null);
  }

  const groupedCollaterals = useMemo(() => groupCollaterals(), []);

  return (
    <div className={css({ gridArea: "borrow" })}>
      <HomeTable
        title={`Borrow ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} against ETH and assets`}
        subtitle="You can adjust your loans, including your interest rate, at any time"
        icon={<IconBorrow />}
        columns={columns}
        rows={groupedCollaterals.flatMap((group, groupIndex) => [
          <CollateralSectionHeader
            key={`section-${group.title}`}
            title={group.title}
            isFirst={groupIndex === 0}
            colSpan={compact ? 5 : 6}
          />,
          ...group.collaterals.map(({ symbol }) => (
            <BorrowingRow key={symbol} compact={compact} symbol={symbol} />
          ))
        ])}
      />
    </div>
  );
}

function EarnTable({
  compact,
}: {
  compact: boolean;
}) {
  const columns: ReactNode[] = [
    "Pool",
    <abbr
      key="apr1d"
      title="Annual Percentage Rate over the last 24 hours"
    >
      APR
    </abbr>,
    <abbr
      key="apr7d"
      title="Annual Percentage Rate over the last 7 days"
    >
      7d APR
    </abbr>,
    "Pool size",
  ];

  if (!compact) {
    columns.push(null);
  }

  const earnGroupedCollaterals = useMemo(() => {
    const earnPools = getAvailableEarnPools().filter(pool => pool.type !== 'staked');
    const earnCollaterals = earnPools.map(pool => pool.symbol.toUpperCase() as CollateralSymbol);
    
    // Group only the earn collaterals
    const allGroups = groupCollaterals();
    return allGroups.map(group => ({
      ...group,
      collaterals: group.collaterals.filter(c => earnCollaterals.includes(c.symbol))
    })).filter(group => group.collaterals.length > 0);
  }, []);

  return (
    <div
      className={css({
        gridArea: "earn",
      })}
    >
      <div
        className={css({
          position: "relative",
          zIndex: 2,
        })}
      >
        <HomeTable
          title={content.home.earnTable.title}
          subtitle={content.home.earnTable.subtitle}
          icon={<IconEarn />}
          columns={columns}
          rows={earnGroupedCollaterals.flatMap((group, groupIndex) => [
            <CollateralSectionHeader 
              key={`earn-section-${group.title}`} 
              title={group.title} 
              isFirst={groupIndex === 0}
              colSpan={compact ? 4 : 5}
            />,
            ...group.collaterals.map(({ symbol }) => (
              <EarnRewardsRow
                key={symbol}
                symbol={symbol}
              />
            ))
          ])}
        />
      </div>
      <div
        className={css({
          position: "relative",
          zIndex: 1,
        })}
      >
        <ForksInfoDrawer />
      </div>
    </div>
  );
}

function ForksInfoDrawer() {
  const pickedForkIcons = useMemo(() => pickRandomForks(2), []);
  return (
    <div
      className={css({
        width: "100%",
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        gap: 16,
        marginTop: -20,
        height: 44 + 20,
        padding: "20px 16px 0",
        whiteSpace: "nowrap",
        background: "#F7F7FF",
        borderRadius: 8,
        userSelect: "none",
      })}
    >
      <div
        className={css({
          display: "flex",
          gap: 12,
        })}
      >
        <div
          className={css({
            flexShrink: 0,
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            gap: 0,
          })}
        >
          {pickedForkIcons.map(([name, icon], index) => (
            <div
              key={name}
              className={css({
                display: "grid",
                placeItems: "center",
                background: "white",
                borderRadius: "50%",
                width: 18,
                height: 18,
              })}
              style={{
                marginLeft: index > 0 ? -4 : 0,
              }}
            >
              <Image
                loading="eager"
                unoptimized
                alt={name}
                title={name}
                height={18}
                src={icon}
                width={18}
              />
            </div>
          ))}
        </div>
        <div
          className={css({
            display: "grid",
            fontSize: 14,
          })}
        >
          <span
            title={content.home.earnTable.forksInfo.titleAttr}
            className={css({
              overflow: "hidden",
              textOverflow: "ellipsis",
            })}
          >
            {content.home.earnTable.forksInfo.text}
          </span>
        </div>
      </div>
      <div
        className={css({
          display: "flex",
          alignItems: "center",
        })}
      >
        <LinkTextButton
          external
          href={content.home.earnTable.forksInfo.learnMore.url}
          label={content.home.earnTable.forksInfo.learnMore.label}
          title={content.home.earnTable.forksInfo.learnMore.title}
          className={css({
            fontSize: 14,
          })}
        >
          Learn more
        </LinkTextButton>
      </div>
    </div>
  );
}

function BorrowingRow({
  compact,
  symbol,
}: {
  compact: boolean;
  symbol: CollateralSymbol;
}) {
  const branch = getBranch(symbol);
  const collateral = getCollToken(branch.id);
  const avgInterestRate = useAverageInterestRate(branch.id);
  const branchDebt = useBranchDebt(branch.id);

  const maxLtv = collateral?.collateralRatio && dn.gt(collateral.collateralRatio, 0)
    ? dn.div(DNUM_1, collateral.collateralRatio)
    : null;

  // Find the collateral config to check for aerodrome pool link
  const collateralConfig = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  const aerodromePoolLink = collateralConfig?.poolData?.aerodromePoolLink;

  // LP APY for LP token collaterals
  const isLp = isLpToken(symbol);
  const lpApy = useLpApy(isLp ? symbol : null);

  return (
    <tr>
      <td>
        <div
          className={css({
            display: "flex",
            alignItems: "center",
            gap: 8,
          })}
        >
          <CollateralIcon symbol={symbol} size="mini" />
          <div className={css({ display: "flex", alignItems: "center", gap: 4 })}>
            <span>{collateral?.name}</span>
            {aerodromePoolLink && (
              <a
                href={aerodromePoolLink}
                target="_blank"
                rel="noopener noreferrer"
                className={css({
                  display: "flex",
                  alignItems: "center",
                  color: "contentAlt",
                  _hover: { color: "content" },
                })}
              >
                <IconExternal size={12} />
              </a>
            )}
          </div>
        </div>
      </td>
      <td>
        <Amount
          fallback="…"
          percentage
          value={avgInterestRate.data}
        />
      </td>
      <td>
        <Amount
          value={maxLtv}
          percentage
        />
      </td>
      <td>
        {isLp ? (
          <span
            className={css({
              color: lpApy.data ? "positiveAlt" : "contentAlt",
            })}
          >
            {lpApy.data
              ? `${lpApy.data.apy.toFixed(2)}%`
              : "…"}
          </span>
        ) : (
          <span className={css({ color: "contentAlt" })}>…</span>
        )}
      </td>
      <td>
        <Amount
          format="compact"
          prefix="$"
          fallback="…"
          value={branchDebt.data}
        />
      </td>
      {!compact && (
        <td>
          <div
            className={css({
              display: "flex",
              gap: 16,
              justifyContent: "flex-end",
            })}
          >
            <LinkTextButton
              href={`/borrow/${symbol.toLowerCase()}`}
              label={
                <div
                  className={css({
                    display: "flex",
                    alignItems: "center",
                    gap: 4,
                    fontSize: 14,
                  })}
                >
                  Borrow
                  <TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} size="mini" />
                </div>
              }
              title={`Borrow ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} from ${symbol}`}
            />
          </div>
        </td>
      )}
    </tr>
  );
}

function EarnRewardsRow({
  symbol,
}: {
  symbol: CollateralSymbol;
}) {
  const branch = getBranch(symbol);
  const token = getToken(symbol);
  const earnPool = useEarnPool(branch?.id ?? null);
  
  // Find the collateral config to check for aerodrome pool link and token type
  const collateralConfig = WHITE_LABEL_CONFIG.tokens.collaterals.find(c => c.symbol === symbol);
  const aerodromePoolLink = collateralConfig?.poolData?.aerodromePoolLink;
  const isLPToken = collateralConfig?.type === "samm" || collateralConfig?.type === "vamm";
  
  return (
    <tr>
      <td>
        <div
          className={css({
            display: "flex",
            alignItems: "center",
            gap: 8,
          })}
        >
          <CollateralIcon symbol={symbol} size="mini" />
          <div className={css({ display: "flex", alignItems: "center", gap: 4 })}>
            <span>{token?.name}</span>
            {aerodromePoolLink && (
              <a
                href={aerodromePoolLink}
                target="_blank"
                rel="noopener noreferrer"
                className={css({
                  display: "flex",
                  alignItems: "center",
                  color: "contentAlt",
                  _hover: { color: "content" },
                })}
              >
                <IconExternal size={12} />
              </a>
            )}
          </div>
        </div>
      </td>
      <td>
        <Amount
          fallback="…"
          percentage
          value={earnPool.data?.apr}
        />
      </td>
      <td>
        <Amount
          fallback="…"
          percentage
          value={earnPool.data?.apr7d}
        />
      </td>
      <td>
        <Amount
          fallback="…"
          format="compact"
          prefix="$"
          value={earnPool.data?.totalDeposited}
        />
      </td>
        <td>
          <LinkTextButton
            href={isLPToken ? `/earn/fsbased` : `/earn/${symbol.toLowerCase()}`}
            label={
              <div
                className={css({
                  display: "flex",
                  alignItems: "center",
                  gap: 4,
                  fontSize: 14,
                })}
              >
                Earn
                {isLPToken ? (
                  <div className={css({ display: "flex", alignItems: "center", gap: 2 })}>
                    <TokenIcon.Group size="mini">
                      <TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} />
                      <TokenIcon symbol="AERO" />
                    </TokenIcon.Group>
                    <div
                      className={css({ 
                        width: 16,
                        height: 16,
                        borderRadius: "50%",
                        backgroundColor: "white",
                        border: "1px solid token(colors.border)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        fontSize: 8,
                        color: "contentAlt",
                        cursor: "help",
                        position: "relative",
                        marginLeft: "-6px",
                        zIndex: 1
                      })}
                    >
                      <span>•••</span>
                      <div
                        className={css({
                          position: "absolute",
                          left: 0,
                          top: 0,
                          width: "100%",
                          height: "100%",
                          opacity: 0
                        })}
                      >
                        <InfoTooltip
                          {...infoTooltipProps(content.generalInfotooltips.mixedLiquidationRewards)}
                        />
                      </div>
                    </div>
                  </div>
                ) : (
                  <TokenIcon.Group size="mini">
                    <TokenIcon symbol={WHITE_LABEL_CONFIG.tokens.mainToken.symbol} />
                    <TokenIcon symbol={symbol} />
                  </TokenIcon.Group>
                )}
              </div>
            }
            title={isLPToken 
              ? `Deposit ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} to earn AERO + mixed LP liquidation rewards`
              : `Earn ${WHITE_LABEL_CONFIG.tokens.mainToken.symbol} with ${token?.name}`}
          />
        </td>
    </tr>
  );
}

function pickRandomForks(count: number): ForkInfo[] {
  const forks = [...FORKS_INFO];
  if (forks.length < count) {
    return forks;
  }
  const picked: ForkInfo[] = [];
  for (let i = 0; i < count; i++) {
    const [info] = forks.splice(
      Math.floor(Math.random() * forks.length),
      1,
    );
    if (info) picked.push(info);
  }
  return picked;
}
