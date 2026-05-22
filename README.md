<p align="center">
  <img src="assets/logo.png" width="300" />
</p>

# i-cherri

<p align="center">
  <b>English</b> | 
  <a href="README.ko.md">한국어</a>
</p>

**i-cherri** is a macOS (and other OS) local LAN backup solution designed to secure, speed up, and streamline the backup of iPhone photos and videos.  
It utilizes a high-speed wired connection for initial bulk backups, followed by **one-way incremental backups from iOS to Mac** using a [Cherri](https://cherrilang.org/)-based iOS Shortcut for daily data synchronization.

---

## 🍒 Key Features

- **One-Way Incremental Backup**: Only new media files from your iPhone are sent to the server. Server-side modifications will not affect the data on your iPhone, ensuring a secure workflow.
- **Multi-Platform Server**: The server engine is written in Go, allowing it to run on macOS, Linux, and Windows (macOS is currently the primary target).
- **High-Speed Initial Backup**: Directly copy files by connecting your iPhone to your Mac via USB, then immediately sync the status using SQLite indexing (`--reindex`).
- **Smart Incremental Sync**: The iOS Shortcut compiled by Cherri analyzes media files from the last 3 days, communicates with the server, and uploads only the missing files.
- **Data Integrity**: SHA-256 hash-based deduplication completely prevents identical files from being uploaded twice.
- **Lightweight Architecture**: A single binary server written in Go combined with SQLite minimizes system resource usage.

---

## 🔒 Security Precondition (Must-Read)

For simplicity and maximum performance, i-cherri does not include a separate authentication layer. You must strictly adhere to the following security guidelines:

- **Local LAN Only**: Use only within trusted home/office Wi-Fi networks.
- **No Exposure**: Never expose the server to the public internet, port forwarding, or Cloudflare Tunnels (`cloudflared`).
- **Trusted Environments**: Avoid running the sync on public Wi-Fi networks in libraries, cafes, or schools.

---

## 🛠 Components

- [main.go](main.go): High-performance Go HTTP server and indexing engine
- [iphone_daily_backup.cherri](iphone_daily_backup.cherri): Cherri-based iOS incremental backup source
- [com.local.i-cherri.plist.template](com.local.i-cherri.plist.template): macOS launchd auto-run template
- [Makefile](Makefile): Workflow automation for building and management

---

## 📋 Prerequisites

To build and run i-cherri, you need the following environment:

- **OS**: macOS (optimized for launchd and iOS Shortcut integration)
- **Go**: Version 1.20 or higher
- **Cherri CLI**: Required to compile and sign iOS Shortcut source files (`.cherri`) ([Installation Guide](https://cherrilang.org/language/))
- **Make**: Recommended for workflow automation

---

## 🚀 Getting Started

### 1. Initial Full Backup & Indexing

1. Connect your iPhone to your Mac via USB.
2. Directly copy photos/videos to your Mac's backup directory (default: `~/Photos`).
3. Organize the copied files into year-month folders (`YYYY-MM`) automatically:
   ```bash
   # Build the init CLI
   make init

   # Move and organize copied files into YYYY-MM folders
   ./dist/init <path_to_backup_directory>
   ```
   *Note: The server only recognizes files structured inside `YYYY-MM` directories.*
4. Build the database index:
   ```bash
   make reindex
   ```

### 2. Running the Server

Use `Makefile` to easily build and start the server:

```bash
# Build all components and run the server
make all
make run
```

Default server address: `http://localhost:8787`

---

## 📱 iOS Shortcut Configuration

### 1. Basic Setup
1. Import the signed `iPhone Daily Backup.shortcut` file onto your iPhone.
2. **Server IP Configuration**: In the Shortcut edit mode, you must change the server address variable at the top to your Mac's actual local IP (e.g., `http://192.168.0.10:8787`).

### 2. Automation Setup Guide
We recommend setting up the backup to run automatically at a specific time daily.
1. Open the **Shortcuts** app on your iPhone and tap the **Automation** tab at the bottom.
2. Tap the **+** button in the upper-right corner to create a new automation.
3. Select **Time of Day** (e.g., 3:00 AM, recommended to run while charging).
4. Set the execution condition to **Run Immediately** and disable 'Notify When Run' (Important for hands-free automation overnight).
5. On the next screen, select `iPhone Daily Backup` from **My Shortcuts**.
6. The backup will now run automatically at the scheduled time daily when connected to your home Wi-Fi.

---

## 📂 macOS Sharing Configuration for Initial Backup

If a wired connection is inconvenient, you can copy the initial large batch of files over the same Wi-Fi network using **macOS Shared Folders**.

### 1. Enable File Sharing on Mac
1. Go to `System Settings` > `General` > `Sharing`.
2. Toggle `File Sharing` to **On**, then click the `i` button next to it.
3. Tap the `+` button under the `Shared Folders` list and add your backup folder (e.g., `~/Photos`).
4. Ensure your account has `Read & Write` permissions.

### 2. Connect from iPhone
1. Open the **Files** app on your iPhone.
2. Tap the `...` button in the upper-right corner and select `Connect to Server`.
3. Enter your Mac's local IP address (e.g., `smb://192.168.0.10`).
4. Enter your Mac username and password to log in.
5. In the Photos app, select the media you want to back up, tap `Save to Files`, and choose the Mac shared folder.

---

## 📂 Directory Structure & DB

### Directory Structure Example
```text
~/Photos/
├── 2026-04/
├── 2026-05/
└── .i-cherri.sqlite3
```

### SQLite Schema
The server indexes and manages details such as the SHA-256 hash, original filename, creation date, size, etc.

```sql
CREATE TABLE files (
  sha256 TEXT NOT NULL UNIQUE,
  original_name TEXT,
  saved_path TEXT NOT NULL,
  created_at TEXT,
  file_size INTEGER NOT NULL,
  uploaded_at TEXT NOT NULL
);
```

---

## 📋 Management Commands (Makefile)

- `make all`: Build both the Go server and the Shortcut
- `make go`: Build only the Go server binary
- `make init`: Build only the init CLI
- `make shortcut`: Build only the Signed Shortcut
- `make reindex`: Re-index the photos library database
- `make run`: Rebuild Go binary and run the server in the background
- `make db-reset`: Clear database and re-index all files
- `make clean`: Remove all built artifacts

---

## 🗺️ Roadmap & Milestones

Roadmap for future improvements of i-cherri:

| Milestone | Target & Key Features | Expected Impact | Priority / Complexity | Components |
| :--- | :--- | :--- | :---: | :--- |
| **M1: Performance & Metadata** | <ul><li>Add `/check-batch` API</li><li>Server-side auto EXIF parsing</li><li>Large file streaming upload</li></ul> | Significantly improve shortcut execution speed (10x+), accurate shooting date tracking | **High** / Medium | Go Server, Cherri Shortcut |
| **M2: Multi-Device & Integrity** | <ul><li>Device identification & isolation</li><li>Live Photo image-video matching</li><li>Bit-rot detection via hash verification</li></ul> | Prevent backup confusion for multiple devices, integrate Live Photo management, data safety | **Medium** / Medium | Go Server, SQLite DB, Cherri |
| **M3: macOS Integration** | <ul><li>macOS Menu Bar App development</li><li>Local IP auto-discovery</li><li>`launchd` auto-install CLI</li></ul> | Better Shortcut configuration UX, real-time server status management | **Medium** / Medium | Go Server, macOS UI (systray) |
| **M4: Web Dashboard & UI** | <ul><li>Embedded dashboard UI</li><li>Media timeline grid view</li><li>Thumbnail caching & HEIC conversion</li></ul> | Visualized photo library, comfortable web browsing, faster loading times | **Low** / High | Go Server (embed), Frontend (HTML/JS) |

### 💡 M1 Hybrid Large Upload Architecture Detail
To overcome the iOS Shortcuts memory limit (OOM crash on HTTP POST), M1 defines the following hybrid transmission structure:

1. **Check First**: Before uploading, the Shortcut collects metadata (filename, creation date) and queries the Go server's `/check-batch` API in a single request to filter out already backed up media.
2. **Small Files (HTTP POST)**: Media files under 100MB are uploaded directly via HTTP POST `/upload` from the Shortcut.
3. **Large Files (SMB + Go Post-processing)**: Media files exceeding 100MB are copied to the server's temporary incoming directory (`.tmp/incoming/`) using the iOS native `Save File` action via SMB protocol. (iOS File app daemon handles streaming copy efficiently, preventing OOM).
4. **Migration & Indexing**: Once the copy is completed, the Shortcut triggers the Go server (or the server automatically detects it). The Go server calculates the SHA-256 hash of the temporary file, verifies it's not a duplicate, moves (Renames) it to the final `YYYY-MM` directory, and registers it in the SQLite DB. Duplicate files are purged immediately.

---

## 💬 API Reference

- `GET /health`: Check server status
- `POST /check`: Check duplicate files based on metadata
- `POST /upload`: Upload actual media files (includes SHA-256 duplicate verification)

---

Keep your precious memories local and safe with **i-cherri**! 🍒
