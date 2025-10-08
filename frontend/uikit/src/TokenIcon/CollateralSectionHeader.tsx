"use client";

import { css } from "../../styled-system/css";

export function CollateralSectionHeader({
  title,
  isFirst = false,
  colSpan = 5, // Default to 5 columns, can be overridden
}: {
  title: string;
  isFirst?: boolean;
  colSpan?: number;
}) {
  return (
    <tr>
      <td
        colSpan={colSpan}
        className={css({
          padding: `${isFirst ? 0 : 24}px 0 12px !important`,
          borderTop: "none !important",
        })}
      >
        <div
          className={css({
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 12,
            fontSize: 12,
            fontWeight: 600,
            textTransform: "uppercase",
            color: "contentAlt",
            letterSpacing: "0.05em",
            userSelect: "none",
            width: "100%",
            
            _before: {
              content: '""',
              height: "1px",
              backgroundColor: "contentAlt2",
              opacity: 0.3,
              flex: 1,
            },
            
            _after: {
              content: '""',
              height: "1px", 
              backgroundColor: "contentAlt2",
              opacity: 0.3,
              flex: 1,
            },
          })}
        >
          {title}
        </div>
      </td>
    </tr>
  );
}