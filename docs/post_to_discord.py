"""Post docs/server-template.md to a Discord webhook, one message per section.

Discord limits a message to 2000 characters, which is why pasting the whole
template fails. This script splits the file at its "## " headings and sends each
part as its own message, so nothing has to be copied by hand.

Usage
    python post_template.py --dry                    # just show the parts and sizes
    python post_template.py <webhook-url>            # post every section
    python post_template.py <webhook-url> 5          # post only section 5 (rules)

The webhook URL is never stored: pass it on the command line. Create one in
Discord via Channel settings > Integrations > Webhooks > New Webhook > Copy URL.
Only standard library, no dependencies.
"""

import json
import os
import sys
import time
import urllib.request

MAX = 1900  # Discord allows 2000, leave a little room


def read_template(path: str):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()

    sections = []
    current = []
    for line in text.splitlines():
        if line.startswith("## "):
            if current:
                sections.append("\n".join(current).strip())
            current = [line]
        else:
            current.append(line)
    if current:
        sections.append("\n".join(current).strip())
    return [s for s in sections if s]


def post(url: str, content: str) -> bool:
    payload = json.dumps({"content": content[:MAX]}).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "server-template-poster/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return 200 <= response.status < 300
    except Exception as error:  # noqa: BLE001 - report and continue
        print("  failed:", error)
        return False


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "server-template.md")
    if not os.path.isfile(path):
        print("server-template.md not found next to this script")
        return 1

    sections = read_template(path)
    print("sections found:", len(sections))
    for index, section in enumerate(sections, 1):
        title = section.splitlines()[0][3:]
        print("  %2d  %5d chars  %s" % (index, len(section), title))
        if len(section) > MAX:
            print("      WARNING: longer than %d, it will be cut" % MAX)

    args = sys.argv[1:]
    if not args or args[0] == "--dry":
        print("\ndry run - nothing sent. Pass a webhook URL to post.")
        return 0

    url = args[0]
    only = int(args[1]) if len(args) > 1 else None

    if only is not None:
        sections = [sections[only - 1]] if 1 <= only <= len(sections) else []

    sent = 0
    for section in sections:
        if post(url, section):
            sent += 1
            print("  sent a %d character message" % len(section))
        time.sleep(1.5)  # stay well inside the webhook rate limit

    print("\nsent %d of %d" % (sent, len(sections)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
