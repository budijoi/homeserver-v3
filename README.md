# My Home Server v3

Self Hosted di STB Bekas - STB B860H v1 | Amlogic S905X | 1GB RAM | Armbian

## Status
**EMMC Rusak** - Semua data dan aplikasi akan disimpan pada **SDCARD**

## Fitur

| Komponen | Pilihan | Port |
|----------|---------|------|
| **Dashboard Monitor** | Web monitor dengan grafik Chart.js real-time | 80/5000 |
| **Micro Blog** | Ghost / WriteFreely / Liveblog | 2368 / 8082 / 8083 |
| **File Manager** | FileBrowser / FileGator / FileRise | 8080 / 8084 / 8085 |
| **CCTV NVR** | Shinobi / MotionEye / Frigate | 8081 / 8765 / 5000 |
| **Cloudflared** | Cloudflare Tunnel | - |
| **TTYD + BTOP** | Terminal monitoring via browser | 7681 |

## Login Default

- **User**: admin
- **Password**: admin12345678

## Cara Penggunaan

```bash
sudo bash install.sh
```

Atau instal semua komponen sekaligus:

```bash
sudo bash install.sh --auto
```

## Optimasi Sistem

- ZRAM 512MB (algoritma zstd)
- SWAP File 1GB
- CPU Governor: Performance
- BBR TCP Congestion Control
- Firewall UFW (SSH, HTTP, HTTPS, Dashboard)

## Sosial Media

- Facebook: budijoiBBJ
- Instagram: budijoi_eco
- Threads: budijoi_eco
- X: budijoi
- Github: budijoi

## Donasi

- DANA: 085323073037
- Bank Mandiri: 1310014031126
- Bank BNI: 2027537451
- Konfirmasi: +6288224553181
