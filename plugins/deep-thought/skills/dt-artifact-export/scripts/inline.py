"""Fold every outside dependency of an artifact page into the page itself.

Usage: inline.py <input.html> <output.html> [--subsets latin,latin-ext]

Reads the input, fetches what it references, rewrites it as data URIs and inline
blocks, writes the output, and prints a report of what happened to stdout.
Touches nothing but the output path.
"""
import base64, mimetypes, os, re, sys, urllib.parse, urllib.request

# Google Fonts serves by User-Agent. Ask as curl and it hands back TTF, twenty times
# the bytes of the WOFF2 every browser since 2014 can read. This string is the whole
# difference between a 300KB file and a 4MB one.
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
TIMEOUT = 25
MAX_BYTES = 12 * 1024 * 1024

report = {"inlined": [], "skipped": [], "failed": []}

# A variable font serves one file for several weights, so the same URL comes back
# several times in one stylesheet. Without this the bytes land in the output twice.
_cache = {}


def fetch(url):
    if url in _cache:
        return _cache[url]
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        data = r.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("larger than %d bytes" % MAX_BYTES)
    _cache[url] = data
    return data


def load(url, base_dir):
    """Fetch a URL, or read a path relative to the input file. Returns bytes."""
    if url.startswith("data:"):
        return None
    if re.match(r"^https?://", url):
        return fetch(url)
    if url.startswith("//"):
        return fetch("https:" + url)
    local = os.path.join(base_dir, url.split("?")[0].split("#")[0])
    with open(local, "rb") as f:
        return f.read()


def data_uri(raw, url):
    guess = mimetypes.guess_type(url.split("?")[0])[0]
    if not guess:
        if ".woff2" in url:
            guess = "font/woff2"
        elif ".woff" in url:
            guess = "font/woff"
        else:
            guess = "application/octet-stream"
    return "data:%s;base64,%s" % (guess, base64.b64encode(raw).decode("ascii"))


def note(kind, what, size=None, why=None):
    entry = what if size is None else "%s  [%s]" % (what, human(size))
    if why:
        entry += "  (%s)" % why
    if entry not in report[kind]:
        report[kind].append(entry)


def human(n):
    for unit in ("b", "KB", "MB"):
        if n < 1024 or unit == "MB":
            return "%.0f%s" % (n, unit) if unit == "b" else "%.1f%s" % (n, unit)
        n /= 1024.0


def prune_subsets(css, keep):
    """Google Fonts splits each family by unicode-range, one @font-face per script,
    each preceded by a /* subset */ comment. Keeping only the scripts a page uses is
    most of the saving on a family with Cyrillic and Vietnamese cuts."""
    if not keep:
        return css
    blocks = re.split(r"(/\*\s*[a-z0-9\-\[\] ]+\s*\*/)", css)
    out, current = [], None
    for chunk in blocks:
        m = re.match(r"/\*\s*([a-z0-9\-\[\] ]+?)\s*\*/", chunk)
        if m:
            current = m.group(1)
            continue
        if current is None or current in keep:
            out.append(chunk)
    return "".join(out) if out else css


