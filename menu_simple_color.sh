#!/bin/bash
# DEPRECATED: menu_simple_color.sh has been merged into menu.sh.
# Please use ./menu.sh instead.
echo "WARNING: menu_simple_color.sh is deprecated and will be removed in a future release."
echo "         Please use ./menu.sh instead (supports both gum and text-based UI)."
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/menu.sh"
