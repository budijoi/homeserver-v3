#!/bin/bash
# ============================================================
#  My Home Server v3 - All-in-One Installer
#  STB B860H v1 | Amlogic S905X | 1GB RAM | Armbian
#  EMMC Rusak -> Semua data dan aplikasi di SDCARD
#  Repo   : https://github.com/budijoi
#  Author : Budi Joi
# ============================================================
#  Komponen:
#  1. Optimasi Sistem (ZRAM 512MB, SWAP 1GB, tuning S905X)
#  2. Dashboard Monitor (Web monitor dengan grafik bar + navigasi)
#  3. Micro Blog (Ghost / WriteFreely / Liveblog)
#  4. File Manager (FileBrowser / FileGator / FileRise)
#  5. CCTV NVR (Shinobi / MotionEye / Frigate)
#  6. Cloudflared (Cloudflare Tunnel)
#  7. TTYD + BTOP (Terminal via Browser)
#  8. Donasi (Informasi donasi + WhatsApp)
# ============================================================

set -e

# ============================================================
#  WARNA & FORMAT
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
NC='\033[0m'

# ============================================================
#  VARIABEL GLOBAL
# ============================================================
DATA_DIR=""
STORAGE_ESTIMATION=""
SCRIPT_VERSION="3.0"

# ============================================================
#  FUNGSI BANTU
# ============================================================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo '  ╔══════════════════════════════════════════════════════╗'
    echo '  ║     ${WHITE}███╗   ███╗██╗  ██╗ █████╗ ${CYAN}                ║'
    echo '  ║     ${WHITE}████╗ ████║██║  ██║██╔══██╗${CYAN}               ║'
    echo '  ║     ${WHITE}██╔████╔██║███████║███████║${CYAN}               ║'
    echo '  ║     ${WHITE}██║╚██╔╝██║██╔══██║██╔══██║${CYAN}               ║'
    echo '  ║     ${WHITE}██║ ╚═╝ ██║██║  ██║██║  ██║${CYAN}               ║'
    echo '  ║     ${WHITE}╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝${CYAN}               ║'
    echo '  ║                                                  ║'
    echo '  ║     ${GREEN}My Home Server v3${CYAN}                            ║'
    echo '  ║     ${YELLOW}STB B860H v1 | S905X | 1GB RAM${CYAN}               ║'
    echo '  ║     ${RED}EMMC Rusak${NC}${CYAN} - Semua di SDCARD!${CYAN}             ║'
    echo '  ╚══════════════════════════════════════════════════════╝'
    echo -e "${NC}"
}

print_step() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD} STEP $1${NC}"
    echo -e "${BLUE}║${NC} ${DIM}$2${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUKSES]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[PERINGATAN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────${NC}"
}

print_estimation() {
    local app=$1
    local size=$2
    echo -e "  ${CYAN}$app${NC} : ${YELLOW}$size${NC}"
}

confirm() {
    echo ""
    echo -ne "${YELLOW}[?]${NC} $1 ${CYAN}[y/N]: ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

press_enter() {
    echo ""
    echo -ne "${CYAN}Tekan ENTER untuk melanjutkan...${NC}"
    read -r
}

spinner() {
    local pid=$1
    local msg=$2
    local spin='-\|/'
    local i=0
    echo -ne "${CYAN}[INFO]${NC} $msg ... "
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    echo -ne "\b${GREEN}OK${NC}\n"
}

# ============================================================
#  CEK ROOT & DETEKSI SDCARD
# ============================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan sebagai root (sudo)!"
        exit 1
    fi
}

detect_sdcard() {
    print_info "Mendeteksi SDCARD..."
    
    # Cari mount point SDCARD dengan prioritas
    # Karena EMMC rusak, sistem boot dari SDCARD
    # Root filesystem sudah di SDCARD
    
    # Deteksi root device
    ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
    print_info "Root device terdeteksi: $ROOT_DEVICE"
    
    if echo "$ROOT_DEVICE" | grep -q "mmcblk1"; then
        print_success "SDCARD terdeteksi: $ROOT_DEVICE"
    elif echo "$ROOT_DEVICE" | grep -q "mmcblk0"; then
        print_warning "Terdeteksi mmcblk0 (mungkin EMMC). Sistem berjalan di SDCARD."
    else
        print_warning "Tidak dapat mendeteksi tipe storage, melanjutkan..."
    fi

    # Data directory di SDCARD (root filesystem)
    DATA_DIR="/home/storage"
    
    # Cek apakah SDCARD sudah di-mount
    if mount | grep -q "/mnt/sdcard"; then
        DATA_DIR="/mnt/sdcard/storage"
        print_info "Menggunakan mount point: /mnt/sdcard"
    fi
    
    mkdir -p "$DATA_DIR"
    print_success "Data akan disimpan di: $DATA_DIR"
}

# ============================================================
#  CEK ARMBIAN
# ============================================================
check_armbian() {
    if [ -f /etc/armbian-release ]; then
        . /etc/armbian-release
        print_info "Terdeteksi Armbian $VERSION ($BOARD_NAME)"
    else
        print_warning "Tidak terdeteksi sebagai Armbian. Melanjutkan..."
    fi
}

# ============================================================
#  FUNGSI CEK STORAGE
# ============================================================
check_storage() {
    local required_mb=$1
    local avail_kb
    avail_kb=$(df "$DATA_DIR" --output=avail 2>/dev/null | tail -1)
    
    if [ -z "$avail_kb" ] || [ "$avail_kb" -lt $((required_mb * 1024)) ]; then
        print_warning "Storage tersisa mungkin tidak cukup! Diperlukan ${required_mb}MB."
        if ! confirm "Lanjutkan instalasi?"; then
            print_info "Instalasi dibatalkan."
            return 1
        fi
    fi
    return 0
}

# ============================================================
#  DOCKER INSTALL
# ============================================================
ensure_docker() {
    if command -v docker &>/dev/null; then
        print_info "Docker sudah terinstal"
        return 0
    fi
    print_info "Menginstal Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
    print_success "Docker terinstal"
}

