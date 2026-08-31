"""Domain normalization and suppression-list handling."""

from __future__ import annotations

import csv
import ipaddress
import re
from pathlib import Path
from typing import Iterable
from urllib.parse import urlsplit


DOMAIN_COLUMNS = ("domain", "website", "company domain", "company_domain", "url")
HOST_LABEL = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")


def normalize_domain(value: str) -> str:
    """Return a conservative registrable-looking hostname or an empty string."""
    text = (value or "").strip().lower()
    if not text:
        return ""
    parsed = urlsplit(text if "://" in text else "//" + text)
    host = (parsed.hostname or "").strip().rstrip(".")
    if host.startswith("www."):
        host = host[4:]
    try:
        host = host.encode("idna").decode("ascii")
    except UnicodeError:
        return ""
    if len(host) > 253 or "." not in host:
        return ""
    try:
        ipaddress.ip_address(host)
        return ""
    except ValueError:
        pass
    labels = host.split(".")
    if any(not HOST_LABEL.fullmatch(label) for label in labels):
        return ""
    if len(labels[-1]) < 2:
        return ""
    return host


def suppression_set(values: Iterable[str]) -> set[str]:
    """Normalize and deduplicate a sequence of possible domains."""
    domains: set[str] = set()
    for value in values:
        domain = normalize_domain(value)
        if domain:
            domains.add(domain)
    return domains


def load_domains_from_csv(path: Path) -> set[str]:
    """Load domains from a named domain/website column."""
    with Path(path).open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"CSV has no header: {path}")
        by_lower = {name.strip().lower(): name for name in reader.fieldnames}
        source_column = next((by_lower[name] for name in DOMAIN_COLUMNS if name in by_lower), None)
        if source_column is None:
            raise ValueError(
                f"CSV needs one of these columns: {', '.join(DOMAIN_COLUMNS)}"
            )
        return suppression_set(row.get(source_column, "") for row in reader)


def load_domains_from_text(path: Path) -> set[str]:
    """Load one domain per line; blank lines and comments are ignored."""
    values = []
    for line in Path(path).read_text(encoding="utf-8-sig").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            values.append(stripped)
    return suppression_set(values)


def write_suppression_csv(path: Path, values: Iterable[str]) -> int:
    """Write a stable one-column suppression baseline and return its row count."""
    domains = sorted(suppression_set(values))
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    text = "domain\n" + "".join(f"{domain}\n" for domain in domains)
    target.write_text(text, encoding="utf-8", newline="")
    return len(domains)
