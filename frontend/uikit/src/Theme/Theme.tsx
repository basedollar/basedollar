"use client";

import type { ReactNode } from "react";

import { createContext, useContext, useState } from "react";

// Base Chain color palette - backward compatible with existing token names
export const colors = {
  // Blue - Updated to Base/Coinbase blue (#0052FF)
  "blue:50": "#E6EDFF",
  "blue:100": "#C2D4FF",
  "blue:200": "#99B8FF",
  "blue:300": "#709CFF",
  "blue:400": "#4D80FF",
  "blue:500": "#0052FF", // Base primary blue
  "blue:600": "#0047DB",
  "blue:700": "#003CB7",
  "blue:800": "#003193",
  "blue:900": "#00266F",
  "blue:950": "#001B4B",

  // Gray - Clean, modern neutrals
  "gray:50": "#FAFAFA",
  "gray:100": "#F5F5F5",
  "gray:200": "#E5E5E5",
  "gray:300": "#D4D4D4",
  "gray:400": "#A3A3A3",
  "gray:500": "#737373",
  "gray:600": "#525252",
  "gray:700": "#404040",
  "gray:800": "#262626",
  "gray:900": "#171717",
  "gray:950": "#0A0A0A",

  // Yellow
  "yellow:50": "#FEFCE8",
  "yellow:100": "#FEF9C3",
  "yellow:200": "#FEF08A",
  "yellow:300": "#FDE047",
  "yellow:400": "#FACC15",
  "yellow:500": "#EAB308",
  "yellow:600": "#CA8A04",
  "yellow:700": "#A16207",
  "yellow:800": "#854D0E",
  "yellow:900": "#713F12",
  "yellow:950": "#422006",

  // Green
  "green:50": "#ECFDF5",
  "green:100": "#D1FAE5",
  "green:200": "#A7F3D0",
  "green:300": "#6EE7B7",
  "green:400": "#34D399",
  "green:500": "#10B981",
  "green:600": "#059669",
  "green:700": "#047857",
  "green:800": "#065F46",
  "green:900": "#064E3B",
  "green:950": "#022C22",

  // Red
  "red:50": "#FEF2F2",
  "red:100": "#FEE2E2",
  "red:200": "#FECACA",
  "red:300": "#FCA5A5",
  "red:400": "#F87171",
  "red:500": "#EF4444",
  "red:600": "#DC2626",
  "red:700": "#B91C1C",
  "red:800": "#991B1B",
  "red:900": "#7F1D1D",
  "red:950": "#450A0A",

  // Black - Updated to Woodsmoke (#0A0B0D)
  "black:50": "#2A2A2A",
  "black:100": "#1F1F1F",
  "black:200": "#1A1A1A",
  "black:300": "#141414",
  "black:400": "#0F0F0F",
  "black:500": "#0A0B0D", // Coinbase Woodsmoke
  "black:600": "#080809",
  "black:700": "#000000",

  // Silver
  "silver:100": "#B8B8B8",
  "silver:200": "#A0A0A0",
  "silver:300": "#888888",

  // Brown
  "brown:50": "#F8F6F4",

  // Desert
  "desert:50": "#FAF9F7",
  "desert:100": "#EFECE5",
  "desert:950": "#2C231E",

  // White
  "white": "#FFFFFF",

  // Brand colors - Updated for Base
  "brand:blue": "#0052FF",
  "brand:lightBlue": "#709CFF",
  "brand:darkBlue": "#001B4B",
  "brand:green": "#10B981",
  "brand:golden": "#FACC15",
  "brand:cyan": "#00D4FF",
  "brand:coral": "#F97316",
  "brand:brown": "#A16207",
};

