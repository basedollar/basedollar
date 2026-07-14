"use client";

import type { ReactNode } from "react";

import { createContext, useContext, useState } from "react";

// BaseDollar landing palette - keep existing token names for compatibility.
export const colors = {
  // Burgundy
  "blue:50": "#FFF7E3",
  "blue:100": "#F5E6C8",
  "blue:200": "#F5D57D",
  "blue:300": "#D4B85C",
  "blue:400": "#C4973A",
  "blue:500": "#56232F",
  "blue:600": "#4A1C28",
  "blue:700": "#3A1520",
  "blue:800": "#2B1018",
  "blue:900": "#1C0A10",
  "blue:950": "#12060A",

  // Warm neutrals
  "gray:50": "#FFFCF2",
  "gray:100": "#FDF6E3",
  "gray:200": "#F2E6D9",
  "gray:300": "#E2CDAF",
  "gray:400": "#C9A877",
  "gray:500": "#98670A",
  "gray:600": "#6F4B12",
  "gray:700": "#4A1C28",
  "gray:800": "#3A1520",
  "gray:900": "#2B1018",
  "gray:950": "#12060A",

  // Yellow
  "yellow:50": "#FFFDF0",
  "yellow:100": "#FDF6E3",
  "yellow:200": "#F5E6C8",
  "yellow:300": "#F5D57D",
  "yellow:400": "#E8C96E",
  "yellow:500": "#D4B85C",
  "yellow:600": "#C4973A",
  "yellow:700": "#98670A",
  "yellow:800": "#5F4007",
  "yellow:900": "#3A2705",
  "yellow:950": "#261A03",

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

  // Burgundy-black
  "black:50": "#4A1C28",
  "black:100": "#3A1520",
  "black:200": "#32121C",
  "black:300": "#2B1018",
  "black:400": "#230C14",
  "black:500": "#1C0A10",
  "black:600": "#12060A",
  "black:700": "#08060D",

  // Silver
  "silver:100": "#E2CDAF",
  "silver:200": "#C9A877",
  "silver:300": "#98670A",

  // Brown
  "brown:50": "#FFFDF0",

  // Desert
  "desert:50": "#FDF6E3",
  "desert:100": "#F5E6C8",
  "desert:950": "#4A1C28",

  // White
  "white": "#FFFFFF",

  // Brand colors
  "brand:blue": "#56232F",
  "brand:lightBlue": "#F5D57D",
  "brand:darkBlue": "#3A1520",
  "brand:green": "#10B981",
  "brand:golden": "#F5D57D",
  "brand:cyan": "#D4B85C",
  "brand:coral": "#C4973A",
  "brand:brown": "#98670A",
};

// The light theme with BaseDollar landing branding.
export const lightTheme = {
  name: "light" as const,
  colors: {
    accent: "yellow:300",
    accentActive: "yellow:500",
    accentContent: "blue:700",
    accentHint: "yellow:600",
    background: "yellow:100",
    backgroundActive: "yellow:50",
    border: "blue:500",
    borderSoft: "yellow:200",
    content: "blue:600",
    contentAlt: "gray:700",
    contentAlt2: "gray:500",
    controlBorder: "blue:500",
    controlBorderStrong: "blue:700",
    controlSurface: "yellow:50",
    controlSurfaceAlt: "yellow:200",
    hint: "brown:50",
    infoSurface: "desert:50",
    infoSurfaceBorder: "desert:100",
    infoSurfaceContent: "blue:600",
    dimmed: "gray:400",
    fieldBorder: "yellow:200",
    fieldBorderFocused: "blue:500",
    fieldSurface: "yellow:50",
    focused: "yellow:300",
    focusedSurface: "yellow:100",
    focusedSurfaceActive: "yellow:200",
    strongSurface: "blue:600",
    strongSurfaceContent: "yellow:100",
    strongSurfaceContentAlt: "yellow:300",
    strongSurfaceContentAlt2: "yellow:200",
    position: "blue:600",
    positionContent: "yellow:100",
    positionContentAlt: "yellow:300",
    interactive: "blue:600",
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
    negativeInfoSurfaceContent: "blue:700",
    negativeInfoSurfaceContentAlt: "gray:600",
    positive: "green:500",
    positiveAlt: "green:400",
    positiveActive: "green:600",
    positiveContent: "white",
    positiveHint: "green:400",
    secondary: "yellow:200",
    secondaryActive: "yellow:300",
    secondaryContent: "blue:600",
    secondaryHint: "yellow:100",
    selected: "yellow:300",
    separator: "yellow:200",
    surface: "yellow:50",
    tableBorder: "yellow:200",
    warning: "yellow:300",
    warningAlt: "yellow:300",
    warningAltContent: "blue:700",
    disabledBorder: "yellow:200",
    disabledContent: "gray:500",
    disabledSurface: "yellow:100",
    brandBlue: "brand:blue",
    brandBlueContent: "yellow:100",
    brandBlueContentAlt: "yellow:300",
    brandDarkBlue: "brand:darkBlue",
    brandDarkBlueContent: "yellow:100",
    brandDarkBlueContentAlt: "yellow:300",
    brandLightBlue: "brand:lightBlue",
    brandGolden: "brand:golden",
    brandGoldenContent: "blue:700",
    brandGoldenContentAlt: "blue:600",
    brandGreen: "brand:green",
    brandGreenContent: "green:950",
    brandGreenContentAlt: "green:800",

    riskGradient1: "#10B981", // green:500
    riskGradient2: "#84CC16",
    riskGradient3: "#F5D57D",
    riskGradient4: "#C4973A",
    riskGradient5: "#F87171", // red:400

    riskGradientDimmed1: "red:100",
    riskGradientDimmed2: "yellow:100",
    riskGradientDimmed3: "green:100",

    loadingGradient1: "yellow:100",
    loadingGradient2: "yellow:200",
    loadingGradientContent: "yellow:600",

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
