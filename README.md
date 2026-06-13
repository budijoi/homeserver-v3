# My Home Server v3

Self Hosted di STB Bekas — STB B860H v1 | Amlogic S905X | 1GB RAM | Armbian

**EMMC Rusak** → Semua data dan aplikasi disimpan di **SDCARD**

---

## 📋 Informasi Script

| Item | Detail |
|------|--------|
| **Nama** | `install.sh` |
| **Versi** | 3.0 |
| **Ukuran** | ~103 KB (2723 baris) |
| **OS Target** | Armbian (Amlogic S905X) |
| **Device** | STB B860H v1 |
| **RAM** | 1 GB |
| **Storage** | SDCARD (EMMC rusak) |
| **Bahasa** | Bash shell script |
| **Author** | Budi Joi |

### Isi Script

Script ini adalah **All-in-One Installer** yang mencakup:

1. **Optimasi Sistem** — ZRAM 512MB, SWAP 1GB, CPU Governor Performance, BBR TCP, firewall UFW
2. **Dashboard Monitor** — Web monitor dengan grafik Chart.js real-time, status CPU/RAM/ZRAM/SWAP/DISK/NETWORK
3. **Micro Blog** — Pilihan: Ghost CMS (Node.js), WriteFreely (Go), Liveblog (Python)
4. **File Manager** — Pilihan: FileBrowser, FileGator, FileRise
5. **CCTV NVR** — Pilihan: Shinobi, MotionEye, Frigate (dengan kamera IP 192.168.101.6)
6. **Cloudflared** — Cloudflare Tunnel untuk akses dari internet
7. **TTYD + BTOP** — Terminal monitoring via browser

### Fitur Dashboard

- Grafik garis real-time (Chart.js) untuk CPU, RAM, ZRAM, SWAP, Disk
- Status bar: CPU Load, Temperature, Jumlah Proses, SDCARD
- Status service (online/offline) untuk Blog, File Manager, NVR, BTOP
- Navigasi cepat ke semua layanan + GitHub repo
- Ikon sosial media: Facebook, Instagram, Threads, X, Github
- Popup donasi dengan DANA, Mandiri, BNI, QRIS, konfirmasi WhatsApp

### Login Default

Semua layanan menggunakan kredensial yang sama:

| Field | Value |
|-------|-------|
| **User** | `admin` |
| **Password** | `admin12345678` |

---

## 🚀 Tutorial Instalasi

### Persyaratan

- STB B860H v1 (Amlogic S905X)
- Sudah terinstal **Armbian** (minimal Ubuntu/Debian based)
- Koneksi internet stabil
- SDCARD dengan ruang kosong minimal **8 GB**
- Akses root (sudo)

### Langkah Instalasi

#### 1. Download Script

```bash
# Download langsung
wget -O install.sh https://raw.githubusercontent.com/budijoi/homeserver-v3/main/install.sh

# Atau Clone repositori
git clone https://github.com/budijoi/homeserver-v3.git
cd homeserver-v3
```

#### 2. Beri Izin Eksekusi

```bash
chmod +x install.sh
```

#### 3. Jalankan Script

```bash
sudo ./install.sh
```

Atau instal semua komponen sekaligus (tanpa menu):

```bash
sudo ./install.sh --auto
```

#### 4. Ikuti Petunjuk di Layar

Script akan menampilkan menu interaktif:

```
  ╔══════════════════════════════════════════════════════╗
  ║     My Home Server v3                               ║
  ║     STB B860H v1 | S905X | 1GB RAM                  ║
  ║     EMMC Rungkad - Semua di SDCARD!                 ║
  ╚══════════════════════════════════════════════════════╝

  Pilih komponen yang akan diinstal:

   1)  Optimasi Sistem      (ZRAM 512MB, SWAP 1GB, tuning S905X)
   2)  Dashboard Monitor    (Web monitor + Chart.js grafik real-time)
   3)  Micro Blog            (Ghost / WriteFreely / Liveblog)
   4)  File Manager          (FileBrowser / FileGator / FileRise)
   5)  CCTV NVR              (Shinobi / MotionEye / Frigate)
   6)  Cloudflared           (Cloudflare Tunnel)
   7)  TTYD + BTOP           (Terminal monitoring via browser)

   8)  INSTAL ALL-IN-ONE     (Instal semua komponen)

   0)  Keluar
```

#### 5. Akses Dashboard

Setelah instalasi selesai, buka browser dan akses:

```
http://<IP-ADDRESS-STB>
```

Cari IP address STB dengan:

```bash
ip addr show | grep inet
```

---

## 📡 Port Layanan

| Layanan | Port | URL |
|---------|------|-----|
| **Dashboard** | 80 / 5000 | `http://IP` |
| **Ghost Blog** | 2368 | `http://IP:2368` |
| **WriteFreely** | 8082 | `http://IP:8082` |
| **Liveblog** | 8083 | `http://IP:8083` |
| **FileBrowser** | 8080 | `http://IP:8080` |
| **FileGator** | 8084 | `http://IP:8084` |
| **FileRise** | 8085 | `http://IP:8085` |
| **Shinobi NVR** | 8081 | `http://IP:8081` |
| **MotionEye NVR** | 8765 | `http://IP:8765` |
| **Frigate NVR** | 5000 | `http://IP:5000` |
| **BTOP Terminal** | 7681 | `http://IP:7681` |

---

## 📁 Struktur Folder

```
/home/storage/
├── My Document/
├── My Music/
├── My Pictures/
├── My Videos/
│   └── NVR/              ← Rekaman CCTV
├── ghost/                ← Data Ghost CMS
├── writefreely/          ← Data WriteFreely
├── liveblog/             ← Data Liveblog
├── filegator/            ← Data FileGator
├── filerise/             → Data FileRise
├── shinobi/              ← Data Shinobi NVR
├── frigate/              ← Data Frigate NVR
└── swapfile              ← SWAP file 1GB
```

---

## ⚙️ Optimasi Sistem

| Optimasi | Detail |
|----------|--------|
| **ZRAM** | 512MB, algoritma zstd, prioritas 100 |
| **SWAP** | 1GB file di SDCARD |
| **CPU** | Performance governor |
| **BBR** | TCP congestion control aktif |
| **Firewall** | UFW: SSH (22), HTTP (80), HTTPS (443), Dashboard (5000) |
| **sysctl** | swappiness 60, cache pressure 50, dirty ratio 20 |

---

## ⚠️ Catatan

- Script ini dirancang khusus untuk **STB B860H v1 (S905X, 1GB RAM)**
- **EMMC rusak** → pastikan SDCARD terpasang dan memiliki cukup ruang
- Frigate membutuhkan **Google Coral TPU** untuk deteksi AI optimal
- Semua service akan aktif otomatis saat STB dinyalakan (systemd)
- Akses dashboard via browser di perangkat yang sama atau berbeda dalam satu jaringan

---

## 📜 Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan.