// The light theme with Base branding
export const lightTheme = {
  name: "light" as const,
  colors: {
    accent: "blue:500",
    accentActive: "blue:600",
    accentContent: "white",
    accentHint: "blue:400",
    background: "white",
    backgroundActive: "gray:50",
    border: "gray:200",
    borderSoft: "gray:100",
    content: "black:700",
    contentAlt: "gray:600",
    contentAlt2: "gray:500",
    controlBorder: "gray:300",
    controlBorderStrong: "black:600",
    controlSurface: "white",
    controlSurfaceAlt: "gray:200",
    hint: "brown:50",
    infoSurface: "desert:50",
    infoSurfaceBorder: "desert:100",
    infoSurfaceContent: "black:600",
    dimmed: "gray:400",
    fieldBorder: "gray:100",
    fieldBorderFocused: "gray:300",
    fieldSurface: "gray:50",
    focused: "blue:500",
    focusedSurface: "blue:50",
    focusedSurfaceActive: "blue:100",
    strongSurface: "black:600",
    strongSurfaceContent: "white",
    strongSurfaceContentAlt: "gray:500",
    strongSurfaceContentAlt2: "gray:100",
    position: "black:500",
    positionContent: "white",
    positionContentAlt: "gray:500",
    interactive: "black:600",
    negative: "red:500",
    negativeStrong: "red:600",
    negativeActive: "red:600",
    negativeContent: "white",
    negativeHint: "red:400",
    negativeSurface: "red:50",
    negativeSurfaceBorder: "red:100",
    negativeSurfaceContent: "red:900",
    negativeSurfaceContentAlt: "red:400",
    negativeInfoSurface: "red:50",
    negativeInfoSurfaceBorder: "red:200",
    negativeInfoSurfaceContent: "black:700",
    negativeInfoSurfaceContentAlt: "gray:600",
    positive: "green:500",
    positiveAlt: "green:400",
    positiveActive: "green:600",
    positiveContent: "white",
    positiveHint: "green:400",
    secondary: "blue:50",
    secondaryActive: "blue:200",
    secondaryContent: "blue:500",
    secondaryHint: "blue:100",
    selected: "blue:500",
    separator: "gray:50",
    surface: "white",
    tableBorder: "gray:100",
    warning: "yellow:400",
    warningAlt: "yellow:300",
    warningAltContent: "black:700",
    disabledBorder: "gray:200",
    disabledContent: "gray:500",
    disabledSurface: "gray:50",
    brandBlue: "brand:blue",
    brandBlueContent: "white",
    brandBlueContentAlt: "blue:50",
    brandDarkBlue: "brand:darkBlue",
    brandDarkBlueContent: "white",
    brandDarkBlueContentAlt: "gray:50",
    brandLightBlue: "brand:lightBlue",
    brandGolden: "brand:golden",
    brandGoldenContent: "yellow:950",
    brandGoldenContentAlt: "yellow:800",
    brandGreen: "brand:green",
    brandGreenContent: "green:950",
    brandGreenContentAlt: "green:800",

    riskGradient1: "#10B981", // green:500
    riskGradient2: "#84CC16",
    riskGradient3: "#FACC15", // yellow:400
    riskGradient4: "#F97316",
    riskGradient5: "#F87171", // red:400

    riskGradientDimmed1: "red:100",
    riskGradientDimmed2: "yellow:100",
    riskGradientDimmed3: "green:100",

    loadingGradient1: "blue:50",
    loadingGradient2: "blue:100",
    loadingGradientContent: "blue:400",

    // not used yet
    brandCyan: "brand:cyan",
    brandCoral: "brand:coral",
    brandBrown: "brand:brown",
  } satisfies Record<string, (keyof typeof colors) | `#${string}`>,
} as const;

export type ThemeDescriptor = {
  name: "light"; // will be "light" | "dark" once dark mode is added
  colors: typeof lightTheme.colors; // lightTheme acts as a reference for types
};
export type ThemeColorName = keyof ThemeDescriptor["colors"];

export function themeColor(theme: ThemeDescriptor, name: ThemeColorName) {
  const themeColor = theme.colors[name];

  if (themeColor.startsWith("#")) {
    return themeColor;
  }

  if (themeColor in colors) {
    return colors[themeColor as keyof typeof colors];
  }

  throw new Error(`Color ${themeColor} not found in theme`);
}

const ThemeContext = createContext({
  theme: lightTheme,
  setTheme: (_: ThemeDescriptor) => {},
});

export function useTheme() {
  const { theme, setTheme } = useContext(ThemeContext);
  return {
    color: (name: ThemeColorName) => themeColor(theme, name),
    setTheme,
    theme,
  };
}

export function Theme({
  children,
}: {
  children: ReactNode;
}) {
  const [theme, setTheme] = useState<ThemeDescriptor>(lightTheme);
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}