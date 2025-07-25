import time
import feedparser
import json
from pathlib import Path
import logging
import re
import requests
from datetime import datetime, timezone
import os

BASE_DIR = Path(__file__).parent
CONFIG_FILE = BASE_DIR / "config.json"
STATE_FILE = BASE_DIR / "seen.json"

# Ensure log directory exists
LOG_DIR = Path("/var/log/pingtube")
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "pingtube.log"

STATS_DIR = BASE_DIR / "stats"

# Setup logging (no internal rotation!)
logger = logging.getLogger("pingtube")
logger.setLevel(logging.INFO)
file_handler = logging.FileHandler(LOG_FILE)
formatter = logging.Formatter('%(asctime)s - %(message)s')
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

def log(msg: str):
    print(msg)
    logger.info(msg)

def safe_filename(url: str) -> str:
    return re.sub(r'[^A-Za-z0-9]+', '_', url)

def load_config():
    if not CONFIG_FILE.exists():
        raise FileNotFoundError(f"Missing config file: {CONFIG_FILE}")
    return json.loads(CONFIG_FILE.read_text())

def load_seen():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}

def save_seen(seen):
    STATE_FILE.write_text(json.dumps(seen, indent=2))

def migrate_seen(seen):
    """Convert old seen.json format (list of ids) to new format"""
    changed = False
    for url, value in list(seen.items()):
        if isinstance(value, list):
            log(f"Migrating old seen.json format for {url}")
            seen[url] = {
                "first_seen": datetime.now(timezone.utc).isoformat(),
                "seen_ids": value
            }
            changed = True
    if changed:
        save_seen(seen)
    return seen

def load_stats(feed_url: str):
    STATS_DIR.mkdir(exist_ok=True)
    stats_file = STATS_DIR / f"{safe_filename(feed_url)}.json"
    if stats_file.exists():
        return stats_file, json.loads(stats_file.read_text())
    return stats_file, {"videos_detected": 0}

def save_stats(stats_file: Path, stats: dict):
    stats_file.write_text(json.dumps(stats, indent=2))

def post_to_discord(webhook_url: str, title: str, link: str):
    payload = {"content": f"**New video:** {title}\n{link}"}
    try:
        r = requests.post(webhook_url, json=payload, timeout=10)
        if r.status_code >= 300:
            log(f"Discord webhook error {r.status_code}: {r.text}")
    except Exception as e:
        log(f"Discord webhook exception: {e}")

def ensure_feed_state(seen: dict, url: str):
    """Ensure feed state exists with first_seen and seen_ids."""
    if url not in seen:
        ts = datetime.now(timezone.utc).isoformat()
        log(f"Registering new feed {url}, first_seen={ts}")
        seen[url] = {
            "first_seen": ts,
            "seen_ids": []
        }

def parse_published(entry):
    if hasattr(entry, "published_parsed") and entry.published_parsed:
        return datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
    return None

def check_feed(url: str, state: dict, webhook_url: str = None):
    feed = feedparser.parse(url)
    new_ids = []
    first_seen_dt = datetime.fromisoformat(state["first_seen"])
    seen_ids = state["seen_ids"]

    for entry in reversed(feed.entries):
        published = parse_published(entry)
        if not published:
            continue

        if published < first_seen_dt:
            continue

        if entry.id not in seen_ids:
            msg = f"[NEW VIDEO] {entry.title} - {entry.link}"
            log(msg)
            new_ids.append(entry.id)
            seen_ids.append(entry.id)
            if webhook_url:
                post_to_discord(webhook_url, entry.title, entry.link)

    return new_ids

def main():
    config = load_config()
    interval = config.get("interval_seconds", 300)
    feeds = config.get("feeds", [])
    webhook_url = config.get("discord_webhook_url")

    seen = migrate_seen(load_seen())

    log(f"Starting pingtube. Interval: {interval}s. Feeds: {len(feeds)}")
    while True:
        for url in feeds:
            ensure_feed_state(seen, url)
            state = seen[url]
            new_ids = check_feed(url, state, webhook_url)

            if new_ids:
                stats_file, stats = load_stats(url)
                stats["videos_detected"] += len(new_ids)
                save_stats(stats_file, stats)

        save_seen(seen)
        log(f"Waiting {interval} seconds...")
        time.sleep(interval)

if __name__ == "__main__":
    main()
