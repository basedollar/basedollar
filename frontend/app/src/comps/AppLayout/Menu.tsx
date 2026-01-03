import type { ComponentType } from "react";

import { css } from "@/styled-system/css";
import { token } from "@/styled-system/tokens";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { MenuItem } from "./MenuItem";

export type MenuItem = [
  label: string,
  url: string,
  Icon: ComponentType<{}>,
];

function isExternalUrl(url: string) {
  return url.startsWith("http://") || url.startsWith("https://");
}

export function Menu({
  menuItems,
}: {
  menuItems: MenuItem[];
}) {
  const pathname = usePathname();
  return (
    <nav
      className={css({
        display: "none",
        large: {
          display: "block",
        },
      })}
    >
      <ul
        className={css({
          position: "relative",
          zIndex: 2,
          display: "flex",
          gap: 8,
          height: "100%",
        })}
      >
        {menuItems.map(([label, href, Icon]) => {
          const isExternal = isExternalUrl(href);
          const selected = !isExternal && (href === "/" ? pathname === "/" : pathname.startsWith(href));

          const linkClassName = css({
            display: "flex",
            height: "100%",
            padding: "0 8px",
            _active: {
              translate: "0 1px",
            },
            _focusVisible: {
              outline: "2px solid token(colors.focused)",
              borderRadius: 4,
            },
          });

          const linkStyle = {
            color: token(`colors.${selected ? "selected" : "interactive"}`),
          };

          return (
            <li key={label + href}>
              {isExternal ? (
                <a
                  href={href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={linkClassName}
                  style={linkStyle}
                >
                  <MenuItem
                    icon={<Icon />}
                    label={label}
                    selected={false}
                  />
                </a>
              ) : (
                <Link
                  href={href}
                  className={linkClassName}
                  style={linkStyle}
                >
                  <MenuItem
                    icon={<Icon />}
                    label={label}
                    selected={selected}
                  />
                </Link>
              )}
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