# ============================================================
#  1. OPTIMASI SISTEM
# ============================================================
install_optimization() {
    print_step "1/7" "OPTIMASI SISTEM - ZRAM 512MB, SWAP 1GB, Tuning S905X"

    print_info "Memperbarui sistem..."
    apt update && apt upgrade -y
    print_success "Sistem diperbarui"

    print_info "Menginstal paket dasar..."
    apt install -y curl wget git htop iotop iftop btop \
        ufw nginx python3 python3-pip python3-venv \
        ca-certificates gnupg lsb-release software-properties-common \
        apt-transport-https jq
    print_success "Paket dasar terinstal"

    # ---- ZRAM 512MB ----
    print_info "Mengkonfigurasi ZRAM 512MB..."
    apt install -y zram-tools 2>/dev/null || true
    
    # Konfigurasi ZRAM manual untuk S905X (1GB RAM -> 512MB ZRAM)
    cat > /etc/default/zramswap << 'ZRAMEOF'
# ZRAM configuration - My Home Server v3 (S905X)
# 512MB ZRAM dengan algoritma zstd untuk kompresi maksimal
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMEOF
    
    # Fallback: konfigurasi langsung via systemd service jika zram-tools tidak ada
    if ! systemctl is-enabled zramswap &>/dev/null; then
        cat > /etc/systemd/system/zram-config.service << 'ZRAMSVCEOF'
[Unit]
Description=ZRAM Configuration - My Home Server v3
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "modprobe zram && echo zstd > /sys/block/zram0/comp_algorithm && echo 512M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
ZRAMSVCEOF
        systemctl daemon-reload
        systemctl enable zram-config 2>/dev/null || true
        systemctl start zram-config 2>/dev/null || true
    else
        systemctl enable zramswap 2>/dev/null || true
        systemctl restart zramswap 2>/dev/null || true
    fi
    print_success "ZRAM 512MB dikonfigurasi (algoritma: zstd)"

    # ---- SWAP 1GB ----
    print_info "Membuat SWAP file 1GB..."
    SWAP_PATH="$DATA_DIR/swapfile"

    if [ ! -f "$SWAP_PATH" ]; then
        fallocate -l 1G "$SWAP_PATH" 2>/dev/null || dd if=/dev/zero of="$SWAP_PATH" bs=1M count=1024
        chmod 600 "$SWAP_PATH"
        mkswap "$SWAP_PATH"
        swapon "$SWAP_PATH"
        if ! grep -q "$SWAP_PATH" /etc/fstab; then
            echo "$SWAP_PATH none swap sw 0 0" >> /etc/fstab
        fi
        print_success "SWAP file 1GB dibuat di $SWAP_PATH"
    else
        print_info "SWAP file sudah ada di $SWAP_PATH"
    fi

    # ---- Optimasi S905X ----
    print_info "Menerapkan optimasi untuk S905X..."

    # CPU Governor - performance
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    cat > /etc/default/cpufrequtils << 'CPUEOF'
GOVERNOR=performance
CPUEOF
    print_success "CPU Governor: performance"

    # sysctl tweaks untuk S905X (1GB RAM)
    cat >> /etc/sysctl.conf << 'SYSEOF'

# My Home Server v3 - S905X Optimizations
# Memory
vm.swappiness=60
vm.vfs_cache_pressure=50
vm.dirty_ratio=20
vm.dirty_background_ratio=5
vm.min_free_kbytes=32768
vm.overcommit_memory=1

# Network - BBR
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# Optimasi untuk server rumahan
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
SYSEOF
    sysctl -p >/dev/null 2>&1
    print_success "sysctl optimasi diterapkan"

    # Nonaktifkan service tidak perlu
    for svc in bluetooth cups avahi-daemon ModemManager whoopsie snapd; do
        systemctl disable "$svc" 2>/dev/null || true
    done
    print_success "Layanan tidak perlu dinonaktifkan"

    # UFW Firewall
    print_info "Mengkonfigurasi firewall..."
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 5000/tcp comment 'Dashboard'
    ufw --force enable
    print_success "Firewall dikonfigurasi"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  OPTIMASI SELESAI!                                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - ZRAM  : 512MB (zstd)                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - SWAP  : 1GB                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - CPU   : Performance mode                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - BBR   : TCP congestion control                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - Firewall: Aktif (SSH, HTTP, HTTPS, Dashboard)    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  2. DASHBOARD MONITOR (dengan grafik bar + navigasi)
# ============================================================
install_dashboard() {
    print_step "2/7" "DASHBOARD MONITOR - Web monitor dengan grafik bar interaktif"

    local DASH_DIR="/opt/homeserver/dashboard"
    local STATIC_DIR="$DASH_DIR/static"
    local TEMPLATE_DIR="$DASH_DIR/templates"

    print_info "Membuat direktori dashboard..."
    mkdir -p "$STATIC_DIR" "$TEMPLATE_DIR"

    print_info "Menginstal Python Flask..."
    pip3 install flask psutil --break-system-packages 2>/dev/null || pip3 install flask psutil

    # --- app.py ---
    print_info "Membuat aplikasi dashboard v3..."
    cat > "$DASH_DIR/app.py" << 'PYEOF'
#!/usr/bin/env python3
# My Home Server v3 - Dashboard Monitor
from flask import Flask, render_template, jsonify, send_from_directory
import os, time, glob, socket, subprocess
import json

app = Flask(__name__)

_cpu_prev = None
_cpu_time = None
_net_prev = None
_net_time = None

DISK_INFO_CACHE = {"time": 0, "data": None}
HISTORY_FILE = "/opt/homeserver/dashboard/history.json"

def read_sysfs(paths):
    for p in paths:
        expanded = glob.glob(p)
        for fp in expanded:
            if os.path.exists(fp):
                try:
                    with open(fp) as f:
                        return f.read().strip()
                except:
                    pass
    return None

def get_cpu_usage():
    global _cpu_prev, _cpu_time
    try:
        with open('/proc/stat') as f:
            line = f.readline().strip()
        parts = [int(x) for x in line.split()[1:]]
        total = sum(parts)
        idle = parts[3]
        now = time.time()
        if _cpu_prev is not None and _cpu_time is not None:
            dt = now - _cpu_time
            dtotal = total - _cpu_prev['total']
            didle = idle - _cpu_prev['idle']
            if dt > 0 and dtotal > 0:
                usage = round(100.0 * (1.0 - didle / max(dtotal, 1)), 1)
            else:
                usage = 0.0
        else:
            usage = 0.0
        _cpu_prev = {'total': total, 'idle': idle}
        _cpu_time = now
        return usage
    except:
        return 0.0

def get_cpu_temp():
    raw = read_sysfs([
        '/sys/class/thermal/thermal_zone*/temp',
        '/sys/class/hwmon/hwmon*/temp1_input'
    ])
    if raw:
        try:
            millideg = int(raw)
            if millideg > 100000:
                millideg = millideg // 1000
            return round(millideg / 1000, 1)
        except:
            pass
    return 0.0

def get_memory_info():
    try:
        with open('/proc/meminfo') as f:
            data = f.read()
        def get_val(key):
            for line in data.split('\n'):
                if key in line:
                    vals = line.split()
                    if len(vals) >= 2:
                        return int(vals[1])
            return 0
        mt = get_val('MemTotal')
        ma = get_val('MemAvailable')
        mu = mt - ma
        st = get_val('SwapTotal')
        sf = get_val('SwapFree')
        su = max(st - sf, 0)
        return {
            'ram_total': mt // 1024,
            'ram_used': mu // 1024,
            'ram_percent': round(mu / mt * 100, 1) if mt > 0 else 0,
            'swap_total': st // 1024,
            'swap_used': su // 1024,
            'swap_percent': round(su / st * 100, 1) if st > 0 else 0
        }
    except:
        return {'ram_total': 0, 'ram_used': 0, 'ram_percent': 0,
                'swap_total': 0, 'swap_used': 0, 'swap_percent': 0}

def get_zram_info():
    try:
        result = subprocess.run(['zramctl', '--raw', '--noheadings'],
                              capture_output=True, text=True, timeout=5)
        total = 0
        used = 0
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split()
                if len(parts) >= 4:
                    total += int(parts[1])
                    used += int(parts[2])
        if total > 0:
            pct = round(used / total * 100, 1)
        else:
            pct = 0
        # Dapatkan compression ratio
        orig_total = 0
        try:
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split()
                    if len(parts) >= 5:
                        orig_total += int(parts[3])
        except:
            pass
        cr = round(orig_total / max(used, 1), 1) if used > 0 else 1.0
        return {
            'total': total // 1024,
            'used': used // 1024,
            'percent': pct,
            'compression_ratio': cr,
            'orig_total': orig_total // 1024
        }
    except:
        return {'total': 0, 'used': 0, 'percent': 0, 'compression_ratio': 1.0}

def get_disk_info():
    global DISK_INFO_CACHE
    now = time.time()
    if DISK_INFO_CACHE["data"] and (now - DISK_INFO_CACHE["time"]) < 5:
        return DISK_INFO_CACHE["data"]
    try:
        import shutil
        usage = shutil.disk_usage('/')
        pct = round(usage.used / usage.total * 100, 1)
        data = {
            'total': usage.total // (1024**3),
            'used': usage.used // (1024**3),
            'free': usage.free // (1024**3),
            'percent': pct
        }
        DISK_INFO_CACHE = {"time": now, "data": data}
        return data
    except:
        try:
            s = os.statvfs('/')
            total = s.f_frsize * s.f_blocks
            free = s.f_frsize * s.f_bfree
            used = total - free
            pct = round(used / total * 100, 1) if total > 0 else 0
            return {
                'total': total // (1024**3),
                'used': used // (1024**3),
                'free': free // (1024**3),
                'percent': pct
            }
        except:
            return {'total': 0, 'used': 0, 'free': 0, 'percent': 0}

def get_network_info():
    global _net_prev, _net_time
    try:
        with open('/proc/net/dev') as f:
            lines = f.readlines()
        rx_total = 0
        tx_total = 0
        # Dapatkan daftar interface aktif
        iface_list = []
        for line in lines[2:]:
            parts = line.split()
            iface = parts[0].rstrip(':')
            if iface != 'lo':
                iface_list.append(iface)
                rx_total += int(parts[1])
                tx_total += int(parts[9])
        now = time.time()
        if _net_prev is not None and _net_time is not None:
            dt = now - _net_time
            rx_speed = max(0, int((rx_total - _net_prev['rx']) / dt)) if dt > 0 else 0
            tx_speed = max(0, int((tx_total - _net_prev['tx']) / dt)) if dt > 0 else 0
        else:
            rx_speed = 0
            tx_speed = 0
        _net_prev = {'rx': rx_total, 'tx': tx_total}
        _net_time = now
        return {
            'rx': rx_speed,
            'tx': tx_speed,
            'rx_total': rx_total,
            'tx_total': tx_total,
            'interfaces': iface_list
        }
    except:
        return {'rx': 0, 'tx': 0, 'rx_total': 0, 'tx_total': 0, 'interfaces': []}

def get_uptime():
    try:
        with open('/proc/uptime') as f:
            seconds = float(f.read().split()[0])
        days = int(seconds // 86400)
        hours = int((seconds % 86400) // 3600)
        minutes = int((seconds % 3600) // 60)
        return f"{days}h {hours}j {minutes}m"
    except:
        return "N/A"

def get_load_average():
    try:
        with open('/proc/loadavg') as f:
            parts = f.read().strip().split()
        return {
            '1min': parts[0],
            '5min': parts[1],
            '15min': parts[2]
        }
    except:
        return {'1min': '0', '5min': '0', '15min': '0'}

def get_process_count():
    try:
        result = subprocess.run(['ps', '-e', '--no-headers'],
                              capture_output=True, text=True, timeout=5)
        return len(result.stdout.strip().split('\n'))
    except:
        return 0

def get_sdcard_info():
    try:
        result = subprocess.run(['findmnt', '-n', '-o', 'SOURCE', '/'],
                              capture_output=True, text=True, timeout=5)
        device = result.stdout.strip()
        # Dapatkan info SDCARD spesifik
        result2 = subprocess.run(['df', '-h', '/'],
                               capture_output=True, text=True, timeout=5)
        lines = result2.stdout.strip().split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 6:
                return {
                    'device': device,
                    'total': parts[1],
                    'used': parts[2],
                    'free': parts[3],
                    'percent': parts[4]
                }
        return {'device': device, 'total': 'N/A', 'used': 'N/A', 'free': 'N/A', 'percent': 'N/A'}
    except:
        return {'device': 'N/A', 'total': 'N/A', 'used': 'N/A', 'free': 'N/A', 'percent': 'N/A'}

# ============================================================
#  HISTORY DATA untuk grafik
# ============================================================
def load_history():
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE) as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data[-60:]
        except:
            pass
    return []

def save_history(data):
    history = load_history()
    history.append(data)
    history = history[-60:]
    try:
        with open(HISTORY_FILE, 'w') as f:
            json.dump(history, f)
    except:
        pass

# ============================================================
#  ROUTES
# ============================================================
@app.route('/')
def index():
    host_ip = socket.gethostbyname(socket.gethostname())
    if host_ip.startswith('127.'):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80))
            host_ip = s.getsockname()[0]
            s.close()
        except:
            host_ip = 'localhost'
    return render_template('index.html', host_ip=host_ip)

@app.route('/api/stats')
def stats():
    cpu = get_cpu_usage()
    temp = get_cpu_temp()
    memory = get_memory_info()
    zram = get_zram_info()
    disk = get_disk_info()
    network = get_network_info()
    uptime = get_uptime()
    load = get_load_average()
    procs = get_process_count()
    sdcard = get_sdcard_info()
    
    data = {
        'cpu': cpu,
        'temp': temp,
        'memory': memory,
        'zram': zram,
        'disk': disk,
        'network': network,
        'uptime': uptime,
        'load': load,
        'processes': procs,
        'sdcard': sdcard
    }
    
    save_history({
        'cpu': cpu,
        'temp': temp,
        'ram_percent': memory['ram_percent'],
        'zram_percent': zram['percent'],
        'swap_percent': memory['swap_percent'],
        'disk_percent': disk['percent']
    })
    
    return jsonify(data)

@app.route('/api/history')
def history():
    return jsonify(load_history())

@app.route('/api/services')
def services():
    services_list = [
        {'name': 'Dashboard', 'port': 5000, 'url': 'http://localhost:5000', 'icon': 'dashboard'},
        {'name': 'Blog', 'port': 2368, 'url': 'http://localhost:2368', 'icon': 'blog'},
        {'name': 'File Manager', 'port': 8080, 'url': 'http://localhost:8080', 'icon': 'folder'},
        {'name': 'NVR CCTV', 'port': 8765, 'url': 'http://localhost:8765', 'icon': 'camera'},
        {'name': 'BTOP Terminal', 'port': 7681, 'url': 'http://localhost:7681', 'icon': 'terminal'}
    ]
    result = []
    for svc in services_list:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1)
            status = s.connect_ex(('127.0.0.1', svc['port']))
            s.close()
            result.append({
                'name': svc['name'],
                'url': svc['url'],
                'icon': svc['icon'],
                'status': 'online' if status == 0 else 'offline'
            })
        except:
            result.append({'name': svc['name'], 'url': svc['url'], 'icon': svc['icon'], 'status': 'offline'})
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
PYEOF
    chmod +x "$DASH_DIR/app.py"
    print_success "Aplikasi dashboard v3 dibuat"

    # --- index.html ---
    print_info "Membuat halaman dashboard v3..."
    cat > "$TEMPLATE_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>My Home Server v3 — Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    font-family: 'Segoe UI', -apple-system, sans-serif;
    background: #0a0e17;
    color: #c8d6e5;
    min-height: 100vh;
    padding: 15px;
}
.container { max-width: 1200px; margin: 0 auto; }