def inline_css_urls(css, base_url, base_dir):
    """Rewrite every url(...) inside a stylesheet. Fonts and background images both
    land here, and a relative one has to resolve against the stylesheet, not the page."""
    def repl(m):
        quote, raw = m.group(1), m.group(2).strip()
        if raw.startswith("data:") or raw.startswith("#"):
            return m.group(0)
        target = urllib.parse.urljoin(base_url, raw) if base_url else raw
        try:
            blob = load(target, base_dir)
            if blob is None:
                return m.group(0)
            note("inlined", target, len(blob))
            return "url(%s%s%s)" % (quote, data_uri(blob, target), quote)
        except Exception as e:
            note("failed", target, why=str(e)[:70])
            return m.group(0)
    return re.sub(r"url\((['\"]?)([^)'\"]+)\1\)", repl, css)


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: inline.py <input.html> <output.html> [--subsets latin,latin-ext]")
    src_path, out_path = sys.argv[1], sys.argv[2]
    keep = {"latin", "latin-ext"}
    for i, a in enumerate(sys.argv):
        if a == "--subsets" and i + 1 < len(sys.argv):
            keep = {s.strip() for s in sys.argv[i + 1].split(",") if s.strip()}
        if a == "--all-subsets":
            keep = None

    base_dir = os.path.dirname(os.path.abspath(src_path))
    with open(src_path, "r", encoding="utf-8") as f:
        html = f.read()
    before = len(html.encode("utf-8"))

    # ---- stylesheets ----
    def do_link(m):
        tag, href = m.group(0), m.group(1)
        if "stylesheet" not in tag.lower():
            return tag
        try:
            raw = load(href, base_dir)
            if raw is None:
                return tag
            css = raw.decode("utf-8", "replace")
            if "fonts.googleapis.com" in href:
                css = prune_subsets(css, keep)
            css = inline_css_urls(css, href, base_dir)
            note("inlined", href, len(raw))
            return "<style>\n%s\n</style>" % css
        except Exception as e:
            note("failed", href, why=str(e)[:70])
            return tag
    html = re.sub(r"<link\b[^>]*?href=[\"']([^\"']+)[\"'][^>]*>", do_link, html, flags=re.I)

    # ---- scripts ----
    def do_script(m):
        tag, src = m.group(0), m.group(1)
        try:
            raw = load(src, base_dir)
            if raw is None:
                return tag
            js = raw.decode("utf-8", "replace")
            # A closing tag inside the source ends the block early and the rest of the
            # page becomes text. This is the classic way an inlined bundle breaks a page.
            js = js.replace("</script", "<\\/script")
            attrs = ""
            if re.search(r'type=["\']module["\']', tag, re.I):
                attrs = ' type="module"'
            note("inlined", src, len(raw))
            return "<script%s>\n%s\n</script>" % (attrs, js)
        except Exception as e:
            note("failed", src, why=str(e)[:70])
            return tag
    html = re.sub(r"<script\b[^>]*?\bsrc=[\"']([^\"']+)[\"'][^>]*>\s*</script>",
                  do_script, html, flags=re.I)

    # ---- media, in src and in srcset ----
    def do_src(m):
        whole, attr, url = m.group(0), m.group(1), m.group(2)
        if url.startswith("data:") or url.startswith("#"):
            return whole
        try:
            blob = load(url, base_dir)
            if blob is None:
                return whole
            note("inlined", url, len(blob))
            return whole.replace(url, data_uri(blob, url))
        except Exception as e:
            note("failed", url, why=str(e)[:70])
            return whole
    html = re.sub(r"<(?:img|source|video|audio|track|embed)\b[^>]*?\b(src|poster)="
                  r"[\"']([^\"']+)[\"']", do_src, html, flags=re.I)
    if re.search(r"\bsrcset=", html, re.I):
        note("skipped", "srcset attributes left alone", why="the src fallback carries the image")

    # ---- url() in page level <style> blocks and style attributes ----
    def do_style_block(m):
        return "<style%s>%s</style>" % (m.group(1), inline_css_urls(m.group(2), None, base_dir))
    html = re.sub(r"<style([^>]*)>(.*?)</style>", do_style_block, html, flags=re.I | re.S)

    # ---- what is still reaching outside ----
    leftovers = []
    for m in re.finditer(r"(?:\bsrc|\bhref)=[\"'](https?://[^\"']+)[\"']", html, re.I):
        tag_start = html.rfind("<", 0, m.start())
        tag = html[tag_start:m.start()].lower()
        # A link to a web page is content. A link to a resource the page needs is a dependency.
        if tag.startswith("<a ") or tag.startswith("<area "):
            continue
        leftovers.append(m.group(1))
    for m in re.finditer(r"url\(['\"]?(https?://[^)'\"]+)", html, re.I):
        leftovers.append(m.group(1))
    for m in re.finditer(r"@import\s+(?:url\()?['\"]?(https?://[^)'\";]+)", html, re.I):
        leftovers.append(m.group(1))

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)
    after = len(html.encode("utf-8"))

    print("=== INLINE REPORT ===")
    print("in:   %s  [%s]" % (src_path, human(before)))
    print("out:  %s  [%s]" % (out_path, human(after)))
    for kind, label in (("inlined", "INLINED"), ("skipped", "SKIPPED"), ("failed", "FAILED")):
        if report[kind]:
            print("\n--- %s ---" % label)
            for line in report[kind]:
                print("  " + line)
    print("\n--- STILL REACHING OUTSIDE ---")
    if leftovers:
        for u in sorted(set(leftovers)):
            print("  " + u)
        print("\n  Not a single file yet. Every line above is a dependency the reader needs a network for.")
    else:
        print("  nothing. Every dependency is in the file.")
    print("=== END REPORT ===")
    sys.exit(2 if (leftovers or report["failed"]) else 0)


if __name__ == "__main__":
    main()
