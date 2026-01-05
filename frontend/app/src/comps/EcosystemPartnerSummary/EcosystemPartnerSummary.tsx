import type { ReactNode } from "react";
import type { CollateralSymbol } from "@/src/types";

import { css } from "@/styled-system/css";
import { TokenIcon, IconExternal } from "@liquity2/uikit";
import Link from "next/link";
import Image from "next/image";

export type EcosystemPartnerId = 
  | "aero"
  | "liquity"
  | "nerite"
  | "deficollective";

export function EcosystemPartnerSummary({
  partnerId,
}: {
  partnerId: EcosystemPartnerId;
}) {
  const partnerContent: Record<EcosystemPartnerId, {
    title: string;
    subtitle: string;
    href: string;
    logo?: string;
    symbol?: CollateralSymbol;
  }> = {
    aero: {
      title: "Aerodrome",
      subtitle: "Leading DEX and liquidity protocol on Base",
      href: "https://aerodrome.finance/",
      logo: "/images/ecosystem/aerodrome.png",
    },
    liquity: {
      title: "Liquity",
      subtitle: "Decentralized borrowing protocol with flexible rates",
      href: "https://liquity.org/",
      logo: "/images/ecosystem/liquity.png",
    },
    nerite: {
      title: "Nerite",
      subtitle: "Multi-collateral borrowing protocol on Arbitrum",
      href: "https://nerite.io/",
      logo: "/images/ecosystem/nerite.png",
    },
    deficollective: {
      title: "DeFi Collective",
      subtitle: "Non-profit supporting DeFi infrastructure",
      href: "https://deficollective.org/",
      logo: "/images/ecosystem/deficollective.jpg",
    },
  };

  const partner = partnerContent[partnerId];

  return (
    <EcosystemPartnerSummaryBase
      action={{
        label: "Visit website",
        href: partner.href,
        target: "_blank",
      }}
      title={partner.title}
      subtitle={partner.subtitle}
      logo={partner.logo}
      symbol={partner.symbol}
    />
  );
}

export function EcosystemPartnerSummaryBase({
  action,
  logo,
  symbol,
  subtitle,
  title,
}: {
  action?: null | {
    label: string;
    href: string;
    target: "_blank" | "_self" | "_parent" | "_top";
  };
  logo?: string;
  symbol?: CollateralSymbol;
  subtitle?: ReactNode;
  title?: ReactNode;
}) {
  return (
    <div
      className={css({
        position: "relative",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: "12px 16px",
        borderRadius: 8,
        borderWidth: 1,
        borderStyle: "solid",
        width: "100%",
        userSelect: "none",
        borderColor: "token(colors.infoSurfaceBorder)",
        background: "token(colors.infoSurface)",
        color: "token(colors.content)",
      })}
    >
      <div
        className={css({
          display: "flex",
          alignItems: "start",
          gap: 16,
          paddingBottom: 12,
          borderBottom: "1px solid token(colors.infoSurfaceBorder)",
        })}
      >
        <div
          className={css({
            flexGrow: 0,
            flexShrink: 0,
            display: "flex",
          })}
        >
          {logo ? (
            <div
              className={css({
                width: 34,
                height: 34,
                position: "relative",
                borderRadius: "50%",
                overflow: "hidden",
              })}
            >
              <Image
                src={logo}
                alt={String(title)}
                width={34}
                height={34}
                style={{ objectFit: "contain" }}
              />
            </div>
          ) : symbol ? (
            <TokenIcon symbol={symbol} size={34} />
          ) : (
            <div
              className={css({
                width: 34,
                height: 34,
                borderRadius: "50%",
                background: "token(colors.secondary)",
              })}
            />
          )}
        </div>
        <div
          className={css({
            flexGrow: 1,
            display: "flex",
            justifyContent: "space-between",
          })}
        >
          <div
            className={css({
              display: "flex",
              flexDirection: "column",
            })}
          >
            <div>{title}</div>
            <div
              className={css({
                display: "flex",
                gap: 4,
                fontSize: 14,
                color: "token(colors.contentAlt)",
              })}
            >
              {subtitle}
            </div>
          </div>
        </div>
      </div>
      <div
        className={css({
          position: "relative",
          display: "flex",
          gap: 32,
          alignItems: "center",
          justifyContent: "space-between",
          paddingTop: 12,
          height: 56,
          fontSize: 14,
        })}
      >
        {action && (
          <OpenLink
            href={action.href}
            target={action.target}
            title={action.label}
          />
        )}
      </div>
    </div>
  );
}

function OpenLink({
  href,
  target,
  title,
}: {
  href: string;
  target: "_blank" | "_self" | "_parent" | "_top";
  title: string;
}) {
  return (
    <Link
      title={title}
      href={href}
      target={target}
      className={css({
        position: "absolute",
        inset: "0 -16px -12px auto",
        display: "grid",
        placeItems: {
          base: "end center",
          large: "center",
        },
        padding: {
          base: "16px 12px",
          large: "0 12px 0 24px",
        },
        borderRadius: 8,
        _focusVisible: {
          outline: "2px solid token(colors.focused)",
          outlineOffset: -2,
        },
        _active: {
          translate: "0 1px",
        },

        "& > div": {
          transformOrigin: "50% 50%",
          transition: "scale 80ms",
        },
        _hover: {
          "& > div": {
            scale: 1.05,
          },
        },
      })}
    >
      <div
        className={css({
          display: "grid",
          placeItems: "center",
          width: 34,
          height: 34,
          color: "accentContent",
          background: "accent",
          borderRadius: "50%",
        })}
      >
        <IconExternal size={24} />
      </div>
    </Link>
  );
}
