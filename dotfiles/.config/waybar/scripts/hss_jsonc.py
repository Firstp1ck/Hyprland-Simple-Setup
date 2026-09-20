"""JSONC normalization shared by Waybar startup and the setup role updater."""

import json
from pathlib import Path
import re
import sys

TOKENS = re.compile(r'"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/')
TRAILING_COMMA = re.compile(r'"(?:\\.|[^"\\])*"|,(?=\s*[}\]])')


def json_text(text):
    """Blank comments and trailing commas without shifting source offsets."""
    def blank_comment(match):
        token = match.group()
        return token if token.startswith('"') else re.sub(r'[^\r\n]', ' ', token)

    clean = TOKENS.sub(blank_comment, text)
    return TRAILING_COMMA.sub(lambda m: ' ' if m.group() == ',' else m.group(), clean)


def main():
    try:
        data = json.loads(json_text(Path(sys.argv[1]).read_text(encoding="utf-8")))
        if not isinstance(data, (dict, list)):
            raise ValueError("Waybar config must contain an object or array")
    except (OSError, ValueError, IndexError) as error:
        print(f"Invalid Waybar config: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
