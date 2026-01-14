"use client";

import { Amount } from "@/src/comps/Amount/Amount";
import { Screen } from "@/src/comps/Screen/Screen";
import { LinkTextButton } from "@/src/comps/LinkTextButton/LinkTextButton";
import { dnum18 } from "@/src/dnum-utils";
import { WHITE_LABEL_CONFIG } from "@/src/white-label.config";
import { css } from "@/styled-system/css";
import { Button, TokenIcon, shortenAddress } from "@liquity2/uikit";
import { a, useSpring } from "@react-spring/web";
import { useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { erc20Abi, type Address } from "viem";
import Image from "next/image";
import Link from "next/link";
import { useState, useMemo } from "react";

// AeroManager ABI - read and write functions
const AeroManagerAbi = [
  {
    inputs: [],
    name: "collateralRegistry",
    outputs: [{ internalType: "contract ICollateralRegistry", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "aeroTokenAddress",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "governor",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "treasuryAddress",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "claimedAero",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "gauge", type: "address" }],
    name: "stakedAmounts",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "gauge", type: "address" }],
    name: "claim",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

// AeroGauge ABI - for checking claimable rewards
const AeroGaugeAbi = [
  {
    inputs: [{ internalType: "address", name: "_account", type: "address" }],
    name: "earned",
    outputs: [{ internalType: "uint256", name: "_earned", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

const AERO_MANAGER_ADDRESS = WHITE_LABEL_CONFIG.basedollarFeatures.aeroManager.address;
const AERO_TOKEN_ADDRESS = WHITE_LABEL_CONFIG.basedollarFeatures.aeroManager.aeroTokenAddress;

// Get LP collaterals with gauge addresses from config
type LpCollateral = {
  symbol: string;
  name: string;
  type: string;
  gauge: Address;
};

function getLpCollateralsWithGauges(): LpCollateral[] {
  const collaterals = WHITE_LABEL_CONFIG.tokens.collaterals;
  const lpCollaterals: LpCollateral[] = [];

  for (const collateral of collaterals) {
    // Check if it's an LP type (samm or vamm)
    if ('type' in collateral && (collateral.type === 'samm' || collateral.type === 'vamm')) {
      const deployments = collateral.deployments as Record<number, { gauge?: string }>;
      const deployment = deployments[8453]; // Base mainnet
      if (deployment?.gauge && deployment.gauge !== "0x0000000000000000000000000000000000000000") {
        lpCollaterals.push({
          symbol: collateral.symbol,
          name: collateral.name,
          type: collateral.type.toUpperCase(),
          gauge: deployment.gauge as Address,
        });
      }
    }
  }

  return lpCollaterals;
}

export function AeroManagerScreen() {
  const [claimingGaugeIndex, setClaimingGaugeIndex] = useState<number | null>(null);
  const [isClaimingAll, setIsClaimingAll] = useState(false);

  const lpCollaterals = useMemo(() => getLpCollateralsWithGauges(), []);
  const hasGauges = lpCollaterals.length > 0;

  // Read AeroManager contract state
  const contractReads = useReadContracts({
    contracts: [
      {
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "governor",
      },
      {
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "aeroTokenAddress",
      },
      {
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "collateralRegistry",
      },
      {
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "treasuryAddress",
      },
      {
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "claimedAero",
      },
      // Read AERO balance held by AeroManager
      {
        address: AERO_TOKEN_ADDRESS,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [AERO_MANAGER_ADDRESS],
      },
    ],
    query: {
      enabled: AERO_MANAGER_ADDRESS !== "0x0000000000000000000000000000000000000000",
    },
  });

  // Build gauge reads for all LP collaterals
  const gaugeContracts = useMemo(() => {
    return lpCollaterals.map((lp) => ({
      address: lp.gauge,
      abi: AeroGaugeAbi,
      functionName: "earned" as const,
      args: [AERO_MANAGER_ADDRESS] as const,
    }));
  }, [lpCollaterals]);

  // Read claimable AERO from all gauges
  const gaugeReads = useReadContracts({
    contracts: gaugeContracts,
    query: {
      enabled: hasGauges && AERO_MANAGER_ADDRESS !== "0x0000000000000000000000000000000000000000",
    },
  });

  // Write contract for claim
  const { writeContract, data: txHash, isPending: isWritePending, reset: resetWrite } = useWriteContract();
  const { isLoading: isTxLoading, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const governor = contractReads.data?.[0]?.result as Address | undefined;
  const aeroTokenAddress = contractReads.data?.[1]?.result as Address | undefined;
  const collateralRegistry = contractReads.data?.[2]?.result as Address | undefined;
  const treasuryAddress = contractReads.data?.[3]?.result as Address | undefined;
  const claimedAero = contractReads.data?.[4]?.result as bigint | undefined;
  const aeroBalance = contractReads.data?.[5]?.result as bigint | undefined;

  // Get claimable amounts for each gauge
  const claimableAmounts = useMemo(() => {
    if (!gaugeReads.data) return [];
    return gaugeReads.data.map((result) => result.result as bigint | undefined);
  }, [gaugeReads.data]);

  // Calculate total claimable
  const totalClaimable = useMemo(() => {
    return claimableAmounts.reduce<bigint>((acc, amount) => {
      if (amount !== undefined) {
        return acc + amount;
      }
      return acc;
    }, BigInt(0));
  }, [claimableAmounts]);

  // Get gauges with claimable rewards
  const claimableGauges = useMemo(() => {
    return lpCollaterals.filter((_, index) => {
      const amount = claimableAmounts[index];
      return amount !== undefined && amount > BigInt(0);
    });
  }, [lpCollaterals, claimableAmounts]);

  const isContractDeployed = AERO_MANAGER_ADDRESS !== "0x0000000000000000000000000000000000000000";
  const isClaimLoading = isWritePending || isTxLoading;

  const handleClaimSingle = (gaugeAddress: Address, index: number) => {
    setClaimingGaugeIndex(index);
    setIsClaimingAll(false);
    resetWrite();
    writeContract({
      address: AERO_MANAGER_ADDRESS,
      abi: AeroManagerAbi,
      functionName: "claim",
      args: [gaugeAddress],
    });
  };

  const handleClaimAll = async () => {
    if (claimableGauges.length === 0) return;

    setIsClaimingAll(true);
    setClaimingGaugeIndex(null);

    // For now, claim the first gauge with rewards
    // TODO: Implement proper multicall when wagmi supports it better
    const firstClaimableIndex = lpCollaterals.findIndex((_, index) => {
      const amount = claimableAmounts[index];
      return amount !== undefined && amount > BigInt(0);
    });

    const gaugeToClam = lpCollaterals[firstClaimableIndex];
    if (firstClaimableIndex !== -1 && gaugeToClam) {
      resetWrite();
      writeContract({
        address: AERO_MANAGER_ADDRESS,
        abi: AeroManagerAbi,
        functionName: "claim",
        args: [gaugeToClam.gauge],
      });
    }
  };

  const fadeIn = useSpring({
    from: { opacity: 0, transform: "translateY(20px)" },
    to: { opacity: 1, transform: "translateY(0px)" },
    config: { mass: 1, tension: 1800, friction: 120 },
  });

  return (
    <Screen
      heading={{
        title: "AERO Manager",
        subtitle: "Protocol contract for managing AERO token rewards from Aerodrome LP collateral",
      }}
      width={720}
    >
      <a.div style={fadeIn}>
        {/* Info Banner */}
        <div
          className={css({
            display: "flex",
            flexDirection: "column",
            gap: 16,
            padding: 24,
            background: "infoSurface",
            border: "1px solid token(colors.infoSurfaceBorder)",
            borderRadius: 12,
            marginBottom: 24,
          })}
        >
          <div
            className={css({
              display: "flex",
              alignItems: "center",
              gap: 16,
            })}
          >
            <div
              className={css({
                width: 48,
                height: 48,
                borderRadius: "50%",
                overflow: "hidden",
                flexShrink: 0,
              })}
            >
              <Image
                src="/images/ecosystem/aerodrome.png"
                alt="Aerodrome"
                width={48}
                height={48}
              />
            </div>
            <div>
              <h2
                className={css({
                  fontSize: 18,
                  fontWeight: 600,
                  marginBottom: 4,
                })}
              >
                What is AeroManager?
              </h2>
              <p
                className={css({
                  color: "contentAlt",
                  fontSize: 14,
                  lineHeight: 1.5,
                })}
              >
                AeroManager is a protocol contract that handles AERO token rewards generated by
                Aerodrome LP tokens deposited as collateral in the Base Dollar protocol.
                It stakes LP tokens in Aerodrome gauges and allows anyone to claim rewards.
              </p>
            </div>
          </div>

          <div
            className={css({
              display: "grid",
              gridTemplateColumns: "repeat(3, 1fr)",
              gap: 12,
              paddingTop: 16,
              borderTop: "1px solid token(colors.infoSurfaceBorder)",
            })}
          >
            <InfoItem
              label="Collects"
              value="AERO rewards from LP gauges"
            />
            <InfoItem
              label="Claim Fee"
              value="10% to treasury"
            />
            <InfoItem
              label="Managed by"
              value="Protocol governance"
            />
          </div>
        </div>

        {/* Contract Stats */}
        <div
          className={css({
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: 16,
            marginBottom: 24,
          })}
        >
          {/* AERO Balance Card */}
          <StatCard
            title="AERO Balance"
            subtitle="Currently held by the contract"
            icon={
              <TokenIcon
                symbol="AERO"
                size={32}
              />
            }
          >
            {isContractDeployed ? (
              <div
                className={css({
                  fontSize: 28,
                  fontWeight: 600,
                })}
              >
                <Amount
                  value={aeroBalance !== undefined ? dnum18(aeroBalance) : undefined}
                  format={2}
                  fallback="—"
                />{" "}
                <span className={css({ fontSize: 16, color: "contentAlt" })}>AERO</span>
              </div>
            ) : (
              <div className={css({ color: "contentAlt" })}>Contract not deployed</div>
            )}
          </StatCard>

          {/* Total Claimed AERO Card */}
          <StatCard
            title="Total Claimed"
            subtitle="Cumulative AERO claimed (after fees)"
            icon={
              <div
                className={css({
                  width: 32,
                  height: 32,
                  borderRadius: "50%",
                  background: "accent",
                  display: "grid",
                  placeItems: "center",
                  color: "accentContent",
                  fontSize: 18,
                })}
              >
                +
              </div>
            }
          >
            {isContractDeployed ? (
              <div
                className={css({
                  fontSize: 28,
                  fontWeight: 600,
                })}
              >
                <Amount
                  value={claimedAero !== undefined ? dnum18(claimedAero) : undefined}
                  format={2}
                  fallback="—"
                />{" "}
                <span className={css({ fontSize: 16, color: "contentAlt" })}>AERO</span>
              </div>
            ) : (
              <div className={css({ color: "contentAlt" })}>Contract not deployed</div>
            )}
          </StatCard>
        </div>

        {/* Gauge Rewards List */}
        <div
          className={css({
            display: "flex",
            flexDirection: "column",
            gap: 16,
            padding: 24,
            background: "surface",
            border: "1px solid token(colors.border)",
            borderRadius: 12,
            marginBottom: 24,
          })}
        >
          <div
            className={css({
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            })}
          >
            <div>
              <h3
                className={css({
                  fontSize: 16,
                  fontWeight: 600,
                })}
              >
                Claimable AERO Rewards
              </h3>
              <p
                className={css({
                  color: "contentAlt",
                  fontSize: 14,
                  marginTop: 4,
                })}
              >
                Anyone can trigger the claim process. 10% fee to treasury, rest distributed.
              </p>
            </div>
            {hasGauges && totalClaimable > BigInt(0) && (
              <div
                className={css({
                  textAlign: "right",
                })}
              >
                <div className={css({ fontSize: 12, color: "contentAlt" })}>Total Claimable</div>
                <div className={css({ fontSize: 18, fontWeight: 600 })}>
                  <Amount
                    value={dnum18(totalClaimable)}
                    format={4}
                  />{" "}
                  <span className={css({ fontSize: 14, color: "contentAlt" })}>AERO</span>
                </div>
              </div>
            )}
          </div>

          {!hasGauges ? (
            <div
              className={css({
                padding: 32,
                textAlign: "center",
                color: "contentAlt",
                background: "infoSurface",
                borderRadius: 8,
              })}
            >
              <p className={css({ fontSize: 14 })}>
                No gauges configured yet. Gauge addresses will be available after LP collaterals are deployed.
              </p>
            </div>
          ) : (
            <>
              {/* Gauge List */}
              <div
                className={css({
                  display: "flex",
                  flexDirection: "column",
                  gap: 8,
                })}
              >
                {lpCollaterals.map((lp, index) => {
                  const claimable = claimableAmounts[index];
                  const hasRewards = claimable !== undefined && claimable > BigInt(0);
                  const isClaiming = claimingGaugeIndex === index && isClaimLoading;
                  const wasJustClaimed = claimingGaugeIndex === index && isTxSuccess && !isClaimingAll;

                  return (
                    <div
                      key={lp.gauge}
                      className={css({
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        padding: 16,
                        background: hasRewards ? "infoSurface" : "surfaceAlt",
                        border: hasRewards ? "1px solid token(colors.infoSurfaceBorder)" : "1px solid token(colors.border)",
                        borderRadius: 8,
                        opacity: hasRewards ? 1 : 0.6,
                      })}
                    >
                      <div
                        className={css({
                          display: "flex",
                          alignItems: "center",
                          gap: 12,
                        })}
                      >
                        <div
                          className={css({
                            padding: "4px 8px",
                            background: lp.type === "SAMM" ? "positive" : "accent",
                            color: lp.type === "SAMM" ? "positiveContent" : "accentContent",
                            borderRadius: 4,
                            fontSize: 10,
                            fontWeight: 600,
                          })}
                        >
                          {lp.type}
                        </div>
                        <div>
                          <div className={css({ fontWeight: 500 })}>{lp.name}</div>
                          <div className={css({ fontSize: 12, color: "contentAlt", fontFamily: "mono" })}>
                            {shortenAddress(lp.gauge, 4)}
                          </div>
                        </div>
                      </div>

                      <div
                        className={css({
                          display: "flex",
                          alignItems: "center",
                          gap: 16,
                        })}
                      >
                        <div className={css({ textAlign: "right" })}>
                          <div className={css({ fontSize: 14, fontWeight: 600 })}>
                            <Amount
                              value={claimable !== undefined ? dnum18(claimable) : undefined}
                              format={4}
                              fallback="—"
                            />{" "}
                            <span className={css({ fontSize: 12, color: "contentAlt" })}>AERO</span>
                          </div>
                        </div>
                        <Button
                          label={isClaiming ? "Claiming..." : wasJustClaimed ? "Claimed!" : "Claim"}
                          mode={hasRewards ? "primary" : "secondary"}
                          size="small"
                          disabled={!isContractDeployed || !hasRewards || isClaimLoading}
                          onClick={() => handleClaimSingle(lp.gauge, index)}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Claim All Button */}
              {claimableGauges.length > 1 && (
                <Button
                  label={isClaimingAll && isClaimLoading ? "Claiming..." : `Claim All (${claimableGauges.length} gauges)`}
                  mode="primary"
                  size="large"
                  wide
                  disabled={!isContractDeployed || claimableGauges.length === 0 || isClaimLoading}
                  onClick={handleClaimAll}
                />
              )}
            </>
          )}

          {isTxSuccess && txHash && (
            <p className={css({ fontSize: 12, color: "positive", textAlign: "center" })}>
              Transaction successful!{" "}
              <Link
                href={`https://basescan.org/tx/${txHash}`}
                target="_blank"
                className={css({ color: "accent", textDecoration: "underline" })}
              >
                View on BaseScan
              </Link>
            </p>
          )}
        </div>

        {/* Contract Details */}
        <div
          className={css({
            padding: 24,
            background: "surface",
            border: "1px solid token(colors.border)",
            borderRadius: 12,
          })}
        >
          <h3
            className={css({
              fontSize: 16,
              fontWeight: 600,
              marginBottom: 16,
            })}
          >
            Contract Details
          </h3>

          <div
            className={css({
              display: "flex",
              flexDirection: "column",
              gap: 12,
            })}
          >
            <ContractInfoRow
              label="AeroManager Address"
              value={isContractDeployed ? AERO_MANAGER_ADDRESS : "Not deployed"}
              isAddress={isContractDeployed}
            />
            <ContractInfoRow
              label="Governor"
              value={governor ?? (isContractDeployed ? "Loading..." : "—")}
              isAddress={Boolean(governor)}
            />
            <ContractInfoRow
              label="Treasury"
              value={treasuryAddress ?? (isContractDeployed ? "Loading..." : "—")}
              isAddress={Boolean(treasuryAddress)}
            />
            <ContractInfoRow
              label="AERO Token"
              value={aeroTokenAddress ?? AERO_TOKEN_ADDRESS}
              isAddress={true}
            />
            <ContractInfoRow
              label="Collateral Registry"
              value={collateralRegistry ?? (isContractDeployed ? "Loading..." : "—")}
              isAddress={Boolean(collateralRegistry)}
            />
          </div>
        </div>

        {/* How It Works */}
        <div
          className={css({
            marginTop: 24,
            padding: 24,
            background: "infoSurface",
            border: "1px solid token(colors.infoSurfaceBorder)",
            borderRadius: 12,
          })}
        >
          <h3
            className={css({
              fontSize: 16,
              fontWeight: 600,
              marginBottom: 16,
            })}
          >
            How AERO Rewards Work
          </h3>

          <div
            className={css({
              display: "grid",
              gridTemplateColumns: "repeat(4, 1fr)",
              gap: 16,
            })}
          >
            <StepItem
              step="1"
              label="LP Deposited"
              description="Users deposit LP tokens as collateral"
            />
            <StepItem
              step="2"
              label="Staked in Gauges"
              description="AeroManager stakes LP in Aerodrome"
            />
            <StepItem
              step="3"
              label="Rewards Accrue"
              description="AERO rewards accumulate over time"
            />
            <StepItem
              step="4"
              label="Anyone Claims"
              description="10% fee to treasury, rest distributed"
            />
          </div>
        </div>

        {/* Learn More */}
        <div
          className={css({
            marginTop: 24,
            display: "flex",
            justifyContent: "center",
            gap: 16,
          })}
        >
          <LinkTextButton
            href={`${WHITE_LABEL_CONFIG.branding.links.github}/blob/main/contracts/src/AeroManager.sol`}
            label="View Contract Source"
            external
          />
          <LinkTextButton
            href={WHITE_LABEL_CONFIG.branding.links.docs.aeroManager}
            label="Read Documentation"
            external
          />
        </div>
      </a.div>
    </Screen>
  );
}

function StatCard({
  title,
  subtitle,
  icon,
  children,
}: {
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div
      className={css({
        display: "flex",
        flexDirection: "column",
        gap: 12,
        padding: 20,
        background: "surface",
        border: "1px solid token(colors.border)",
        borderRadius: 12,
      })}
    >
      <div
        className={css({
          display: "flex",
          alignItems: "center",
          gap: 12,
        })}
      >
        {icon}
        <div>
          <div className={css({ fontWeight: 600 })}>{title}</div>
          <div className={css({ fontSize: 12, color: "contentAlt" })}>{subtitle}</div>
        </div>
      </div>
      <div>{children}</div>
    </div>
  );
}

function InfoItem({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div>
      <div
        className={css({
          fontSize: 12,
          color: "contentAlt",
          marginBottom: 4,
        })}
      >
        {label}
      </div>
      <div
        className={css({
          fontSize: 14,
          fontWeight: 500,
        })}
      >
        {value}
      </div>
    </div>
  );
}

function ContractInfoRow({
  label,
  value,
  isAddress,
}: {
  label: string;
  value: string;
  isAddress: boolean;
}) {
  return (
    <div
      className={css({
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        padding: "8px 0",
        borderBottom: "1px solid token(colors.border)",
        _last: {
          borderBottom: "none",
        },
      })}
    >
      <span className={css({ color: "contentAlt", fontSize: 14 })}>{label}</span>
      {isAddress && value.startsWith("0x") ? (
        <Link
          href={`https://basescan.org/address/${value}`}
          target="_blank"
          rel="noopener noreferrer"
          className={css({
            fontFamily: "mono",
            fontSize: 14,
            color: "accent",
            _hover: {
              textDecoration: "underline",
            },
          })}
        >
          {shortenAddress(value as Address, 6)}
        </Link>
      ) : (
        <span
          className={css({
            fontFamily: "mono",
            fontSize: 14,
          })}
        >
          {value}
        </span>
      )}
    </div>
  );
}

function StepItem({
  step,
  label,
  description,
}: {
  step: string;
  label: string;
  description: string;
}) {
  return (
    <div
      className={css({
        textAlign: "center",
      })}
    >
      <div
        className={css({
          width: 32,
          height: 32,
          borderRadius: "50%",
          background: "accent",
          color: "accentContent",
          display: "grid",
          placeItems: "center",
          fontSize: 16,
          fontWeight: 700,
          margin: "0 auto 8px",
        })}
      >
        {step}
      </div>
      <div
        className={css({
          fontSize: 14,
          fontWeight: 600,
          marginTop: 4,
        })}
      >
        {label}
      </div>
      <div
        className={css({
          fontSize: 12,
          color: "contentAlt",
          marginTop: 2,
        })}
      >
        {description}
      </div>
    </div>
  );
}