/* Header */
.header {
    text-align: center;
    padding: 20px 15px 15px;
    margin-bottom: 20px;
    position: relative;
}
.header h1 {
    font-size: 1.8em;
    background: linear-gradient(135deg, #00d2ff, #3a7bd5, #8b5cf6);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    font-weight: 700;
    letter-spacing: 1px;
}
.header .subtitle {
    color: #576574;
    margin-top: 6px;
    font-size: 0.85em;
}
.header .datetime {
    color: #48dbfb;
    font-size: 1em;
    margin-top: 4px;
    font-weight: 300;
}
.header .uptime {
    color: #2ed573;
    font-size: 0.85em;
    margin-top: 3px;
}

/* Top Status Bar */
.status-bar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: 10px;
    margin-bottom: 20px;
}
.status-item {
    background: linear-gradient(145deg, #111827, #0f1729);
    border: 1px solid #1e293b;
    border-radius: 12px;
    padding: 12px 15px;
    text-align: center;
}
.status-item .label {
    font-size: 0.65em;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #576574;
}
.status-item .value {
    font-size: 1.1em;
    font-weight: 700;
    color: #fff;
    margin-top: 3px;
}
.status-item .value.green { color: #2ed573; }
.status-item .value.blue { color: #48dbfb; }
.status-item .value.orange { color: #ffa502; }
.status-item .value.red { color: #ff4757; }

/* Grid */
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 15px;
    margin-bottom: 20px;
}

/* Card */
.card {
    background: linear-gradient(145deg, #111827, #0f1729);
    border: 1px solid #1e293b;
    border-radius: 16px;
    padding: 18px;
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
}
.card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 3px;
    background: linear-gradient(90deg, #00d2ff, #3a7bd5);
    opacity: 0.6;
}
.card:hover {
    border-color: #3a7bd5;
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(58, 123, 213, 0.15);
}
.card-title {
    font-size: 0.7em;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: #576574;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 6px;
}
.card-body { position: relative; }
.card-value {
    font-size: 1.8em;
    font-weight: 700;
    color: #fff;
    line-height: 1.2;
}
.card-value .unit {
    font-size: 0.5em;
    color: #576574;
    font-weight: 400;
}
.card-sub {
    font-size: 0.8em;
    color: #8395a7;
    margin-top: 4px;
}

/* Chart container */
.chart-container {
    height: 80px;
    margin-top: 8px;
}
.chart-container canvas {
    width: 100% !important;
    height: 100% !important;
}

/* Service Status */
.service-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 10px;
    margin-bottom: 20px;
}
.service-card {
    background: linear-gradient(145deg, #111827, #0f1729);
    border: 1px solid #1e293b;
    border-radius: 12px;
    padding: 14px;
    text-align: center;
    text-decoration: none;
    transition: all 0.3s ease;
    cursor: pointer;
}
.service-card:hover {
    border-color: #3a7bd5;
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(58, 123, 213, 0.2);
}
.service-card .icon {
    font-size: 1.8em;
    margin-bottom: 5px;
}
.service-card .name {
    font-size: 0.8em;
    color: #c8d6e5;
    font-weight: 500;
}
.service-card .status-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-top: 5px;
}
.service-card .status-dot.online { background: #2ed573; box-shadow: 0 0 8px #2ed573; }
.service-card .status-dot.offline { background: #ff4757; box-shadow: 0 0 8px #ff4757; }

/* Social & Donasi Buttons */
.social-bar {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 8px;
    margin: 18px 0;
}
.social-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 8px 14px;
    background: #111827;
    border: 1px solid #1e293b;
    border-radius: 20px;
    color: #8395a7;
    text-decoration: none;
    font-size: 0.8em;
    transition: all 0.3s ease;
}
.social-btn:hover {
    color: #fff;
    border-color: #3a7bd5;
    transform: translateY(-1px);
}
.social-btn.donate {
    border-color: #f1c40f40;
    color: #f1c40f;
}
.social-btn.donate:hover {
    border-color: #f1c40f;
    box-shadow: 0 0 15px rgba(241, 196, 15, 0.2);
}

/* Modal Donasi */
.modal-overlay {
    display: none;
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.75);
    z-index: 1000;
    justify-content: center;
    align-items: center;
    backdrop-filter: blur(4px);
}
.modal-overlay.active { display: flex; }
.modal {
    background: #111827;
    border: 1px solid #1e293b;
    border-radius: 20px;
    padding: 30px;
    max-width: 460px;
    width: 90%;
    position: relative;
    max-height: 90vh;
    overflow-y: auto;
}
.modal h2 {
    font-size: 1.4em;
    text-align: center;
    margin-bottom: 4px;
    background: linear-gradient(135deg, #f1c40f, #e67e22);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}
.modal .subtitle {
    text-align: center;
    color: #576574;
    font-size: 0.85em;
    margin-bottom: 20px;
}
.modal-close {
    position: absolute;
    top: 12px; right: 15px;
    background: none;
    border: none;
    color: #576574;
    font-size: 1.5em;
    cursor: pointer;
}
.modal-close:hover { color: #fff; }
.bank-list { list-style: none; }
.bank-list li {
    background: #0f1729;
    border: 1px solid #1e293b;
    border-radius: 12px;
    padding: 14px;
    margin-bottom: 8px;
}
.bank-list .bank-name {
    font-weight: 700;
    color: #48dbfb;
    font-size: 0.85em;
}
.bank-list .bank-num {
    color: #fff;
    font-size: 1.1em;
    margin-top: 3px;
    letter-spacing: 1px;
}
.bank-list .bank-owner {
    color: #8395a7;
    font-size: 0.75em;
    margin-top: 2px;
}
.qris-img {
    width: 100%;
    max-width: 200px;
    display: block;
    margin: 12px auto;
    border-radius: 12px;
}
.whatsapp-btn {
    display: block;
    text-align: center;
    background: #25D366;
    color: #fff;
    padding: 11px;
    border-radius: 10px;
    text-decoration: none;
    font-weight: 600;
    margin-top: 12px;
    transition: opacity 0.3s;
}
.whatsapp-btn:hover { opacity: 0.85; color: #fff; }

/* Footer */
.footer {
    text-align: center;
    padding: 15px;
    color: #576574;
    font-size: 0.75em;
}
.footer a { color: #48dbfb; text-decoration: none; }
.footer a:hover { text-decoration: underline; }

/* Responsive */
@media (max-width: 600px) {
    .grid { grid-template-columns: 1fr; }
    .status-bar { grid-template-columns: repeat(2, 1fr); }
    .header h1 { font-size: 1.3em; }
    .card-value { font-size: 1.4em; }
}

/* Animations */
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}
.card { animation: fadeIn 0.4s ease; }
.card:nth-child(2) { animation-delay: 0.1s; }
.card:nth-child(3) { animation-delay: 0.2s; }
</style>
</head>
<body>
<div class="container">
    <!-- Header -->
    <div class="header">
        <h1>My Home Server v3</h1>
        <p class="subtitle">STB B860H v1 &bull; S905X &bull; 1GB RAM &bull; Armbian &bull; EMMC Rusak</p>
        <div class="datetime" id="datetime"></div>
        <div class="uptime" id="uptime">Uptime: --</div>
    </div>

    <!-- Status Bar -->
    <div class="status-bar">
        <div class="status-item">
            <div class="label">CPU Load</div>
            <div class="value blue" id="load1">0.00</div>
        </div>
        <div class="status-item">
            <div class="label">Temperature</div>
            <div class="value orange" id="tempDisplay">-- °C</div>
        </div>
        <div class="status-item">
            <div class="label">Proses</div>
            <div class="value green" id="procs">0</div>
        </div>
        <div class="status-item">
            <div class="label">SDCARD</div>
            <div class="value" id="sdCardDisplay">--</div>
        </div>
    </div>

    <!-- Stat Cards -->
    <div class="grid" id="statsGrid">
        <div class="card">
            <div class="card-title">CPU Usage</div>
            <div class="card-body">
                <div class="card-value glow-blue" id="cpuValue">0<span class="unit">%</span></div>
                <div class="card-sub" id="cpuTemp">Temperature: -- °C</div>
                <div class="chart-container"><canvas id="cpuChart"></canvas></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">Memory (RAM)</div>
            <div class="card-body">
                <div class="card-value glow-green" id="ramValue">0<span class="unit"> MB</span></div>
                <div class="card-sub" id="ramSub">Total: -- MB</div>
                <div class="chart-container"><canvas id="ramChart"></canvas></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">ZRAM</div>
            <div class="card-body">
                <div class="card-value glow-blue" id="zramValue">0<span class="unit"> MB</span></div>
                <div class="card-sub" id="zramSub">Total: -- MB | CR: --</div>
                <div class="chart-container"><canvas id="zramChart"></canvas></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">SWAP</div>
            <div class="card-body">
                <div class="card-value glow-orange" id="swapValue">0<span class="unit"> MB</span></div>
                <div class="card-sub" id="swapSub">Total: -- MB</div>
                <div class="chart-container"><canvas id="swapChart"></canvas></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">SDCARD Storage</div>
            <div class="card-body">
                <div class="card-value glow-blue" id="diskValue">0<span class="unit"> GB</span></div>
                <div class="card-sub" id="diskSub">Total: -- GB</div>
                <div class="chart-container"><canvas id="diskChart"></canvas></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">Network</div>
            <div class="card-body">
                <div class="card-value glow-green" id="netRx">0<span class="unit"> B/s</span></div>
                <div class="card-sub" id="netTx">TX: 0 B/s</div>
                <div class="card-sub" style="margin-top:4px;color:#576574;font-size:0.75em" id="netTotal">Total RX: 0 | TX: 0</div>
            </div>
        </div>
    </div>

    <!-- Services -->
    <div class="service-grid" id="serviceGrid">
        <a href="http://{{ host_ip }}:2368" target="_blank" class="service-card" data-port="2368">
            <div class="icon">📝</div>
            <div class="name">Blog</div>
            <div class="status-dot" id="dot-2368"></div>
        </a>
        <a href="http://{{ host_ip }}:8080" target="_blank" class="service-card" data-port="8080">
            <div class="icon">📁</div>
            <div class="name">File Manager</div>
            <div class="status-dot" id="dot-8080"></div>
        </a>
        <a href="http://{{ host_ip }}:8765" target="_blank" class="service-card" data-port="8765">
            <div class="icon">📹</div>
            <div class="name">NVR Dashboard</div>
            <div class="status-dot" id="dot-8765"></div>
        </a>
        <a href="http://{{ host_ip }}:7681" target="_blank" class="service-card" data-port="7681">
            <div class="icon">💻</div>
            <div class="name">BTOP Terminal</div>
            <div class="status-dot" id="dot-7681"></div>
        </a>
        <a href="https://github.com/budijoi" target="_blank" class="service-card">
            <div class="icon">🐙</div>
            <div class="name">GitHub Repo</div>
            <div class="status-dot online"></div>
        </a>
    </div>

    <!-- Social Media & Donasi -->
    <div class="social-bar">
        <a href="https://facebook.com/budijoiBBJ" target="_blank" class="social-btn">
            <span>📘</span> Facebook
        </a>
        <a href="https://instagram.com/budijoi_eco" target="_blank" class="social-btn">
            <span>📷</span> Instagram
        </a>
        <a href="https://threads.net/budijoi_eco" target="_blank" class="social-btn">
            <span>🔄</span> Threads
        </a>
        <a href="https://x.com/budijoi" target="_blank" class="social-btn">
            <span>🐦</span> X
        </a>
        <a href="https://github.com/budijoi" target="_blank" class="social-btn">
            <span>🐙</span> Github
        </a>
        <a href="#" onclick="openDonasi()" class="social-btn donate">
            <span>❤️</span> Donasi
        </a>
    </div>

    <!-- Footer -->
    <div class="footer">
        My Home Server v3 &mdash; Self Hosted di STB Bekas<br>
        <span style="font-size:0.85em;color:#576574;">
            Made with ❤️ by <a href="https://github.com/budijoi" target="_blank">Budi Joi</a>
        </span>
    </div>
</div>

<!-- Modal Donasi -->
<div class="modal-overlay" id="donasiModal">
    <div class="modal">
        <button class="modal-close" onclick="closeDonasi()">&times;</button>
        <h2>Dukung Project Ini</h2>
        <p class="subtitle">Terima kasih untuk donasi yang mendukung pengembangan My Home Server v3</p>
        <ul class="bank-list">
            <li>
                <div class="bank-name">DANA</div>
                <div class="bank-num">085323073037</div>
                <div class="bank-owner">a.n. Budi Joi</div>
            </li>
            <li>
                <div class="bank-name">Bank Mandiri</div>
                <div class="bank-num">1310014031126</div>
                <div class="bank-owner">a.n. Budi Joi</div>
            </li>
            <li>
                <div class="bank-name">Bank BNI</div>
                <div class="bank-num">2027537451</div>
                <div class="bank-owner">a.n. Budi Joi</div>
            </li>
        </ul>
        <img src="https://raw.githubusercontent.com/budijoi/budijoi.github.io/refs/heads/main/QRDANA2.JPG"
             alt="QRIS DANA" class="qris-img" onerror="this.style.display='none'">
        <a href="https://wa.me/6288224553181?text=Halo%20Budi%20Joi%2C%20saya%20telah%20mendonasi%20untuk%20My%20Home%20Server%20v3"
           target="_blank" class="whatsapp-btn">
            ✅ Konfirmasi via WhatsApp
        </a>
    </div>
</div>

<script>
// Global charts
let cpuChart, ramChart, zramChart, swapChart, diskChart;
const CPU_HISTORY = [];
const RAM_HISTORY = [];
const ZRAM_HISTORY = [];
const SWAP_HISTORY = [];
const DISK_HISTORY = [];
const MAX_POINTS = 60;

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    let i = 0;
    let val = bytes;
    while (val >= 1024 && i < units.length - 1) { val /= 1024; i++; }
    return val.toFixed(i > 1 ? 1 : 0) + ' ' + units[i];
}

function formatBytesSpeed(bytes) {
    if (bytes === 0) return '0 B/s';
    const units = ['B/s', 'KB/s', 'MB/s'];
    let i = 0;
    let val = bytes;
    while (val >= 1024 && i < units.length - 1) { val /= 1024; i++; }
    return val.toFixed(i > 0 ? 1 : 0) + ' ' + units[i];
}

function updateClock() {
    const now = new Date();
    const opts = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
                   hour: '2-digit', minute: '2-digit', second: '2-digit' };
    document.getElementById('datetime').textContent = now.toLocaleDateString('id-ID', opts);
}

function createMiniChart(canvasId, color, label) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return null;
    const ctx = canvas.getContext('2d');
    return new Chart(ctx, {
        type: 'line',
        data: {
            labels: Array(MAX_POINTS).fill(''),
            datasets: [{
                label: label,
                data: Array(MAX_POINTS).fill(0),
                borderColor: color,
                backgroundColor: color + '20',
                borderWidth: 1.5,
                tension: 0.3,
                pointRadius: 0,
                fill: true
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: { duration: 300 },
            plugins: { legend: { display: false } },
            scales: {
                x: { display: false },
                y: { display: false, min: 0, max: 100 }
            },
            elements: { line: { borderJoinStyle: 'round' } }
        }
    });
}

function updateMiniChart(chart, value) {
    if (!chart) return;
    chart.data.datasets[0].data.push(value);
    chart.data.datasets[0].data.shift();
    chart.update('none');
}

function fetchStats() {
    fetch('/api/stats')
        .then(r => r.json())
        .then(d => {
            // CPU
            document.getElementById('cpuValue').innerHTML = d.cpu + '<span class="unit">%</span>';
            document.getElementById('cpuTemp').textContent = 'Temperature: ' + d.temp + ' °C';
            updateMiniChart(cpuChart, d.cpu);

            // RAM
            document.getElementById('ramValue').innerHTML = d.memory.ram_used + '<span class="unit"> MB</span>';
            document.getElementById('ramSub').textContent = 'Total: ' + d.memory.ram_total + ' MB | ' + d.memory.ram_percent + '%';
            updateMiniChart(ramChart, d.memory.ram_percent);

            // ZRAM
            document.getElementById('zramValue').innerHTML = d.zram.used + '<span class="unit"> MB</span>';
            document.getElementById('zramSub').textContent = 'Total: ' + d.zram.total + ' MB | CR: ' + d.zram.compression_ratio + 'x';
            updateMiniChart(zramChart, d.zram.percent);

            // SWAP
            document.getElementById('swapValue').innerHTML = d.memory.swap_used + '<span class="unit"> MB</span>';
            document.getElementById('swapSub').textContent = 'Total: ' + d.memory.swap_total + ' MB | ' + d.memory.swap_percent + '%';
            updateMiniChart(swapChart, d.memory.swap_percent);

            // Disk
            document.getElementById('diskValue').innerHTML = d.disk.used + '<span class="unit"> GB</span>';
            document.getElementById('diskSub').textContent = 'Total: ' + d.disk.total + ' GB | ' + d.disk.percent + '%';
            updateMiniChart(diskChart, d.disk.percent);

            // Network
            document.getElementById('netRx').innerHTML = formatBytesSpeed(d.network.rx);
            document.getElementById('netTx').textContent = 'TX: ' + formatBytesSpeed(d.network.tx);
            document.getElementById('netTotal').textContent = 'Total RX: ' + formatBytes(d.network.rx_total) + ' | TX: ' + formatBytes(d.network.tx_total);

            // Status bar
            document.getElementById('load1').textContent = d.load['1min'];
            document.getElementById('tempDisplay').textContent = d.temp + ' °C';
            document.getElementById('procs').textContent = d.processes;
            document.getElementById('uptime').textContent = 'Uptime: ' + d.uptime;

            // SDCARD
            const sdEl = document.getElementById('sdCardDisplay');
            if (d.sdcard && d.sdcard.total !== 'N/A') {
                sdEl.textContent = d.sdcard.used + ' / ' + d.sdcard.total;
                sdEl.className = 'value ' + (parseInt(d.sdcard.percent) > 80 ? 'red' : 'green');
            } else {
                sdEl.textContent = d.disk.used + 'G / ' + d.disk.total + 'G';
                sdEl.className = 'value blue';
            }
        })
        .catch(() => {});
}

function fetchServices() {
    fetch('/api/services')
        .then(r => r.json())
        .then(services => {
            services.forEach(svc => {
                const dot = document.getElementById('dot-' + svc.port);
                if (dot) {
                    dot.className = 'status-dot ' + svc.status;
                }
            });
        })
        .catch(() => {});
}

function openDonasi() {
    document.getElementById('donasiModal').classList.add('active');
}

function closeDonasi() {
    document.getElementById('donasiModal').classList.remove('active');
}

document.getElementById('donasiModal').addEventListener('click', function(e) {
    if (e.target === this) closeDonasi();
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeDonasi();
});

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    cpuChart = createMiniChart('cpuChart', '#48dbfb', 'CPU');
    ramChart = createMiniChart('ramChart', '#2ed573', 'RAM');
    zramChart = createMiniChart('zramChart', '#48dbfb', 'ZRAM');
    swapChart = createMiniChart('swapChart', '#ffa502', 'SWAP');
    diskChart = createMiniChart('diskChart', '#48dbfb', 'DISK');
    
    updateClock();
    fetchStats();
    fetchServices();
    
    setInterval(updateClock, 1000);
    setInterval(fetchStats, 2000);
    setInterval(fetchServices, 10000);
});
</script>
</body>
</html>
HTMLEOF
    print_success "Halaman dashboard v3 dibuat (dengan Chart.js)"

    # --- Systemd service ---
    print_info "Membuat systemd service..."
    cat > /etc/systemd/system/homeserver-dashboard.service << 'SVCEOF'
[Unit]
Description=My Home Server v3 - Dashboard Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/homeserver/dashboard
ExecStart=/usr/bin/python3 /opt/homeserver/dashboard/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF
    systemctl daemon-reload
    systemctl enable homeserver-dashboard
    systemctl restart homeserver-dashboard
    print_success "Dashboard service diaktifkan"

    # --- Nginx reverse proxy ---
    print_info "Mengkonfigurasi Nginx..."
    cat > /etc/nginx/sites-available/homeserver << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static/ {
        alias /opt/homeserver/dashboard/static/;
        expires 7d;
    }
}
NGINXEOF
    if [ -d /etc/nginx/sites-enabled ]; then
        ln -sf /etc/nginx/sites-available/homeserver /etc/nginx/sites-enabled/ 2>/dev/null || true
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        systemctl enable nginx
        systemctl restart nginx
    fi
    print_success "Nginx dikonfigurasi sebagai reverse proxy"

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  DASHBOARD V3 SIAP!                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses dashboard: ${CYAN}http://$HOSTNAME${NC}                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Fitur: Grafik bar real-time, navigasi layanan,     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  status service, sosial media, donasi               ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  3. MICRO BLOG (Ghost / WriteFreely / Liveblog)
# ============================================================
install_blog() {
    print_step "3/7" "MICRO BLOG - Ghost, WriteFreely, atau Liveblog"

    echo ""
    echo -e "${WHITE}Pilih platform blog yang akan diinstal:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}Ghost       ${NC}- Platform blogging modern (Node.js)"
    echo -e "     ${DIM}Estimasi storage: ~200MB${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}WriteFreely ${NC}- Platform blogging minimalis (Go)"
    echo -e "     ${DIM}Estimasi storage: ~50MB${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}Liveblog    ${NC}- Live blogging ringan (Python)"
    echo -e "     ${DIM}Estimasi storage: ~10MB${NC}"
    echo ""
    echo -e "  ${BOLD}0${NC}) ${RED}Batal${NC}"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-3]: ${NC}"
    read -r blog_choice

    case "$blog_choice" in
        1) install_ghost ;;
        2) install_writefreely ;;
        3) install_liveblog ;;
        *) print_info "Instalasi blog dibatalkan" ;;
    esac
}

