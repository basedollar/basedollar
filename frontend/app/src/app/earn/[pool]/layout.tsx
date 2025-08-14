import { EarnPoolScreen } from "@/src/screens/EarnPoolScreen/EarnPoolScreen";
import { SboldPoolScreen } from "@/src/screens/EarnPoolScreen/SboldPoolScreen";
import { getEarnPoolSymbols, WHITE_LABEL_CONFIG } from "@/src/white-label.config";

export function generateStaticParams() {
  return getEarnPoolSymbols().map(pool => ({ pool }));
}

export default async function Layout({
  params,
}: {
  params: Promise<{
    pool: string;
  }>;
}) {
  const { pool } = await params;
  const stakedPoolSymbol = WHITE_LABEL_CONFIG.tokens.otherTokens.staked.symbol.toLowerCase();
  return pool === stakedPoolSymbol
    ? <SboldPoolScreen />
    : <EarnPoolScreen />;
}
