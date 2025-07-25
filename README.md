# PingTube

**PingTube** is a lightweight Python service that monitors YouTube channels via their RSS feeds and automatically posts new video links to a Discord webhook.

It is designed for self-hosting on Linux and runs as a systemd service.

---

## Features

- Monitors any number of YouTube RSS feeds
- Posts new uploads to a Discord webhook
- Keeps track of what has already been posted (no duplicates)
- Ignores all videos published before the service was started
- Saves basic statistics about detected videos
- Simple JSON configuration
- Runs as a background service on Linux

---

## Tested environment

PingTube has so far only been tested on **Ubuntu 24.04**.  
It should work on other Debian/Ubuntu-based systems, but this has not been verified.

---

## How it works

1. On the first run, PingTube records the current time for each feed (`first_seen`).
2. It **never posts videos published before that time**.
3. Every interval (default 5 minutes), it checks the feeds and posts links to any new videos published since `first_seen`.
4. Detected videos are logged to a file and stored in `seen.json`.

---

## Requirements

- Python 3.8+
- `pip` and `venv`
- Linux with `systemd`
- A **Discord webhook** (see below)

---

## Discord webhook

PingTube uses a Discord webhook to send messages to a channel.  
To create one:
1. Go to your Discord server settings
2. Choose **Integrations → Webhooks**
3. Create a webhook, copy the webhook URL, and paste it into your `config.json`

---

## Configuration

The configuration file is `config.json`, located in the same folder as `pingtube.py`.  
Example:

```json
{
  "interval_seconds": 300,
  "discord_webhook_url": "https://discord.com/api/webhooks/....",
  "feeds": [
    "https://www.youtube.com/feeds/videos.xml?channel_id=UCxxxx",
    "https://www.youtube.com/feeds/videos.xml?channel_id=UCyyyy"
  ]
}
```
- **interval_seconds**: how often (in seconds) feeds are checked
- **discord_webhook_url**: Discord webhook to post messages
- **feeds**: list of RSS URLs (one per channel)

## Helper script: youtube_channel_rss.sh
To easily get the correct RSS feed URL for a YouTube channel, use:<br>
`./youtube_channel_rss.sh`<br>
It will ask for a YouTube channel URL (such as `https://www.youtube.com/@LinusTechTips`)
and return something like:
```yaml
Channel ID : UCXuqSBlHAE6Xw-yeJA0Tunw
RSS feed   : https://www.youtube.com/feeds/videos.xml?channel_id=UCXuqSBlHAE6Xw-yeJA0Tunw
```
You can then copy the RSS feed URL and paste it into the feeds list in your config.json.

## Installation as a service
An install script is provided: `install_pingtube_service.sh`.

Before running it, **edit the script and set the `USER_NAME` variable** to the Linux user that should run the service.<br>
This user will own the files in `/opt/pingtube` and the logs in `/var/log/pingtube`.

Run:
```bash
chmod +x install_pingtube_service.sh
./install_pingtube_service.sh
```

This will:
- Create /opt/pingtube
- Create a Python virtual environment and install dependencies
- Set up a systemd service (pingtube.service)
- Create a log directory /var/log/pingtube
- Add a logrotate configuration
- Enable and start the service

## Logs

Logs are stored in:<br>
`/var/log/pingtube/pingtube.log`<br>
and rotated automatically by `logrotate`.<br>

Follow logs live with:<br>
`sudo journalctl -u pingtube.service -f`

## State and statistics
- `seen.json`: tracks which videos have been posted
- `stats/`: stores simple JSON stats files with counts

## Updating feeds

To add a new YouTube channel:
1. Use the helper script `youtube_channel_rss.sh` to get the correct RSS URL
2. Add the resulting RSS URL to `config.json`
3. Restart the service:
`sudo systemctl restart pingtube.service`

## About this project
This is a very small tool I made for my own use as a **Linux administrator**.<br>
I am **not a developer**, and this was just a small side project to solve a simple problem.<br>
I do not plan to add many features or maintain it as a full software project.

Feel free to use it if it solves your problem, or ignore it if it doesn't.<br>
Pull requests or suggestions are welcome, but this is meant to be a simple, no-fuss solution.

## Why "PingTube"?
It "pings" Discord with new YouTube uploads.

I originally tried some existing software for this task, but I couldn’t get any of them to work.<br>
So I built this for fun and to help out a friend who needed a simple solution.

## License
This is free and unencumbered software released into the public domain.<br>
For more information, please refer to <https://unlicense.org/>