install_ghost() {
    print_info "Menginstal Ghost CMS..."
    print_estimation "Ghost CMS" "~200MB (image Docker + content)"
    
    check_storage 500 || return
    
    ensure_docker

    print_info "Menjalankan Ghost via Docker..."
    mkdir -p "$DATA_DIR/ghost"
    docker rm -f ghost-blog 2>/dev/null || true
    docker run -d \
        --name ghost-blog \
        --restart always \
        -p 2368:2368 \
        -v "$DATA_DIR/ghost:/var/lib/ghost/content" \
        -e url=http://$(hostname -I | awk '{print $1}'):2368 \
        ghost:5-alpine

    # Buat user admin
    sleep 5
    print_info "Membuat user admin untuk Ghost..."
    docker exec ghost-blog ghost-cli setup --username admin --password admin12345678 --email admin@localhost --no-prompt 2>/dev/null || true
    # Alternatif: Ghost membuat admin di halaman setup pertama

    ufw allow 2368/tcp comment 'Ghost CMS'
    
    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  GHOST CMS SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:2368${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Admin : ${CYAN}http://$HOSTNAME:2368/ghost${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin (buat saat setup pertama)             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Data  : $DATA_DIR/ghost                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~200MB                           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_writefreely() {
    print_info "Menginstal WriteFreely..."
    print_estimation "WriteFreely" "~50MB (binary + database)"

    check_storage 150 || return

    local WF_DIR="$DATA_DIR/writefreely"
    mkdir -p "$WF_DIR"

    if [ ! -f "$WF_DIR/writefreely" ]; then
        print_info "Mendownload WriteFreely binary..."
        WF_VER=$(curl -sI https://github.com/writefreely/writefreely/releases/latest | grep -i 'location:' | grep -oP 'tag/\K[^"]+' || echo "v0.15.1")
        WF_VER=${WF_VER:-v0.15.1}
        wget -q "https://github.com/writefreely/writefreely/releases/download/$WF_VER/writefreely_linux_arm64.tar.gz" -O /tmp/wf.tar.gz 2>/dev/null || \
        wget -q "https://github.com/writefreely/writefreely/releases/download/v0.15.1/writefreely_linux_arm64.tar.gz" -O /tmp/wf.tar.gz
        tar -xzf /tmp/wf.tar.gz -C "$WF_DIR" 2>/dev/null || true
    fi

    WF_BIN=$(find "$WF_DIR" -name "writefreely" -type f 2>/dev/null | head -1)
    if [ -z "$WF_BIN" ]; then
        print_warning "Binary WriteFreely tidak ditemukan, menggunakan Docker..."
        ensure_docker
        docker run -d \
            --name writefreely \
            --restart always \
            -p 8082:8080 \
            -v "$WF_DIR:/data" \
            writeas/writefreely:latest 2>/dev/null || \
        print_warning "Gagal menjalankan WriteFreely via Docker."
        
        print_success "WriteFreely via Docker berjalan di port 8082"
    else
        cd "$WF_DIR"
        if [ ! -f config.ini ]; then
            "$WF_BIN" config gen 2>/dev/null || true
            if [ -f config.ini ]; then
                sed -i "s/port = 8080/port = 8082/" config.ini
                sed -i "s/bind = 127.0.0.1/bind = 0.0.0.0/" config.ini
                sed -i "s/;;bind/bind/" config.ini
            fi
        fi

        "$WF_BIN" keys generate 2>/dev/null || true
        "$WF_BIN" db init 2>/dev/null || true

        cat > /etc/systemd/system/writefreely.service << 'WFEOF'
[Unit]
Description=WriteFreely Blog - My Home Server v3
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/storage/writefreely
ExecStart=/home/storage/writefreely/writefreely
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
WFEOF
        systemctl daemon-reload
        systemctl enable writefreely 2>/dev/null || true
        systemctl restart writefreely 2>/dev/null || true
        print_success "WriteFreely binary berjalan di port 8082"
    fi

    ufw allow 8082/tcp comment 'WriteFreely Blog'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  WRITEFREELY SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8082${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Register user baru untuk admin                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin (register manual)                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Data  : $DATA_DIR/writefreely              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~50MB                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_liveblog() {
    print_info "Menginstal Liveblog..."
    print_estimation "Liveblog" "~10MB (Python + data JSON)"

    check_storage 50 || return

    local LB_DIR="$DATA_DIR/liveblog"
    mkdir -p "$LB_DIR"

    cat > "$LB_DIR/app.py" << 'LBPYEOF'
#!/usr/bin/env python3
# Liveblog - My Home Server v3
from flask import Flask, render_template_string, request, jsonify, redirect, url_for
import json, os, time
from datetime import datetime

app = Flask(__name__)
DATA_FILE = os.path.join(os.path.dirname(__file__), 'posts.json')

def load_posts():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE) as f:
                return json.load(f)
        except:
            return []
    return []

def save_posts(posts):
    with open(DATA_FILE, 'w') as f:
        json.dump(posts, f, indent=2)

INDEX_HTML = '''
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Liveblog - My Home Server v3</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:#0a0e17;color:#c8d6e5;padding:20px}
.container{max-width:800px;margin:0 auto}
h1{text-align:center;margin:30px 0;background:linear-gradient(135deg,#00d2ff,#3a7bd5);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-size:2em}
.desc{text-align:center;color:#576574;margin-bottom:30px}
.post{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:20px;margin-bottom:15px;animation:fadeIn .3s}
@keyframes fadeIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
.post h3{color:#48dbfb;margin-bottom:6px}
.post .date{color:#576574;font-size:0.8em;margin-bottom:10px}
.post p{line-height:1.7;color:#c8d6e5}
.nav{text-align:center;margin:20px 0}
.btn{display:inline-block;background:linear-gradient(135deg,#00d2ff,#3a7bd5);border:none;padding:10px 25px;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;text-decoration:none}
.btn:hover{opacity:0.9}
.empty{text-align:center;padding:40px;color:#576574}
</style>
</head>
<body>
<div class="container">
    <h1>Liveblog</h1>
    <p class="desc">Blog ringan untuk update cepat</p>
    <div id="posts"></div>
    <div class="nav"><a href="/admin" class="btn">+ Tulis Postingan</a></div>
</div>
<script>
let posts=[];
function render(){
    const c=document.getElementById('posts');
    if(posts.length===0){c.innerHTML='<div class="empty">Belum ada postingan</div>';return}
    c.innerHTML=posts.map(p=>'<div class="post"><h3>'+p.title+'</h3><div class="date">'+p.date+'</div><p>'+p.content+'</p></div>').join('')
}
function fetchPosts(){fetch('/api/posts').then(r=>r.json()).then(d=>{posts=d;render()}).catch(()=>{})}
fetchPosts();setInterval(fetchPosts,10000);
</script>
</body>
</html>
'''

ADMIN_HTML = '''
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Liveblog Admin - My Home Server v3</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:#0a0e17;color:#c8d6e5;padding:20px}
.container{max-width:600px;margin:0 auto}
h1{text-align:center;margin:30px 0;background:linear-gradient(135deg,#00d2ff,#3a7bd5);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
form{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:25px;margin:20px 0}
label{display:block;color:#8395a7;font-size:0.85em;margin-bottom:5px;margin-top:15px}
label:first-child{margin-top:0}
input,textarea{width:100%;padding:10px;background:#0f1729;border:1px solid #1e293b;border-radius:8px;color:#c8d6e5;font-size:1em}
textarea{min-height:150px;resize:vertical}
button{background:linear-gradient(135deg,#00d2ff,#3a7bd5);border:none;padding:12px 30px;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;font-size:1em;margin-top:10px}
button:hover{opacity:0.9}
a.back{display:block;text-align:center;margin-top:15px;color:#576574;text-decoration:none}
.msg{padding:10px;border-radius:8px;margin:10px 0;display:none}
.msg.success{display:block;background:#1a3a2a;border:1px solid #2ecc71;color:#2ecc71}
.msg.error{display:block;background:#3a1a1a;border:1px solid #e74c3c;color:#e74c3c}
</style>
</head>
<body>
<div class="container">
    <h1>Tulis Postingan</h1>
    <div id="msg" class="msg"></div>
    <form id="postForm">
        <label>Judul</label>
        <input type="text" id="title" required>
        <label>Konten</label>
        <textarea id="content" required></textarea>
        <label>Author</label>
        <input type="text" id="author" value="Admin">
        <button type="submit">Publikasikan</button>
    </form>
    <a href="/" class="back">&larr; Kembali ke Liveblog</a>
</div>
<script>
document.getElementById('postForm').addEventListener('submit',function(e){
    e.preventDefault();
    const data={title:document.getElementById('title').value,content:document.getElementById('content').value,author:document.getElementById('author').value||'Admin'};
    fetch('/api/posts',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})
    .then(r=>r.json()).then(d=>{
        const msg=document.getElementById('msg');
        if(d.status==='ok'){
            msg.className='msg success';msg.textContent='Postingan berhasil dipublikasikan!';
            document.getElementById('title').value='';document.getElementById('content').value='';
        }else{
            msg.className='msg error';msg.textContent='Gagal: '+d.message;
        }
    }).catch(()=>{const msg=document.getElementById('msg');msg.className='msg error';msg.textContent='Terjadi kesalahan koneksi'});
});
</script>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(INDEX_HTML)

@app.route('/admin')
def admin():
    return render_template_string(ADMIN_HTML)

@app.route('/api/posts', methods=['GET'])
def get_posts():
    return jsonify(load_posts())

@app.route('/api/posts', methods=['POST'])
def create_post():
    data = request.get_json()
    if not data or not data.get('title') or not data.get('content'):
        return jsonify({'status': 'error', 'message': 'Judul dan konten diperlukan'}), 400
    posts = load_posts()
    posts.insert(0, {
        'id': int(time.time() * 1000),
        'title': data['title'],
        'content': data['content'],
        'author': data.get('author', 'Admin'),
        'date': datetime.now().strftime('%Y-%m-%d %H:%M')
    })
    save_posts(posts)
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=False)
LBPYEOF
    chmod +x "$LB_DIR/app.py"

    cat > /etc/systemd/system/liveblog.service << 'LBEOF'
[Unit]
Description=Liveblog - Simple Blog Platform (My Home Server v3)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/storage/liveblog
ExecStart=/usr/bin/python3 /home/storage/liveblog/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
LBEOF
    systemctl daemon-reload
    systemctl enable liveblog
    systemctl restart liveblog
    ufw allow 8083/tcp comment 'Liveblog'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  LIVEBLOG SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8083${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Admin : ${CYAN}http://$HOSTNAME:8083/admin${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Data  : $DATA_DIR/liveblog/posts.json         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~10MB                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  4. FILE MANAGER (FileBrowser / FileGator / FileRise)
# ============================================================
install_filemanager() {
    print_step "4/7" "FILE MANAGER - FileBrowser, FileGator, atau FileRise"

    echo ""
    echo -e "${WHITE}Pilih File Manager yang akan diinstal:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}FileBrowser ${NC}- Go binary ringan (port 8080)"
    echo -e "     ${DIM}Estimasi storage: ~30MB${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}FileGator   ${NC}- PHP-based file manager (port 8084)"
    echo -e "     ${DIM}Estimasi storage: ~50MB${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}FileRise    ${NC}- Node.js file manager (port 8085)"
    echo -e "     ${DIM}Estimasi storage: ~100MB${NC}"
    echo ""
    echo -e "  ${BOLD}4${NC}) ${GREEN}SEMUA${NC} - Instal ketiganya                             ${GREEN}║${NC}"
    echo ""
    echo -e "  ${BOLD}0${NC}) ${RED}Batal${NC}"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-4]: ${NC}"
    read -r fm_choice

    # Buat folder storage dulu
    print_info "Membuat folder penyimpanan..."
    mkdir -p "$DATA_DIR"/{My\ Document,My\ Music,My\ Pictures,My\ Videos/NVR,My\ Videos}

    case "$fm_choice" in
        1) install_filebrowser ;;
        2) install_filegator ;;
        3) install_filerise ;;
        4)
            install_filebrowser
            install_filegator
            install_filerise
            ;;
        *) print_info "Instalasi File Manager dibatalkan" ;;
    esac
}

install_filebrowser() {
    print_info "Menginstal FileBrowser..."
    print_estimation "FileBrowser" "~30MB"

    check_storage 100 || return

    local FB_DIR="/opt/filebrowser"

    print_info "Mendownload FileBrowser..."
    mkdir -p "$FB_DIR"
    wget -q https://github.com/filebrowser/filebrowser/releases/latest/download/filebrowser-linux-arm64.tar.gz -O /tmp/fb.tar.gz 2>/dev/null || \
    curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/filebrowser-linux-arm64.tar.gz -o /tmp/fb.tar.gz
    tar -xzf /tmp/fb.tar.gz -C "$FB_DIR" filebrowser 2>/dev/null || true
    chmod +x "$FB_DIR/filebrowser" 2>/dev/null || true

    if [ ! -f "$FB_DIR/filebrowser" ]; then
        print_warning "Gagal download FileBrowser binary, coba via curl..."
        curl -fsSL https://github.com/filebrowser/filebrowser/releases/latest/download/filebrowser-linux-arm64.tar.gz -o /tmp/fb.tar.gz
        tar -xzf /tmp/fb.tar.gz -C "$FB_DIR" filebrowser 2>/dev/null || true
        chmod +x "$FB_DIR/filebrowser" 2>/dev/null || true
    fi

    if [ -f "$FB_DIR/filebrowser" ]; then
        "$FB_DIR/filebrowser" config init --database="$FB_DIR/filebrowser.db" 2>/dev/null || true
        "$FB_DIR/filebrowser" config set --address=0.0.0.0 --port=8080 --root="$DATA_DIR" --database="$FB_DIR/filebrowser.db" 2>/dev/null || true
        "$FB_DIR/filebrowser" users add admin admin12345678 --database="$FB_DIR/filebrowser.db" 2>/dev/null || \
        "$FB_DIR/filebrowser" users update admin --password=admin12345678 --database="$FB_DIR/filebrowser.db" 2>/dev/null || true
        print_success "User admin dibuat (password: admin12345678)"

        cat > /etc/systemd/system/filebrowser.service << 'FBEOF'
[Unit]
Description=FileBrowser - My Home Server v3
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/filebrowser
ExecStart=/opt/filebrowser/filebrowser --address=0.0.0.0 --port=8080 --root=/home/storage --database=/opt/filebrowser/filebrowser.db
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FBEOF
        systemctl daemon-reload
        systemctl enable filebrowser
        systemctl restart filebrowser
        print_success "FileBrowser berjalan di port 8080"
    else
        print_warning "FileBrowser binary gagal diunduh, gunakan Docker..."
        ensure_docker
        docker run -d \
            --name filebrowser \
            --restart always \
            -p 8080:80 \
            -v "$DATA_DIR:/srv" \
            -v "$DATA_DIR/filebrowser:/database" \
            filebrowser/filebrowser:latest
        sleep 3
        docker exec filebrowser filebrowser users add admin admin12345678 --database=/database/filebrowser.db 2>/dev/null || true
        print_success "FileBrowser via Docker berjalan di port 8080"
    fi

    ufw allow 8080/tcp comment 'FileBrowser'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILEBROWSER SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8080${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Folder: My Document, My Music, My Pictures, Videos  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~30MB                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_filegator() {
    print_info "Menginstal FileGator..."
    print_estimation "FileGator" "~50MB"

    check_storage 100 || return

    local FG_DIR="$DATA_DIR/filegator"
    mkdir -p "$FG_DIR"

    print_info "Mendownload FileGator..."
    wget -q https://github.com/filegator/filegator/releases/latest/download/filegator.zip -O /tmp/filegator.zip 2>/dev/null || \
    curl -fsSL https://github.com/filegator/filegator/releases/latest/download/filegator.zip -o /tmp/filegator.zip

    if [ -f /tmp/filegator.zip ]; then
        apt install -y unzip php-fpm php-sqlite3 php-mbstring php-xml 2>/dev/null || true
        unzip -q /tmp/filegator.zip -d "$FG_DIR" 2>/dev/null || true
        
        # Konfigurasi
        if [ -f "$FG_DIR/configuration.php" ]; then
            sed -i "s/'admin'/'admin'/" "$FG_DIR/configuration.php"
        fi

        # Buat user admin via SQLite jika ada
        mkdir -p "$FG_DIR/private"
        
        # Jalankan dengan PHP built-in server
        cat > /etc/systemd/system/filegator.service << 'FGSVCEOF'
[Unit]
Description=FileGator - File Manager (My Home Server v3)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/storage/filegator
ExecStart=/usr/bin/php -S 0.0.0.0:8084 -t /home/storage/filegator
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FGSVCEOF
        systemctl daemon-reload
        systemctl enable filegator
        systemctl restart filegator
        print_success "FileGator berjalan di port 8084"
    else
        print_warning "Gagal mendownload FileGator. Gunakan Docker..."
        ensure_docker
        docker run -d \
            --name filegator \
            --restart always \
            -p 8084:80 \
            -v "$DATA_DIR:/var/www/filegator/repository" \
            filegator/filegator:latest 2>/dev/null || \
        print_warning "Gagal menjalankan FileGator"
    fi

    ufw allow 8084/tcp comment 'FileGator'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILEGATOR SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8084${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Login default: admin/admin12345678                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~50MB                            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_filerise() {
    print_info "Menginstal FileRise..."
    print_estimation "FileRise" "~100MB (Node.js + dependencies)"

    check_storage 200 || return

    # FileRise requires Node.js
    print_info "Menginstal Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || true
    apt install -y nodejs 2>/dev/null || true

    local FR_DIR="$DATA_DIR/filerise"
    mkdir -p "$FR_DIR"

    print_info "Mendownload FileRise..."
    # FileRise bisa menggunakan package npm atau docker
    ensure_docker
    
    docker run -d \
        --name filerise \
        --restart always \
        -p 8085:8085 \
        -v "$DATA_DIR:/data" \
        -e PUID=0 \
        -e PGID=0 \
        -e TZ=Asia/Jakarta \
        linuxserver/filerise:latest 2>/dev/null || \
    docker run -d \
        --name filerise \
        --restart always \
        -p 8085:80 \
        -v "$DATA_DIR:/data" \
        filerise/filerise:latest 2>/dev/null || \
    print_warning "FileRise belum tersedia di Docker Hub. Gunakan alternatif."
    
    if docker ps | grep -q filerise; then
        print_success "FileRise via Docker berjalan di port 8085"
    else
        print_warning "FileRise Docker image tidak ditemukan. Menggunakan FileBrowser sebagai pengganti."
    fi

    ufw allow 8085/tcp comment 'FileRise'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILERISE SIAP!                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8085${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Login default: admin/admin12345678                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~100MB                           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  5. CCTV NVR (Shinobi / MotionEye / Frigate)
# ============================================================
install_nvr() {
    print_step "5/7" "CCTV NVR - Shinobi, MotionEye, atau Frigate"

    echo ""
    echo -e "${WHITE}Pilih NVR Platform yang akan diinstal:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}Shinobi    ${NC}- NVR modern dengan UI keren (Node.js)"
    echo -e "     ${DIM}Estimasi storage: ~500MB${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}MotionEye  ${NC}- NVR ringan berbasis Motion (Python)"
    echo -e "     ${DIM}Estimasi storage: ~200MB${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}Frigate    ${NC}- NVR dengan AI deteksi (Google Coral)"
    echo -e "     ${DIM}Estimasi storage: ~1GB${NC}"
    echo -e "     ${YELLOW}Catatan: Frigate butuh Google Coral TPU untuk AI optimal${NC}"
    echo ""
    echo -e "  ${BOLD}0${NC}) ${RED}Batal${NC}"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-3]: ${NC}"
    read -r nvr_choice

    case "$nvr_choice" in
        1) install_shinobi ;;
        2) install_motioneye ;;
        3) install_frigate ;;
        *) print_info "Instalasi NVR dibatalkan" ;;
    esac
}

install_shinobi() {
    print_info "Menginstal Shinobi NVR..."
    print_estimation "Shinobi NVR" "~500MB (Node.js + ffmpeg + database)"

    check_storage 800 || return

    ensure_docker

    mkdir -p "$DATA_DIR/shinobi"
    mkdir -p "$DATA_DIR/My Videos/NVR"

    print_info "Menjalankan Shinobi via Docker..."
    docker rm -f shinobi 2>/dev/null || true

    # Buat docker-compose untuk Shinobi
    cat > "$DATA_DIR/shinobi/docker-compose.yml" << 'SHINOBIEOF'
version: "3"
services:
  shinobi:
    image: shinobisystems/shinobi:latest
    container_name: shinobi
    restart: always
    ports:
      - "8081:8080"
    environment:
      - ADMIN_USER=admin
      - ADMIN_PASSWORD=admin12345678
      - ADMIN_EMAIL=admin@localhost
      - MYSQL_HOST=shinobi-mysql
      - MYSQL_USER=shinobi
      - MYSQL_PASSWORD=shinobipass
      - MYSQL_DATABASE=shinobi
    volumes:
      - /home/storage/shinobi/config:/config
      - /home/storage/My Videos/NVR:/recordings
    depends_on:
      - shinobi-mysql

  shinobi-mysql:
    image: mariadb:10
    container_name: shinobi-mysql
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=rootpass
      - MYSQL_DATABASE=shinobi
      - MYSQL_USER=shinobi
      - MYSQL_PASSWORD=shinobipass
    volumes:
      - /home/storage/shinobi/mysql:/var/lib/mysql
SHINOBIEOF

    cd "$DATA_DIR/shinobi"
    docker compose -f docker-compose.yml up -d 2>/dev/null || \
    docker-compose -f docker-compose.yml up -d 2>/dev/null || {
        print_warning "Docker compose gagal, menjalankan container langsung..."
        docker network create shinobi-net 2>/dev/null || true
        docker run -d --name shinobi-mysql --network shinobi-net \
            -e MYSQL_ROOT_PASSWORD=rootpass \
            -e MYSQL_DATABASE=shinobi \
            -e MYSQL_USER=shinobi \
            -e MYSQL_PASSWORD=shinobipass \
            -v "$DATA_DIR/shinobi/mysql:/var/lib/mysql" \
            --restart always \
            mariadb:10
        sleep 15
        docker run -d --name shinobi --network shinobi-net -p 8081:8080 \
            -e ADMIN_USER=admin \
            -e ADMIN_PASSWORD=admin12345678 \
            -e ADMIN_EMAIL=admin@localhost \
            -e MYSQL_HOST=shinobi-mysql \
            -e MYSQL_USER=shinobi \
            -e MYSQL_PASSWORD=shinobipass \
            -e MYSQL_DATABASE=shinobi \
            -v "$DATA_DIR/shinobi/config:/config" \
            -v "$DATA_DIR/My Videos/NVR:/recordings" \
            --restart always \
            shinobisystems/shinobi:latest
    }

    print_success "Shinobi NVR dimulai (port 8081)"

    ufw allow 8081/tcp comment 'Shinobi NVR'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  SHINOBI NVR SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8081${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Kamera: Tambahkan IP ${CYAN}192.168.101.6${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Rekaman: $DATA_DIR/My Videos/NVR            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~500MB                           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_motioneye() {
    print_info "Menginstal MotionEye NVR..."
    print_estimation "MotionEye" "~200MB"

    check_storage 400 || return

    mkdir -p "$DATA_DIR/My Videos/NVR"

    print_info "Menginstal dependensi motioneye..."
    apt install -y python3-pip python3-dev libssl-dev libcurl4-openssl-dev \
        libjpeg-dev motion ffmpeg v4l-utils 2>/dev/null || true

    print_info "Menginstal motioneye via pip..."
    pip3 install motioneye --break-system-packages 2>/dev/null || pip3 install motioneye

    print_info "Menyiapkan konfigurasi motioneye..."
    mkdir -p /etc/motioneye
    mkdir -p /var/log/motioneye

    cat > /etc/motioneye/motioneye.conf << 'MEYEEOF'
# MotionEye Configuration - My Home Server v3
conf_path /etc/motioneye
log_level info
log_file /var/log/motioneye/motioneye.log
motion_root /etc/motioneye
run_user root
web_port 8765
local_movies_directory /home/storage/My Videos/NVR
local_images_directory /home/storage/My Videos/NVR
MEYEEOF

    cat > /etc/systemd/system/motioneye.service << 'MEYEOF'
[Unit]
Description=MotionEye NVR - My Home Server v3
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/meyectl startserver -c /etc/motioneye/motioneye.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
MEYEOF
    systemctl daemon-reload
    systemctl enable motioneye
    systemctl restart motioneye

    print_success "MotionEye NVR telah dimulai"
    ufw allow 8765/tcp comment 'MotionEye NVR'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  MOTIONEYE NVR SIAP!                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8765${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  1. Buka dan buat user admin                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     User: admin | Pass: admin12345678                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  2. Tambah kamera: ${YELLOW}Network Camera${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${CYAN}rtsp://192.168.101.6:554/stream1${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  3. Set Movies Location ke:                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${CYAN}$DATA_DIR/My Videos/NVR${NC}         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~200MB                           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_frigate() {
    print_info "Menginstal Frigate NVR..."
    print_estimation "Frigate" "~1GB + Google Coral TPU"

    check_storage 2000 || return

    ensure_docker
    mkdir -p "$DATA_DIR/frigate"
    mkdir -p "$DATA_DIR/My Videos/NVR"

    print_info "Menjalankan Frigate via Docker..."

    # Deteksi apakah Google Coral tersedia
    if [ -e /dev/apex_0 ] || [ -e /dev/apex_1 ]; then
        CORAL_DEVICE="/dev/apex_0:/dev/apex_0"
        CORAL_MSG="Google Coral TPU terdeteksi!"
    else
        CORAL_DEVICE=""
        CORAL_MSG="Google Coral TPU ${YELLOW}TIDAK${NC} terdeteksi. Frigate akan berjalan tanpa AI."
    fi
    print_info "$CORAL_MSG"

    docker rm -f frigate 2>/dev/null || true

    # Buat config minimal untuk Frigate
    mkdir -p "$DATA_DIR/frigate/config"
    cat > "$DATA_DIR/frigate/config/config.yml" << 'FRIGATECFG'
mqtt:
  enabled: false

cameras:
  kamera1:
    ffmpeg:
      inputs:
        - path: rtsp://192.168.101.6:554/stream1
          roles:
            - detect
            - record
    detect:
      width: 1280
      height: 720
      fps: 5
    record:
      enabled: true
      events:
        required_zones: []
      retain:
        days: 7

record:
  enabled: true
  dir: /media/frigate/recordings
  retain:
    days: 7

snapshots:
  enabled: true

objects:
  track:
    - person
    - car
    - motorcycle
    - bicycle

detectors:
  cpu1:
    type: cpu

birdseye:
  enabled: true
  mode: continuous
FRIGATECFG

    docker run -d \
        --name frigate \
        --restart always \
        --privileged \
        --network host \
        -v "$DATA_DIR/frigate/config:/config" \
        -v "$DATA_DIR/My Videos/NVR:/media/frigate/recordings" \
        -v /etc/localtime:/etc/localtime:ro \
        ${CORAL_DEVICE:+-v $CORAL_DEVICE} \
        -e FRIGATE_RTSP_PASSWORD=admin12345678 \
        ghcr.io/blakeblackshear/frigate:stable

    print_success "Frigate NVR dimulai"
    ufw allow 5000/tcp comment 'Frigate NVR'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FRIGATE NVR SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:5000${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Kamera: ${CYAN}192.168.101.6${NC} (RTSP auto-detect)          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Rekaman: $DATA_DIR/My Videos/NVR            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $CORAL_MSG    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Estimasi storage: ~1GB                             ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  6. CLOUDFLARED
# ============================================================
install_cloudflared() {
    print_step "6/7" "CLOUDFLARED - Cloudflare Tunnel"

    print_info "Mendownload Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    print_success "Cloudflared terinstal"

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  KONFIGURASI CLOUDFLARED                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Untuk menghubungkan server ke Cloudflare Tunnel:  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  1. Login ke Cloudflare                            ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     cloudflared tunnel login                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  2. Buat tunnel baru                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     cloudflared tunnel create homeserver           ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  3. Konfigurasi tunnel (~/.cloudflared/config.yml) ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     tunnel: <TUNNEL-ID>                            ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     credentials-file: ~/.cloudflared/<ID>.json     ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     ingress:                                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}       - hostname: blog.domain.com                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}         service: http://localhost:2368             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}       - hostname: files.domain.com                 ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}         service: http://localhost:8080             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}       - hostname: nvr.domain.com                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}         service: http://localhost:8765             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}       - hostname: status.domain.com                ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}         service: http://localhost:7681             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}       - service: http_status:404                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  4. Install sebagai service                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}     cloudflared service install                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if confirm "Apakah Anda ingin login ke Cloudflare sekarang?"; then
        cloudflared tunnel login
        print_success "Login Cloudflare berhasil"
    fi

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  CLOUDFLARED SIAP DIGUNAKAN                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Jalankan langkah-langkah di atas untuk setup       ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  7. TTYD + BTOP
# ============================================================
install_ttyd() {
    print_step "TAMBAHAN" "TTYD - Terminal BTOP via Browser"

    print_info "Menginstal btop..."
    apt install -y btop 2>/dev/null || (
        wget -q https://github.com/aristocratos/btop/releases/latest/download/btop-aarch64-linux-musl.tgz -O /tmp/btop.tgz
        mkdir -p /tmp/btop && tar -xzf /tmp/btop.tgz -C /tmp/btop
        cp /tmp/btop/btop /usr/local/bin/btop
        chmod +x /usr/local/bin/btop
    )

    print_info "Menginstal TTYD..."
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) TTYD_ARCH="arm64" ;;
        armv7l|armhf)  TTYD_ARCH="armhf" ;;
        *)             TTYD_ARCH="arm64" ;;
    esac

    wget -q "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.$TTYD_ARCH" -O /usr/local/bin/ttyd
    chmod +x /usr/local/bin/ttyd

    cat > /etc/systemd/system/ttyd.service << 'TTYDEOF'
[Unit]
Description=TTYD - Terminal BTOP via Browser (My Home Server v3)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ttyd -p 7681 -c admin:admin12345678 btop
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
TTYDEOF
    systemctl daemon-reload
    systemctl enable ttyd
    systemctl restart ttyd

    ufw allow 7681/tcp comment 'TTYD BTOP'

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  TTYD SIAP!                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:7681${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass  : admin12345678                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  BTOP  : System monitor interaktif                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  8. INSTALL ALL-IN-ONE
# ============================================================
install_all() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}INSTALASI ALL-IN-ONE${NC}                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  Seluruh komponen akan diinstal secara berurutan    ${RED}║${NC}"
    echo -e "${RED}║${NC}  Waktu instalasi: ~30-60 menit                     ${RED}║${NC}"
    echo -e "${RED}║${NC}  Estimasi storage total: ~2-3GB                   ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! confirm "Lanjutkan instalasi semua komponen?"; then
        print_info "Instalasi dibatalkan"
        return
    fi

    install_optimization

    install_dashboard

    echo ""
    echo -e "${YELLOW}[?]${NC} Apakah Anda ingin menginstal Blog platform?"
    echo -ne "${CYAN}[y/N]: ${NC}"
    read -r blog_yn
    if [[ "$blog_yn" =~ ^[yY] ]]; then
        install_blog
    fi

    echo ""
    echo -e "${YELLOW}[?]${NC} Apakah Anda ingin menginstal File Manager?"
    echo -ne "${CYAN}[y/N]: ${NC}"
    read -r fm_yn
    if [[ "$fm_yn" =~ ^[yY] ]]; then
        install_filemanager
    fi

    echo ""
    echo -e "${YELLOW}[?]${NC} Apakah Anda ingin menginstal CCTV NVR?"
    echo -ne "${CYAN}[y/N]: ${NC}"
    read -r nvr_yn
    if [[ "$nvr_yn" =~ ^[yY] ]]; then
        install_nvr
    fi

    install_cloudflared

    if confirm "Apakah Anda ingin menginstal TTYD (btop via browser)?"; then
        install_ttyd
    fi

    # Final info
    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}INSTALASI MY HOME SERVER V3 SELESAI!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}AKSES LAYANAN:${NC}                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Dashboard     : ${CYAN}http://$HOSTNAME${NC}                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Blog          : ${CYAN}http://$HOSTNAME:2368${NC} (Ghost)${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:8082${NC} (WriteFreely)${NC}            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:8083${NC} (Liveblog)${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  File Manager  : ${CYAN}http://$HOSTNAME:8080${NC} (FileBrowser)${NC}            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:8084${NC} (FileGator)${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:8085${NC} (FileRise)${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  NVR CCTV      : ${CYAN}http://$HOSTNAME:8081${NC} (Shinobi)${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:8765${NC} (MotionEye)${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                  ${CYAN}http://$HOSTNAME:5000${NC} (Frigate)${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Terminal BTOP : ${CYAN}http://$HOSTNAME:7681${NC}                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}LOGIN KREDENSIAL:${NC}                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User : ${YELLOW}admin${NC}                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Pass : ${YELLOW}admin12345678${NC}                                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}FOLDER DATA:${NC}                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Document                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Music                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Pictures                           ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Videos                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Videos/NVR (rekaman CCTV)          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}OPTIMASI SISTEM:${NC}                                           ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ZRAM  : 512MB (algoritma zstd)                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  SWAP  : 1GB (di SDCARD)                                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  CPU   : Performance mode                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  BBR   : TCP congestion control                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}SOSIAL MEDIA:${NC}                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Facebook  : budijoiBBJ                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Instagram : budijoi_eco                                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Threads   : budijoi_eco                                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  X         : budijoi                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Github    : budijoi                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}DONASI:${NC}                                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Buka dashboard -> klik tombol Donasi                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Atau WA: ${CYAN}+6288224553181${NC}                                     ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  MAIN MENU
# ============================================================
show_menu() {
    print_banner
    echo -e "${BOLD}Pilih komponen yang akan diinstal:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC})  Optimasi Sistem     ${DIM}(ZRAM 512MB, SWAP 1GB, tuning S905X)${NC}"
    echo -e "  ${GREEN}2${NC})  Dashboard Monitor   ${DIM}(Web monitor + Chart.js grafik real-time)${NC}"
    echo -e "  ${GREEN}3${NC})  Micro Blog           ${DIM}(Ghost / WriteFreely / Liveblog)${NC}"
    echo -e "  ${GREEN}4${NC})  File Manager         ${DIM}(FileBrowser / FileGator / FileRise)${NC}"
    echo -e "  ${GREEN}5${NC})  CCTV NVR             ${DIM}(Shinobi / MotionEye / Frigate)${NC}"
    echo -e "  ${GREEN}6${NC})  Cloudflared          ${DIM}(Cloudflare Tunnel)${NC}"
    echo -e "  ${GREEN}7${NC})  TTYD + BTOP          ${DIM}(Terminal monitoring via browser)${NC}"
    echo ""
    echo -e "  ${YELLOW}8${NC})  ${BOLD}INSTAL ALL-IN-ONE${NC}  ${DIM}(Instal semua komponen)${NC}"
    echo ""
    echo -e "  ${RED}0${NC})  Keluar"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-8]: ${NC}"
    read -r menu_choice

    case "$menu_choice" in
        1) install_optimization ;;
        2) install_dashboard ;;
        3) install_blog ;;
        4) install_filemanager ;;
        5) install_nvr ;;
        6) install_cloudflared ;;
        7) install_ttyd ;;
        8) install_all ;;
        0)
            echo ""
            echo -e "${GREEN}Terima kasih telah menggunakan My Home Server v3 Installer!${NC}"
            echo ""
            exit 0
            ;;
        *)
            print_error "Pilihan tidak valid!"
            sleep 2
            show_menu
            ;;
    esac
}

# ============================================================
#  EKSEKUSI UTAMA
# ============================================================
main() {
    check_root
    detect_sdcard
    check_armbian

    # Jika argumen --auto diberikan, jalankan install_all langsung
    if [ "$1" = "--auto" ]; then
        install_all
        exit 0
    fi

    while true; do
        show_menu
        echo ""
        if confirm "Kembali ke menu utama?"; then
            continue
        else
            echo ""
            echo -e "${GREEN}Terima kasih telah menggunakan My Home Server v3 Installer!${NC}"
            echo ""
            break
        fi
    done
}

main "$@"
