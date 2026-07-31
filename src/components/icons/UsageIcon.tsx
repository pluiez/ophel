/**
 * SVG 图标组件 - 用量（柱状图）
 * 风格：Outline (stroke-based)，与 SIDEBAR_ICONS 保持一致
 */
import React from "react"

interface IconProps {
  size?: number
  color?: string
  className?: string
}

export const UsageIcon: React.FC<IconProps> = ({
  size = 18,
  color = "currentColor",
  className = "",
}) => (
  <svg
    viewBox="0 0 24 24"
    width={size}
    height={size}
    fill="none"
    stroke={color}
    strokeWidth="1.5"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={className}
    style={{ display: "block" }}>
    <rect x="4" y="13" width="4" height="7" rx="1" />
    <rect x="10" y="8" width="4" height="12" rx="1" />
    <rect x="16" y="3" width="4" height="17" rx="1" />
  </svg>
)

export default UsageIcon
