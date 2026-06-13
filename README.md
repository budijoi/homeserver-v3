# My Home Server v3

Self Hosted di STB Bekas — STB B860H v1 | Amlogic S905X | 1GB RAM | Armbian

**EMMC Rusak** → Semua data dan aplikasi disimpan di **SDCARD**

---

## 📋 Informasi Script

| Item | Detail |
|------|--------|
| **File** | `install.sh` |
| **Versi** | 3.1 |
| **Ukuran** | ~85 KB (1781 baris) |
| **OS** | Armbian (Amlogic S905X) |
| **Device** | STB B860H v1 |
| **RAM** | 1 GB |
| **Storage** | SDCARD (EMMC rusak) |
| **Log** | `/var/log/homeserver-install.log` |
| **Author** | Budi Joi |

### Komponen (diurutkan dari paling penting)

| # | Komponen | Pilihan | Port |
|---|----------|---------|------|
| 1 | **Optimasi Sistem** | ZRAM 512MB + SWAP 1GB + S905X tuning | — |
| 2 | **Dashboard Monitor** | Grafik Chart.js real-time, navigasi layanan | 80/5000 |
| 3 | **File Manager** | FileBrowser / FileGator / FileRise | 8080/8084/8085 |
| 4 | **CCTV NVR** | Shinobi / MotionEye / Frigate | 8081/8765/8971 |
| 5 | **Micro Blog** | Ghost / WriteFreely / Liveblog | 2368/8082/8083 |
| 6 | **Cloudflared** | Cloudflare Tunnel | — |
| 7 | **TTYD + BTOP** | Terminal monitoring via browser | 7681 |

### Login Default

| Aplikasi | User | Password |
|----------|------|----------|
| Dashboard | — | — |
| FileBrowser | `admin` | `admin12345678` |
| FileGator | `admin` | `admin123` |
| FileRise | (buat baru) | — |
| Shinobi | (setup `/super`) | — |
| MotionEye | `admin` | `admin12345678` |
| Frigate | (auto-generate) | cek `docker logs frigate` |
| Ghost | (setup `/ghost`) | — |
| WriteFreely | (register baru) | — |
| Liveblog | — | — |
| BTOP/TTYD | `admin` | `admin12345678` |

### Fitur Dashboard

- Grafik real-time CPU, RAM, ZRAM, SWAP, Disk, Network (Chart.js)
- Status bar: CPU Load, Temperature, Jumlah Proses, SDCARD
- Status service online/offline untuk semua layanan
- Navigasi cepat: Blog, File Manager, NVR, BTOP Terminal, GitHub
- Sosial media: Facebook, Instagram, Threads, X, Github
- Popup donasi: DANA, Mandiri, BNI, QRIS, konfirmasi WhatsApp

---

## 🚀 Tutorial Instalasi

### Persyaratan

- STB B860H v1 (Amlogic S905X) dengan Armbian
- Koneksi internet stabil
- SDCARD minimal 8 GB (direkomendasikan 16 GB+)
- Akses root (`sudo`)

### Langkah Instalasi

#### 1. Download Script

```bash
git clone https://github.com/budijoi/homeserver-v3.git
cd homeserver-v3
```

Atau download langsung:

```bash
wget -O install.sh https://raw.githubusercontent.com/budijoi/homeserver-v3/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

#### 2. Beri Izin & Jalankan

```bash
chmod +x install.sh
sudo ./install.sh
```

Untuk instalasi semua komponen sekaligus (tanpa menu):

```bash
sudo ./install.sh --auto
```

#### 3. Pilih Menu

Script akan menampilkan menu interaktif:

```
  Pilih komponen (diurutkan dari yang paling penting):
   1)  Optimasi Sistem      (WAJIB - ZRAM, SWAP, tuning)
   2)  Dashboard Monitor    (Grafik real-time, navigasi)
   3)  File Manager         (FileBrowser/FileGator/FileRise)
   4)  CCTV NVR             (Shinobi/MotionEye/Frigate)
   5)  Micro Blog           (Ghost/WriteFreely/Liveblog)
   6)  Cloudflared          (Cloudflare Tunnel)
   7)  TTYD + BTOP          (Terminal via browser)
   8)  INSTAL ALL-IN-ONE    (Semua komponen)
   0)  Keluar
```

#### 4. Akses Dashboard

Setelah instalasi selesai, buka browser:

```
http://<IP-ADDRESS-STB>
```

Cari IP dengan:

```bash
hostname -I
```

---

## 🔧 Troubleshooting

### Cek status service

```bash
systemctl status homeserver-dashboard
systemctl status filebrowser
systemctl status ttyd
```

### Cek Docker container

```bash
docker ps -a
docker logs <container-name>
```

### Cek log instalasi

```bash
cat /var/log/homeserver-install.log | tail -50
```

### Restart semua service

```bash
systemctl restart homeserver-dashboard filebrowser ttyd
systemctl restart nginx
```

---

## 📁 Struktur Folder

```
/home/storage/                 # Data utama di SDCARD
├── My Document/
├── My Music/
├── My Pictures/
├── My Videos/
│   └── NVR/                  ← Rekaman CCTV
├── ghost/                    ← Data Ghost CMS
├── writefreely/              ← Data WriteFreely
├── liveblog/                 ← Data Liveblog
├── filerise/                 ← Data FileRise
│   ├── uploads/
│   ├── users/
│   └── metadata/
├── shinobi/                  ← Data Shinobi
│   ├── config/
│   └── mysql/
├── frigate/                  ← Data Frigate
│   └── config/
├── filebrowser-db/           ← DB FileBrowser
├── filebrowser-config/       ← Config FileBrowser
├── filegator-repo/           ← Repository FileGator
└── swapfile                  ← SWAP file 1GB
```

---

## 📡 Port Map

| Port | Layanan |
|------|---------|
| 22 | SSH |
| 80 | Dashboard (Nginx) |
| 443 | HTTPS (cadangan) |
| 2368 | Ghost Blog |
| 5000 | Dashboard (Flask internal) |
| 7681 | TTYD / BTOP Terminal |
| 8080 | FileBrowser |
| 8081 | Shinobi NVR |
| 8082 | WriteFreely |
| 8083 | Liveblog |
| 8084 | FileGator |
| 8085 | FileRise |
| 8554 | Frigate RTSP |
| 8765 | MotionEye NVR |
| 8971 | Frigate NVR |

---

## ⚙️ Optimasi

| Optimasi | Detail |
|----------|--------|
| **ZRAM** | 512MB, kompresi zstd, prioritas 100 |
| **SWAP** | 1GB file di SDCARD |
| **CPU** | Performance governor |
| **BBR** | TCP congestion control |
| **Firewall** | UFW: SSH, HTTP, HTTPS, Dashboard |
| **sysctl** | swappiness=60, dirty_ratio=20, BBR aktif |

---

## ⚠️ Catatan Penting

- **Armbian wajib** — Script didesain untuk Armbian di STB S905X
- **EMMC rusak** — Pastikan SDCARD terpasang dengan ruang cukup
- **Frigate** — Membutuhkan RAM besar (~512MB+). Tanpa Google Coral TPU, AI detection via CPU akan lambat
- **Shinobi** — Image dari GitLab registry, mungkin butuh waktu download
- **FileGator** — Login default `admin/admin123`, ubah password setelah instalasi
- **Ghost** — Setup admin dilakukan saat pertama akses
- **Semua service** — Akan aktif otomatis saat STB boot (systemd enabled)
