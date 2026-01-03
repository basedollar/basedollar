"use client";

import type { ReactNode } from "react";
import { css } from "@/styled-system/css";

// Simple tooltip that appears immediately on hover
export function Tip({ children, tip }: { children: ReactNode; tip: string }) {
  return (
    <span
      className={css({
        position: "relative",
        cursor: "help",
        "&:hover > span": {
          opacity: 1,
          visibility: "visible",
        },
      })}
    >
      {children}
      <span
        className={css({
          position: "absolute",
          bottom: "calc(100% + 6px)",
          left: "50%",
          transform: "translateX(-50%)",
          padding: "6px 10px",
          fontSize: 12,
          fontWeight: 400,
          color: "white",
          background: "#1C1D4D",
          borderRadius: 6,
          whiteSpace: "nowrap",
          opacity: 0,
          visibility: "hidden",
          transition: "opacity 0.15s",
          zIndex: 100,
          pointerEvents: "none",
        })}
      >
        {tip}
      </span>
    </span>
  );
}
