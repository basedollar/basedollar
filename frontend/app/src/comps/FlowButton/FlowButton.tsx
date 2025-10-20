import type { ReactNode } from "react";

import { useBreakpointName } from "@/src/breakpoints";
import { ConnectWarningBox } from "@/src/comps/ConnectWarningBox/ConnectWarningBox";
import { useTransactionFlow } from "@/src/services/TransactionFlow";
import { css } from "@/styled-system/css";
import { Button, Tooltip } from "@liquity2/uikit";

type FlowRequest = Parameters<
  ReturnType<typeof useTransactionFlow>["start"]
>[0];

type FlowRequestParam = FlowRequest | null | undefined;

export function FlowButton({
  disabled,
  disabledReason,
  footnote,
  label,
  request,
  size = "large",
}: {
  disabled?: boolean;
  disabledReason?: string;
  footnote?: ReactNode;
  label?: string;
  request?: (() => FlowRequestParam) | FlowRequestParam;
  size?: "medium" | "large" | "small" | "mini";
}) {
  const txFlow = useTransactionFlow();
  const breakpointName = useBreakpointName();
  
  const button = (
    <Button
      className="flow-button"
      disabled={disabled || !request}
      label={label ?? "Next: Summary"}
      mode="primary"
      size={size === "large" && breakpointName === "small" ? "medium" : size}
      wide
      style={size === "large"
        ? {
          height: breakpointName === "small" ? 56 : 72,
          fontSize: breakpointName === "small" ? 20 : 24,
          borderRadius: breakpointName === "small" ? 56 : 120,
        }
        : {}}
      onClick={() => {
        if (typeof request === "function") {
          request = request();
        }
        if (request) {
          txFlow.start(request);
        }
      }}
    />
  );
  
  return (
    <>
      <div
        className={css({
          display: "flex",
          flexDirection: "column",
          gap: 48,
        })}
      >
        <ConnectWarningBox />
        {disabled && disabledReason ? (
          <Tooltip
            opener={({ buttonProps, setReference }) => (
              <span ref={setReference} {...buttonProps} style={{ width: "100%" }}>
                {button}
              </span>
            )}
          >
            <div style={{ padding: "8px", fontSize: 14 }}>
              {disabledReason}
            </div>
          </Tooltip>
        ) : button}
      </div>
      {footnote && (
        <div
          className={css({
            fontSize: 14,
            textAlign: "center",
          })}
        >
          {footnote}
        </div>
      )}
    </>
  );
}
