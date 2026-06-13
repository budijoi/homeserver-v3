#!/bin/bash
# ============================================================
#  My Home Server v3 - All-in-One Installer
#  STB B860H v1 | Amlogic S905X | 1GB RAM | Armbian
#  EMMC Rusak -> Semua data dan aplikasi di SDCARD
#  Repo   : https://github.com/budijoi
#  Author : Budi Joi
# ============================================================
#  Komponen (diurutkan dari yang paling penting):
#  1. Optimasi Sistem   (ZRAM, SWAP, tuning S905X)
#  2. Dashboard Monitor  (Web monitor grafik real-time)
#  3. File Manager       (FileBrowser / FileGator / FileRise)
#  4. CCTV NVR           (Shinobi / MotionEye / Frigate)
#  5. Micro Blog         (Ghost / WriteFreely / Liveblog)
#  6. Cloudflared        (Cloudflare Tunnel)
#  7. TTYD + BTOP        (Terminal via Browser)
# ============================================================

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
SCRIPT_VERSION="3.1"
INSTALL_LOG="/var/log/homeserver-install.log"

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
    echo -e "${BLUE}║${NC} ${BOLD} $1${NC}"
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

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG"
}

run_cmd() {
    local cmd="$1"
    local msg="$2"
    print_info "$msg..."
    log "MENJALANKAN: $cmd"
    eval "$cmd" >> "$INSTALL_LOG" 2>&1
    local status=$?
    if [ $status -eq 0 ]; then
        return 0
    else
        print_warning "Perintah gagal (kode: $status), melanjutkan..."
        log "GAGAL (kode $status): $cmd"
        return 1
    fi
}

run_cmd_critical() {
    local cmd="$1"
    local msg="$2"
    print_info "$msg..."
    log "MENJALANKAN: $cmd"
    eval "$cmd" >> "$INSTALL_LOG" 2>&1
    local status=$?
    if [ $status -eq 0 ]; then
        print_success "Berhasil"
        return 0
    else
        print_error "Gagal! (kode: $status)"
        log "GAGAL KRITIS (kode $status): $cmd"
        return 1
    fi
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
    ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
    if echo "$ROOT_DEVICE" | grep -q "mmcblk1"; then
        print_success "SDCARD terdeteksi: $ROOT_DEVICE"
    elif echo "$ROOT_DEVICE" | grep -q "mmcblk0"; then
        print_info "Terdeteksi: $ROOT_DEVICE"
    else
        print_info "Root device: $ROOT_DEVICE"
    fi

    if mount | grep -q "/mnt/sdcard"; then
        DATA_DIR="/mnt/sdcard/storage"
    else
        DATA_DIR="/home/storage"
    fi

    mkdir -p "$DATA_DIR"
    print_success "Data akan disimpan di: $DATA_DIR"
    log "DATA_DIR=$DATA_DIR"
}

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
    local label=$2
    local avail_kb
    avail_kb=$(df "$DATA_DIR" --output=avail 2>/dev/null | tail -1)
    local avail_mb=$((avail_kb / 1024))

    if [ -z "$avail_kb" ] || [ "$avail_kb" -lt $((required_mb * 1024)) ]; then
        print_warning "Storage tersisa: ${avail_mb}MB, diperlukan: ${required_mb}MB untuk $label"
        if ! confirm "Lanjutkan instalasi $label?"; then
            print_info "Instalasi $label dibatalkan."
            return 1
        fi
    else
        print_info "Storage cukup: ${avail_mb}MB tersedia (dibutuhkan ${required_mb}MB)"
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
    curl -fsSL https://get.docker.com | bash >> "$INSTALL_LOG" 2>&1
    systemctl enable docker >> "$INSTALL_LOG" 2>&1 || true
    systemctl start docker >> "$INSTALL_LOG" 2>&1 || true
    if command -v docker &>/dev/null; then
        print_success "Docker terinstal"
    else
        print_error "Docker gagal diinstal!"
        return 1
    fi
}

docker_pull() {
    local image="$1"
    print_info "Mendownload image: $image..."
    docker pull "$image" >> "$INSTALL_LOG" 2>&1 || {
        print_warning "Gagal mendownload $image, melanjutkan..."
        return 1
    }
    return 0
}

# ============================================================
#  1. OPTIMASI SISTEM (PALING PENTING)
# ============================================================
install_optimization() {
    print_step "1/7" "OPTIMASI SISTEM - ZRAM 512MB, SWAP 1GB, Tuning S905X"

    echo -e "${WHITE}  Mengapa ini penting?${NC}"
    echo -e "  ${DIM}STB dengan 1GB RAM perlu ZRAM dan SWAP agar aplikasi bisa${NC}"
    echo -e "  ${DIM}berjalan stabil. Optimasi S905X mencegah overheating.${NC}"
    echo ""

    log "=== MULAI OPTIMASI SISTEM ==="

    if ! confirm "Mulai optimasi sistem?"; then
        print_info "Optimasi dibatalkan"
        return
    fi

    # Step 1: Update sistem
    echo ""
    echo -e "  ${BOLD}Tahap 1/6:${NC} Memperbarui sistem..."
    run_cmd "apt update" "Memperbarui daftar paket"
    run_cmd "apt upgrade -y" "Meningkatkan paket sistem"

    # Step 2: Install paket dasar
    echo ""
    echo -e "  ${BOLD}Tahap 2/6:${NC} Menginstal paket dasar..."
    run_cmd "apt install -y curl wget git htop iotop iftop btop ufw nginx python3 python3-pip python3-venv ca-certificates gnupg lsb-release software-properties-common apt-transport-https jq unzip" "Menginstal paket dasar"

    # Step 3: ZRAM 512MB
    echo ""
    echo -e "  ${BOLD}Tahap 3/6:${NC} Konfigurasi ZRAM 512MB..."
    echo -e "  ${DIM}ZRAM mengompresi memori agar lebih efisien. Dengan 1GB RAM,${NC}"
    echo -e "  ${DIM}512MB ZRAM menggunakan algoritma zstd (kompresi terbaik).${NC}"
    echo ""

    apt install -y zram-tools 2>/dev/null || true
    cat > /etc/default/zramswap << 'ZRAMEOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMEOF

    if systemctl is-enabled zramswap &>/dev/null; then
        systemctl restart zramswap 2>/dev/null || true
    else
        cat > /etc/systemd/system/zram-config.service << 'ZRAMSVC'
[Unit]
Description=ZRAM 512MB - My Home Server v3
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c "modprobe zram && echo zstd > /sys/block/zram0/comp_algorithm && echo 512M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0"
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
ZRAMSVC
        systemctl daemon-reload
        systemctl enable zram-config 2>/dev/null || true
        systemctl start zram-config 2>/dev/null || true
    fi
    print_success "ZRAM 512MB (zstd)"

    # Step 4: SWAP 1GB
    echo ""
    echo -e "  ${BOLD}Tahap 4/6:${NC} Membuat SWAP file 1GB..."
    echo -e "  ${DIM}SWAP file di SDCARD sebagai cadangan ketika RAM penuh.${NC}"
    echo ""

    SWAP_PATH="$DATA_DIR/swapfile"
    if [ ! -f "$SWAP_PATH" ]; then
        run_cmd "fallocate -l 1G '$SWAP_PATH' 2>/dev/null || dd if=/dev/zero of='$SWAP_PATH' bs=1M count=1024" "Membuat file SWAP 1GB"
        run_cmd "chmod 600 '$SWAP_PATH'" "Mengatur permission SWAP"
        run_cmd "mkswap '$SWAP_PATH'" "Format SWAP"
        run_cmd "swapon '$SWAP_PATH'" "Aktifkan SWAP"
        if ! grep -q "$SWAP_PATH" /etc/fstab; then
            echo "$SWAP_PATH none swap sw 0 0" >> /etc/fstab
            print_success "SWAP ditambahkan ke fstab"
        fi
        print_success "SWAP file 1GB di $SWAP_PATH"
    else
        print_info "SWAP file sudah ada"
    fi

    # Step 5: Optimasi S905X
    echo ""
    echo -e "  ${BOLD}Tahap 5/6:${NC} Optimasi khusus S905X..."
    echo -e "  ${DIM}Mengatur CPU ke mode performance, mengaktifkan BBR,${NC}"
    echo -e "  ${DIM}dan menonaktifkan layanan yang tidak perlu.${NC}"
    echo ""

    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    cat > /etc/default/cpufrequtils << 'CPUEOF'
GOVERNOR=performance
CPUEOF

    cat >> /etc/sysctl.conf << 'SYSEOF'
# My Home Server v3 - S905X Optimizations
vm.swappiness=60
vm.vfs_cache_pressure=50
vm.dirty_ratio=20
vm.dirty_background_ratio=5
vm.min_free_kbytes=32768
vm.overcommit_memory=1
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
SYSEOF
    sysctl -p >/dev/null 2>&1 || true
    print_success "sysctl tuning diterapkan"

    for svc in bluetooth cups avahi-daemon ModemManager whoopsie snapd; do
        systemctl disable "$svc" 2>/dev/null || true
    done
    print_success "Layanan tidak perlu dinonaktifkan"

    # Step 6: Firewall
    echo ""
    echo -e "  ${BOLD}Tahap 6/6:${NC} Konfigurasi firewall..."
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
    ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1
    ufw allow 5000/tcp comment 'Dashboard' >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1 || true
    print_success "Firewall UFW diaktifkan"

    log "=== OPTIMASI SELESAI ==="
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  OPTIMASI SELESAI!                                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - ZRAM  : 512MB (zstd)                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - SWAP  : 1GB                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - CPU   : Performance mode                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - BBR   : TCP congestion control                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  - Firewall: Aktif                                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  2. DASHBOARD MONITOR (GRAFIK + NAVIGASI)
# ============================================================
install_dashboard() {
    print_step "2/7" "DASHBOARD MONITOR - Web monitor dengan grafik real-time"

    echo -e "${WHITE}  Dashboard menampilkan:${NC}"
    echo -e "  ${DIM}- Grafik real-time CPU, RAM, ZRAM, SWAP, Disk, Network${NC}"
    echo -e "  ${DIM}- Status layanan (online/offline)${NC}"
    echo -e "  ${DIM}- Navigasi cepat ke semua aplikasi${NC}"
    echo -e "  ${DIM}- Tombol donasi dan sosial media${NC}"
    echo ""

    log "=== MULAI DASHBOARD ==="

    if ! confirm "Instal Dashboard Monitor?"; then
        print_info "Dashboard dibatalkan"
        return
    fi

    local DASH_DIR="/opt/homeserver/dashboard"
    local TEMPLATE_DIR="$DASH_DIR/templates"

    mkdir -p "$STATIC_DIR" 2>/dev/null
    mkdir -p "$TEMPLATE_DIR" 2>/dev/null

    print_info "Menginstal Flask..."
    apt install -y python3-flask 2>/dev/null && print_success "Flask via apt" || \
    python3 -m pip install flask --break-system-packages 2>/dev/null && print_success "Flask via python3 -m pip" || \
    pip3 install flask --break-system-packages 2>/dev/null && print_success "Flask via pip3" || \
    pip3 install flask 2>/dev/null && print_success "Flask via pip3 (legacy)" || \
    print_warning "Gagal install flask, coba metode alternatif..."

    # --- app.py ---
    print_info "Membuat aplikasi dashboard..."
    cat > "$DASH_DIR/app.py" << 'PYEOF'
#!/usr/bin/env python3
from flask import Flask, render_template, jsonify
import os, time, glob, socket, subprocess, json

app = Flask(__name__)
_cpu_prev = None; _cpu_time = None
_net_prev = None; _net_time = None
HISTORY_FILE = "/opt/homeserver/dashboard/history.json"

def read_sysfs(paths):
    for p in paths:
        for fp in glob.glob(p):
            if os.path.exists(fp):
                try:
                    with open(fp) as f: return f.read().strip()
                except: pass
    return None

def get_cpu_usage():
    global _cpu_prev, _cpu_time
    try:
        with open('/proc/stat') as f: line = f.readline().strip()
        parts = [int(x) for x in line.split()[1:]]
        total = sum(parts); idle = parts[3]; now = time.time()
        if _cpu_prev and _cpu_time:
            dt = now - _cpu_time; dtotal = total - _cpu_prev['total']; didle = idle - _cpu_prev['idle']
            usage = round(100.0 * (1.0 - didle / max(dtotal, 1)), 1) if dt > 0 and dtotal > 0 else 0.0
        else: usage = 0.0
        _cpu_prev = {'total': total, 'idle': idle}; _cpu_time = now
        return usage
    except: return 0.0

def get_cpu_temp():
    raw = read_sysfs(['/sys/class/thermal/thermal_zone*/temp', '/sys/class/hwmon/hwmon*/temp1_input'])
    if raw:
        try:
            v = int(raw)
            return round((v / 1000) if v > 100000 else v, 1)
        except: pass
    return 0.0

def get_memory_info():
    try:
        with open('/proc/meminfo') as f: data = f.read()
        def gv(k):
            for l in data.split('\n'):
                if k in l: return int(l.split()[1])
            return 0
        mt = gv('MemTotal'); ma = gv('MemAvailable'); mu = mt - ma
        st = gv('SwapTotal'); sf = gv('SwapFree'); su = max(st - sf, 0)
        return {'ram_total': mt//1024, 'ram_used': mu//1024, 'ram_percent': round(mu/mt*100,1) if mt>0 else 0,
                'swap_total': st//1024, 'swap_used': su//1024, 'swap_percent': round(su/st*100,1) if st>0 else 0}
    except:
        return {'ram_total':0,'ram_used':0,'ram_percent':0,'swap_total':0,'swap_used':0,'swap_percent':0}

def get_zram_info():
    try:
        r = subprocess.run(['zramctl','--raw','--noheadings'], capture_output=True, text=True, timeout=5)
        t=0; u=0; o=0
        for l in r.stdout.strip().split('\n'):
            if l:
                p = l.split()
                if len(p)>=4: t+=int(p[1]); u+=int(p[2])
                if len(p)>=5: o+=int(p[3])
        pct = round(u/t*100,1) if t>0 else 0
        cr = round(o/max(u,1),1) if u>0 else 1.0
        return {'total':t//1024,'used':u//1024,'percent':pct,'compression_ratio':cr,'orig_total':o//1024}
    except:
        return {'total':0,'used':0,'percent':0,'compression_ratio':1.0}

def get_disk_info():
    try:
        import shutil
        u = shutil.disk_usage('/')
        pct = round(u.used/u.total*100,1)
        return {'total':u.total//(1024**3),'used':u.used//(1024**3),'free':u.free//(1024**3),'percent':pct}
    except:
        try:
            s = os.statvfs('/')
            t = s.f_frsize*s.f_blocks; f = s.f_frsize*s.f_bfree; u = t-f
            return {'total':t//(1024**3),'used':u//(1024**3),'free':f//(1024**3),'percent':round(u/t*100,1) if t>0 else 0}
        except:
            return {'total':0,'used':0,'free':0,'percent':0}

def get_network_info():
    global _net_prev, _net_time
    try:
        with open('/proc/net/dev') as f: lines = f.readlines()
        rx=0; tx=0
        for l in lines[2:]:
            p = l.split(); ifc = p[0].rstrip(':')
            if ifc != 'lo': rx+=int(p[1]); tx+=int(p[9])
        now = time.time()
        if _net_prev and _net_time:
            dt = now - _net_time
            rx_speed = max(0, int((rx - _net_prev['rx']) / dt)) if dt > 0 else 0
            tx_speed = max(0, int((tx - _net_prev['tx']) / dt)) if dt > 0 else 0
        else: rx_speed=0; tx_speed=0
        _net_prev={'rx':rx,'tx':tx}; _net_time=now
        return {'rx':rx_speed,'tx':tx_speed,'rx_total':rx,'tx_total':tx}
    except:
        return {'rx':0,'tx':0,'rx_total':0,'tx_total':0}

def get_uptime():
    try:
        s = float(open('/proc/uptime').read().split()[0])
        d = int(s//86400); h = int((s%86400)//3600); m = int((s%3600)//60)
        return f"{d}h {h}j {m}m"
    except: return "N/A"

def get_load_average():
    try:
        p = open('/proc/loadavg').read().strip().split()
        return {'1min':p[0],'5min':p[1],'15min':p[2]}
    except: return {'1min':'0','5min':'0','15min':'0'}

def get_process_count():
    try:
        r = subprocess.run(['ps','-e','--no-headers'], capture_output=True, text=True, timeout=5)
        return len(r.stdout.strip().split('\n'))
    except: return 0

def load_history():
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE) as f:
                data = json.load(f)
                return data[-60:] if isinstance(data, list) else []
        except: pass
    return []

def save_history(d):
    h = load_history(); h.append(d); h = h[-60:]
    try:
        with open(HISTORY_FILE, 'w') as f: json.dump(h, f)
    except: pass

@app.route('/')
def index():
    host_ip = socket.gethostbyname(socket.gethostname())
    if host_ip.startswith('127.'):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80)); host_ip = s.getsockname()[0]; s.close()
        except: host_ip = 'localhost'
    return render_template('index.html', host_ip=host_ip)

@app.route('/api/stats')
def stats():
    d = {'cpu': get_cpu_usage(), 'temp': get_cpu_temp(),
         'memory': get_memory_info(), 'zram': get_zram_info(),
         'disk': get_disk_info(), 'network': get_network_info(),
         'uptime': get_uptime(), 'load': get_load_average(),
         'processes': get_process_count()}
    save_history({'cpu':d['cpu'],'temp':d['temp'],
                  'ram_percent':d['memory']['ram_percent'],
                  'zram_percent':d['zram']['percent'],
                  'swap_percent':d['memory']['swap_percent'],
                  'disk_percent':d['disk']['percent']})
    return jsonify(d)

@app.route('/api/history')
def history():
    return jsonify(load_history())

@app.route('/api/services')
def services():
    svcs = [
        ('Blog', 2368), ('File Manager', 8080),
        ('NVR CCTV', 8765), ('BTOP Terminal', 7681)]
    result = []
    for name, port in svcs:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1)
            status = 'online' if s.connect_ex(('127.0.0.1', port)) == 0 else 'offline'
            s.close()
        except: status = 'offline'
        result.append({'name':name,'port':port,'status':status})
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
PYEOF
    chmod +x "$DASH_DIR/app.py"

    # --- index.html ---
    print_info "Membuat halaman dashboard..."
    cat > "$TEMPLATE_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>My Home Server v3 — Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',-apple-system,sans-serif;background:#0a0e17;color:#c8d6e5;padding:15px}
.container{max-width:1200px;margin:0 auto}
.header{text-align:center;padding:20px 15px 15px;margin-bottom:20px}
.header h1{font-size:1.8em;background:linear-gradient(135deg,#00d2ff,#3a7bd5,#8b5cf6);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-weight:700}
.header .subtitle{color:#576574;margin-top:6px;font-size:0.85em}
.header .datetime{color:#48dbfb;font-size:1em;margin-top:4px}
.header .uptime{color:#2ed573;font-size:0.85em;margin-top:3px}
.status-bar{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px;margin-bottom:20px}
.status-item{background:linear-gradient(145deg,#111827,#0f1729);border:1px solid #1e293b;border-radius:12px;padding:10px 12px;text-align:center}
.status-item .label{font-size:0.65em;text-transform:uppercase;letter-spacing:1px;color:#576574}
.status-item .value{font-size:1.1em;font-weight:700;color:#fff;margin-top:3px}
.status-item .value.green{color:#2ed573}
.status-item .value.blue{color:#48dbfb}
.status-item .value.orange{color:#ffa502}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:15px;margin-bottom:20px}
.card{background:linear-gradient(145deg,#111827,#0f1729);border:1px solid #1e293b;border-radius:16px;padding:18px;position:relative;overflow:hidden;animation:fadeIn .4s ease}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,#00d2ff,#3a7bd5);opacity:.6}
.card:hover{border-color:#3a7bd5;transform:translateY(-2px);box-shadow:0 8px 30px rgba(58,123,213,.15)}
.card-title{font-size:.7em;text-transform:uppercase;letter-spacing:1.5px;color:#576574;margin-bottom:10px}
.card-value{font-size:1.8em;font-weight:700;color:#fff}
.card-value .unit{font-size:.5em;color:#576574;font-weight:400}
.card-sub{font-size:.8em;color:#8395a7;margin-top:4px}
.chart-container{height:70px;margin-top:8px}
.chart-container canvas{width:100%!important;height:100%!important}
.service-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:20px}
.service-card{background:linear-gradient(145deg,#111827,#0f1729);border:1px solid #1e293b;border-radius:12px;padding:14px;text-align:center;text-decoration:none;transition:all .3s ease;cursor:pointer}
.service-card:hover{border-color:#3a7bd5;transform:translateY(-2px);box-shadow:0 6px 20px rgba(58,123,213,.2)}
.service-card .icon{font-size:1.8em;margin-bottom:5px}
.service-card .name{font-size:.8em;color:#c8d6e5;font-weight:500}
.service-card .status-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-top:5px}
.service-card .status-dot.online{background:#2ed573;box-shadow:0 0 8px #2ed573}
.service-card .status-dot.offline{background:#ff4757;box-shadow:0 0 8px #ff4757}
.social-bar{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;margin:18px 0}
.social-btn{display:inline-flex;align-items:center;gap:5px;padding:7px 12px;background:#111827;border:1px solid #1e293b;border-radius:20px;color:#8395a7;text-decoration:none;font-size:.8em;transition:all .3s ease}
.social-btn:hover{color:#fff;border-color:#3a7bd5;transform:translateY(-1px)}
.social-btn.donate{border-color:#f1c40f40;color:#f1c40f}
.social-btn.donate:hover{border-color:#f1c40f;box-shadow:0 0 15px rgba(241,196,15,.2)}
.modal-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.75);z-index:1000;justify-content:center;align-items:center;backdrop-filter:blur(4px)}
.modal-overlay.active{display:flex}
.modal{background:#111827;border:1px solid #1e293b;border-radius:20px;padding:30px;max-width:460px;width:90%;position:relative;max-height:90vh;overflow-y:auto}
.modal h2{font-size:1.4em;text-align:center;margin-bottom:4px;background:linear-gradient(135deg,#f1c40f,#e67e22);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.modal .subtitle{text-align:center;color:#576574;font-size:.85em;margin-bottom:20px}
.modal-close{position:absolute;top:12px;right:15px;background:none;border:none;color:#576574;font-size:1.5em;cursor:pointer}
.modal-close:hover{color:#fff}
.bank-list{list-style:none}
.bank-list li{background:#0f1729;border:1px solid #1e293b;border-radius:12px;padding:14px;margin-bottom:8px}
.bank-list .bank-name{font-weight:700;color:#48dbfb;font-size:.85em}
.bank-list .bank-num{color:#fff;font-size:1.1em;margin-top:3px;letter-spacing:1px}
.bank-list .bank-owner{color:#8395a7;font-size:.75em;margin-top:2px}
.qris-img{width:100%;max-width:200px;display:block;margin:12px auto;border-radius:12px}
.whatsapp-btn{display:block;text-align:center;background:#25D366;color:#fff;padding:11px;border-radius:10px;text-decoration:none;font-weight:600;margin-top:12px;transition:opacity .3s}
.whatsapp-btn:hover{opacity:.85;color:#fff}
.footer{text-align:center;padding:15px;color:#576574;font-size:.75em}
.footer a{color:#48dbfb;text-decoration:none}
@keyframes fadeIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
@media(max-width:600px){.grid{grid-template-columns:1fr}.header h1{font-size:1.3em}}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>My Home Server v3</h1>
        <p class="subtitle">STB B860H v1 &bull; S905X &bull; 1GB RAM &bull; EMMC via SDCARD</p>
        <div class="datetime" id="datetime"></div>
        <div class="uptime" id="uptime">Uptime: --</div>
    </div>
    <div class="status-bar">
        <div class="status-item"><div class="label">CPU Load</div><div class="value blue" id="load1">0.00</div></div>
        <div class="status-item"><div class="label">Temperature</div><div class="value orange" id="tempDisplay">-- °C</div></div>
        <div class="status-item"><div class="label">Proses</div><div class="value green" id="procs">0</div></div>
        <div class="status-item"><div class="label">SDCARD</div><div class="value blue" id="sdCardDisplay">--</div></div>
    </div>
    <div class="grid">
        <div class="card"><div class="card-title">CPU Usage</div><div class="card-value glow-blue" id="cpuValue">0<span class="unit">%</span></div><div class="card-sub" id="cpuTemp">Temperature: -- °C</div><div class="chart-container"><canvas id="cpuChart"></canvas></div></div>
        <div class="card"><div class="card-title">Memory (RAM)</div><div class="card-value glow-green" id="ramValue">0<span class="unit"> MB</span></div><div class="card-sub" id="ramSub">Total: -- MB</div><div class="chart-container"><canvas id="ramChart"></canvas></div></div>
        <div class="card"><div class="card-title">ZRAM</div><div class="card-value glow-blue" id="zramValue">0<span class="unit"> MB</span></div><div class="card-sub" id="zramSub">Total: -- MB</div><div class="chart-container"><canvas id="zramChart"></canvas></div></div>
        <div class="card"><div class="card-title">SWAP</div><div class="card-value glow-orange" id="swapValue">0<span class="unit"> MB</span></div><div class="card-sub" id="swapSub">Total: -- MB</div><div class="chart-container"><canvas id="swapChart"></canvas></div></div>
        <div class="card"><div class="card-title">SDCARD Storage</div><div class="card-value glow-blue" id="diskValue">0<span class="unit"> GB</span></div><div class="card-sub" id="diskSub">Total: -- GB</div><div class="chart-container"><canvas id="diskChart"></canvas></div></div>
        <div class="card"><div class="card-title">Network</div><div class="card-value glow-green" id="netRx">0<span class="unit"> B/s</span></div><div class="card-sub" id="netTx">TX: 0 B/s</div><div class="card-sub" style="margin-top:4px;color:#576574;font-size:.75em" id="netTotal">Total RX: 0 | TX: 0</div></div>
    </div>
    <div class="service-grid">
        <a href="http://{{ host_ip }}:2368" target="_blank" class="service-card"><div class="icon">📝</div><div class="name">Blog</div><div class="status-dot" id="dot-2368"></div></a>
        <a href="http://{{ host_ip }}:8080" target="_blank" class="service-card"><div class="icon">📁</div><div class="name">File Manager</div><div class="status-dot" id="dot-8080"></div></a>
        <a href="http://{{ host_ip }}:8765" target="_blank" class="service-card"><div class="icon">📹</div><div class="name">NVR Dashboard</div><div class="status-dot" id="dot-8765"></div></a>
        <a href="http://{{ host_ip }}:7681" target="_blank" class="service-card"><div class="icon">💻</div><div class="name">BTOP Terminal</div><div class="status-dot" id="dot-7681"></div></a>
        <a href="https://github.com/budijoi" target="_blank" class="service-card"><div class="icon">🐙</div><div class="name">GitHub Repo</div><div class="status-dot online"></div></a>
    </div>
    <div class="social-bar">
        <a href="https://facebook.com/budijoiBBJ" target="_blank" class="social-btn"><span>📘</span> Facebook</a>
        <a href="https://instagram.com/budijoi_eco" target="_blank" class="social-btn"><span>📷</span> Instagram</a>
        <a href="https://threads.net/budijoi_eco" target="_blank" class="social-btn"><span>🔄</span> Threads</a>
        <a href="https://x.com/budijoi" target="_blank" class="social-btn"><span>🐦</span> X</a>
        <a href="https://github.com/budijoi" target="_blank" class="social-btn"><span>🐙</span> Github</a>
        <a href="#" onclick="openDonasi()" class="social-btn donate"><span>❤️</span> Donasi</a>
    </div>
    <div class="footer">My Home Server v3 &mdash; Self Hosted di STB Bekas<br><span style="font-size:.85em;color:#576574;">Made with ❤️ by <a href="https://github.com/budijoi" target="_blank">Budi Joi</a></span></div>
</div>
<div class="modal-overlay" id="donasiModal">
    <div class="modal">
        <button class="modal-close" onclick="closeDonasi()">&times;</button>
        <h2>Dukung Project Ini</h2>
        <p class="subtitle">Terima kasih untuk donasi yang mendukung pengembangan My Home Server v3</p>
        <ul class="bank-list">
            <li><div class="bank-name">DANA</div><div class="bank-num">085323073037</div><div class="bank-owner">a.n. Budi Joi</div></li>
            <li><div class="bank-name">Bank Mandiri</div><div class="bank-num">1310014031126</div><div class="bank-owner">a.n. Budi Joi</div></li>
            <li><div class="bank-name">Bank BNI</div><div class="bank-num">2027537451</div><div class="bank-owner">a.n. Budi Joi</div></li>
        </ul>
        <img src="https://raw.githubusercontent.com/budijoi/budijoi.github.io/refs/heads/main/QRDANA2.JPG" alt="QRIS DANA" class="qris-img" onerror="this.style.display='none'">
        <a href="https://wa.me/6288224553181?text=Halo%20Budi%20Joi%2C%20saya%20telah%20mendonasi%20untuk%20My%20Home%20Server%20v3" target="_blank" class="whatsapp-btn">✅ Konfirmasi via WhatsApp</a>
    </div>
</div>
<script>
let cpuChart,ramChart,zramChart,swapChart,diskChart;
const MAX=60;
function fmt(b){if(b===0)return'0 B';const u=['B','KB','MB','GB'];let i=0,v=b;while(v>=1024&&i<u.length-1){v/=1024;i++}return v.toFixed(i>1?1:0)+' '+u[i]}
function fmts(b){if(b===0)return'0 B/s';const u=['B/s','KB/s','MB/s'];let i=0,v=b;while(v>=1024&&i<u.length-1){v/=1024;i++}return v.toFixed(i>0?1:0)+' '+u[i]}
function clock(){const n=new Date();document.getElementById('datetime').textContent=n.toLocaleDateString('id-ID',{weekday:'long',year:'numeric',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit'})}
function mkChart(id,color){const c=document.getElementById(id);if(!c)return null;return new Chart(c.getContext('2d'),{type:'line',data:{labels:Array(MAX).fill(''),datasets:[{data:Array(MAX).fill(0),borderColor:color,backgroundColor:color+'20',borderWidth:1.5,tension:.3,pointRadius:0,fill:true}]},options:{responsive:true,maintainAspectRatio:false,animation:{duration:300},plugins:{legend:{display:false}},scales:{x:{display:false},y:{display:false,min:0,max:100}}}})}
function updChart(ch,v){if(!ch)return;ch.data.datasets[0].data.push(v);ch.data.datasets[0].data.shift();ch.update('none')}
function fetchStats(){fetch('/api/stats').then(r=>r.json()).then(d=>{
document.getElementById('cpuValue').innerHTML=d.cpu+'<span class="unit">%</span>'
document.getElementById('cpuTemp').textContent='Temperature: '+d.temp+' °C'
updChart(cpuChart,d.cpu)
document.getElementById('ramValue').innerHTML=d.memory.ram_used+'<span class="unit"> MB</span>'
document.getElementById('ramSub').textContent='Total: '+d.memory.ram_total+' MB | '+d.memory.ram_percent+'%'
updChart(ramChart,d.memory.ram_percent)
document.getElementById('zramValue').innerHTML=d.zram.used+'<span class="unit"> MB</span>'
document.getElementById('zramSub').textContent='Total: '+d.zram.total+' MB | CR: '+d.zram.compression_ratio+'x'
updChart(zramChart,d.zram.percent)
document.getElementById('swapValue').innerHTML=d.memory.swap_used+'<span class="unit"> MB</span>'
document.getElementById('swapSub').textContent='Total: '+d.memory.swap_total+' MB | '+d.memory.swap_percent+'%'
updChart(swapChart,d.memory.swap_percent)
document.getElementById('diskValue').innerHTML=d.disk.used+'<span class="unit"> GB</span>'
document.getElementById('diskSub').textContent='Total: '+d.disk.total+' GB | '+d.disk.percent+'%'
updChart(diskChart,d.disk.percent)
document.getElementById('netRx').innerHTML=fmts(d.network.rx)
document.getElementById('netTx').textContent='TX: '+fmts(d.network.tx)
document.getElementById('netTotal').textContent='Total RX: '+fmt(d.network.rx_total)+' | TX: '+fmt(d.network.tx_total)
document.getElementById('load1').textContent=d.load['1min']
document.getElementById('tempDisplay').textContent=d.temp+' °C'
document.getElementById('procs').textContent=d.processes
document.getElementById('uptime').textContent='Uptime: '+d.uptime
const sd=document.getElementById('sdCardDisplay')
sd.textContent=d.disk.used+'G / '+d.disk.total+'G'
sd.className='value '+(d.disk.percent>80?'red':'green')
}).catch(()=>{})}
function svcStatus(){fetch('/api/services').then(r=>r.json()).then(s=>{s.forEach(svc=>{const d=document.getElementById('dot-'+svc.port);if(d)d.className='status-dot '+svc.status})}).catch(()=>{})}
function openDonasi(){document.getElementById('donasiModal').classList.add('active')}
function closeDonasi(){document.getElementById('donasiModal').classList.remove('active')}
document.getElementById('donasiModal').addEventListener('click',function(e){if(e.target===this)closeDonasi()})
document.addEventListener('keydown',function(e){if(e.key==='Escape')closeDonasi()})
document.addEventListener('DOMContentLoaded',function(){
cpuChart=mkChart('cpuChart','#48dbfb');ramChart=mkChart('ramChart','#2ed573')
zramChart=mkChart('zramChart','#48dbfb');swapChart=mkChart('swapChart','#ffa502');diskChart=mkChart('diskChart','#48dbfb')
clock();fetchStats();svcStatus()
setInterval(clock,1000);setInterval(fetchStats,2000);setInterval(svcStatus,10000)
})
</script>
</body>
</html>
HTMLEOF
    print_success "Halaman dashboard dibuat"

    # Systemd service
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

    # Nginx
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
    }
}
NGINXEOF
    if [ -d /etc/nginx/sites-enabled ]; then
        ln -sf /etc/nginx/sites-available/homeserver /etc/nginx/sites-enabled/ 2>/dev/null || true
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        systemctl enable nginx || true
        systemctl restart nginx || true
    fi
    print_success "Nginx dikonfigurasi"

    log "=== DASHBOARD SELESAI ==="

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  DASHBOARD SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME${NC}                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Fitur : Grafik real-time, navigasi layanan,        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}          status service, sosial media, donasi       ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  3. FILE MANAGER (FileBrowser / FileGator / FileRise)
# ============================================================
install_filemanager() {
    print_step "3/7" "FILE MANAGER - FileBrowser, FileGator, atau FileRise"

    echo -e "${WHITE}  Pilihan File Manager:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}FileBrowser ${NC}- Go binary ringan, port 8080"
    echo -e "     ${DIM}Estimasi storage: ~30MB | Login: admin/admin12345678${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}FileGator   ${NC}- PHP-based, multi-user, port 8084"
    echo -e "     ${DIM}Estimasi storage: ~50MB | Login: admin/admin123${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}FileRise    ${NC}- PHP-based, fitur modern, port 8085"
    echo -e "     ${DIM}Estimasi storage: ~100MB | Login: buat user pertama${NC}"
    echo ""
    echo -e "  ${BOLD}4${NC}) ${GREEN}SEMUA${NC}"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-4]: ${NC}"
    read -r fm_choice

    # Create folders
    mkdir -p "$DATA_DIR"/{My\ Document,My\ Music,My\ Pictures,My\ Videos/NVR,My\ Videos}
    print_success "Folder data dibuat:"
    echo -e "  ${DIM}$DATA_DIR/My Document${NC}"
    echo -e "  ${DIM}$DATA_DIR/My Music${NC}"
    echo -e "  ${DIM}$DATA_DIR/My Pictures${NC}"
    echo -e "  ${DIM}$DATA_DIR/My Videos/NVR${NC}"

    case "$fm_choice" in
        1) install_filebrowser ;;
        2) install_filegator ;;
        3) install_filerise ;;
        4)
            install_filebrowser
            install_filegator
            install_filerise
            ;;
        *) print_info "File Manager dibatalkan" ;;
    esac
}

install_filebrowser() {
    print_info "Menginstal FileBrowser (port 8080)..."
    print_estimation "FileBrowser" "~30MB"
    check_storage 100 "FileBrowser" || return

    local FB_DIR="/opt/filebrowser"
    mkdir -p "$FB_DIR"

    # Coba binary dulu
    local FB_BINARY=""
    wget -q "https://github.com/filebrowser/filebrowser/releases/latest/download/filebrowser-linux-arm64.tar.gz" -O /tmp/fb.tar.gz 2>/dev/null || \
    curl -fsSL "https://github.com/filebrowser/filebrowser/releases/latest/download/filebrowser-linux-arm64.tar.gz" -o /tmp/fb.tar.gz 2>/dev/null || true

    if [ -f /tmp/fb.tar.gz ] && [ -s /tmp/fb.tar.gz ]; then
        tar -xzf /tmp/fb.tar.gz -C "$FB_DIR" filebrowser 2>/dev/null || true
        if [ -f "$FB_DIR/filebrowser" ]; then
            chmod +x "$FB_DIR/filebrowser"
            FB_BINARY="$FB_DIR/filebrowser"
        fi
    fi

    if [ -n "$FB_BINARY" ]; then
        "$FB_BINARY" config init --database="$FB_DIR/filebrowser.db" 2>/dev/null || true
        "$FB_BINARY" config set --address=0.0.0.0 --port=8080 --root="$DATA_DIR" --database="$FB_DIR/filebrowser.db" 2>/dev/null || true
        "$FB_BINARY" users add admin admin12345678 --database="$FB_DIR/filebrowser.db" 2>/dev/null || \
        "$FB_BINARY" users update admin --password=admin12345678 --database="$FB_DIR/filebrowser.db" 2>/dev/null || true

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
        print_success "FileBrowser binary berjalan di port 8080"
    else
        print_warning "Binary gagal, menggunakan Docker..."
        ensure_docker
        docker_pull "filebrowser/filebrowser:latest" || return
        docker rm -f filebrowser 2>/dev/null || true
        docker run -d --name filebrowser --restart always \
            -p 8080:80 \
            -v "$DATA_DIR:/srv" \
            -v "$DATA_DIR/filebrowser-db:/database" \
            -v "$DATA_DIR/filebrowser-config:/config" \
            filebrowser/filebrowser:latest
        sleep 3
        # Set password via API
        curl -s -X POST http://localhost:8080/api/login -d '{"username":"admin","password":"admin"}' 2>/dev/null || true
        print_success "FileBrowser Docker berjalan di port 8080"
    fi

    ufw allow 8080/tcp comment 'FileBrowser' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILEBROWSER SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8080${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin / Pass: admin12345678                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Folder: My Document, My Music, My Pictures, Videos  ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_filegator() {
    print_info "Menginstal FileGator (port 8084)..."
    print_estimation "FileGator" "~50MB"
    check_storage 150 "FileGator" || return

    ensure_docker
    docker_pull "filegator/filegator:latest-multiarch" || {
        docker_pull "filegator/filegator:latest" || return
    }

    docker rm -f filegator 2>/dev/null || true
    docker run -d --name filegator --restart always \
        -p 8084:8080 \
        -v "$DATA_DIR:/var/www/filegator/repository" \
        filegator/filegator:latest-multiarch 2>/dev/null || \
    docker run -d --name filegator --restart always \
        -p 8084:8080 \
        -v "$DATA_DIR:/var/www/filegator/repository" \
        filegator/filegator:latest 2>/dev/null || {
        print_warning "FileGator Docker gagal"
        return
    }

    print_success "FileGator berjalan di port 8084"
    ufw allow 8084/tcp comment 'FileGator' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILEGATOR SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8084${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Login : admin / admin123 (ubah password nanti)     ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_filerise() {
    print_info "Menginstal FileRise (port 8085)..."
    print_estimation "FileRise" "~100MB"
    check_storage 200 "FileRise" || return

    ensure_docker
    docker_pull "error311/filerise-docker:latest" || return

    mkdir -p "$DATA_DIR/filerise"/{uploads,users,metadata}
    docker rm -f filerise 2>/dev/null || true
    docker run -d --name filerise --restart always \
        -p 8085:80 \
        -e TIMEZONE="Asia/Jakarta" \
        -e TOTAL_UPLOAD_SIZE="10G" \
        -e SECURE="false" \
        -e SCAN_ON_START="true" \
        -e CHOWN_ON_START="true" \
        -v "$DATA_DIR/filerise/uploads:/var/www/uploads" \
        -v "$DATA_DIR/filerise/users:/var/www/users" \
        -v "$DATA_DIR/filerise/metadata:/var/www/metadata" \
        error311/filerise-docker:latest

    print_success "FileRise berjalan di port 8085"
    ufw allow 8085/tcp comment 'FileRise' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FILERISE SIAP!                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8085${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Buka di browser, buat user admin pertama            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  4. CCTV NVR (Shinobi / MotionEye / Frigate)
# ============================================================
install_nvr() {
    print_step "4/7" "CCTV NVR - Shinobi, MotionEye, atau Frigate"

    echo -e "${WHITE}  Pilihan NVR:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}Shinobi    ${NC}- NVR modern, Node.js, port 8081"
    echo -e "     ${DIM}Estimasi storage: ~500MB${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}MotionEye  ${NC}- NVR ringan, Python, port 8765"
    echo -e "     ${DIM}Estimasi storage: ~200MB${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}Frigate    ${NC}- NVR dengan AI, port 8971"
    echo -e "     ${DIM}Estimasi storage: ~1GB (butuh Google Coral untuk AI)${NC}"
    echo ""
    echo -e "  ${BOLD}0${NC}) ${RED}Batal${NC}"
    echo ""
    echo -e "  ${YELLOW}Info:${NC} Kamera IP 192.168.101.6 akan dikonfigurasi otomatis"
    echo -e "  ${YELLOW}Info:${NC} Rekaman disimpan di ${CYAN}$DATA_DIR/My Videos/NVR${NC}"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-3]: ${NC}"
    read -r nvr_choice

    # Buat folder rekaman
    mkdir -p "$DATA_DIR/My Videos/NVR"

    case "$nvr_choice" in
        1) install_shinobi ;;
        2) install_motioneye ;;
        3) install_frigate ;;
        *) print_info "Instalasi NVR dibatalkan" ;;
    esac
}

install_shinobi() {
    print_info "Menginstal Shinobi NVR (port 8081)..."
    print_estimation "Shinobi" "~500MB"
    check_storage 800 "Shinobi" || return

    ensure_docker

    # Shinobi uses GitLab registry, not Docker Hub
    print_info "Mendownload Shinobi dari GitLab registry..."
    docker pull registry.gitlab.com/shinobi-systems/shinobi:dev >> "$INSTALL_LOG" 2>&1 || {
        print_warning "Image Shinobi dari GitLab gagal, coba Docker Hub..."
        docker pull shinobisystems/shinobi:latest >> "$INSTALL_LOG" 2>&1 || {
            print_error "Gagal mendownload Shinobi. Coba metode alternatif..."
            # Fallback: install langsung
            print_info "Menginstal Shinobi langsung via script installer..."
            bash <(curl -s https://gitlab.com/Shinobi-Systems/Shinobi-Installer/raw/master/shinobi-docker.sh) 2>/dev/null || {
                print_error "Shinobi gagal diinstal"
                return
            }
            return
        }
    }

    mkdir -p "$DATA_DIR/shinobi"/{config,mysql}
    docker rm -f shinobi shinobi-mysql 2>/dev/null || true

    docker network create shinobi-net 2>/dev/null || true

    docker run -d --name shinobi-mysql --network shinobi-net \
        -e MYSQL_ROOT_PASSWORD=rootpass \
        -e MYSQL_DATABASE=ccio \
        -e MYSQL_USER=majesticflame \
        -e MYSQL_PASSWORD=shinobipass \
        -v "$DATA_DIR/shinobi/mysql:/var/lib/mysql" \
        --restart always \
        mariadb:10 >> "$INSTALL_LOG" 2>&1

    print_info "Menunggu MySQL siap..."
    sleep 15

    docker run -d --name shinobi --network shinobi-net -p 8081:8080 \
        -e DB_HOST=shinobi-mysql \
        -e DB_USER=majesticflame \
        -e DB_PASSWORD=shinobipass \
        -e DB_DATABASE=ccio \
        -v "$DATA_DIR/shinobi/config:/config" \
        -v "$DATA_DIR/My Videos/NVR:/home/Shinobi/videos" \
        --restart always \
        registry.gitlab.com/shinobi-systems/shinobi:dev >> "$INSTALL_LOG" 2>&1 || \
    docker run -d --name shinobi --network shinobi-net -p 8081:8080 \
        -e DB_HOST=shinobi-mysql \
        -e DB_USER=majesticflame \
        -e DB_PASSWORD=shinobipass \
        -e DB_DATABASE=ccio \
        -v "$DATA_DIR/shinobi/config:/config" \
        -v "$DATA_DIR/My Videos/NVR:/home/Shinobi/videos" \
        --restart always \
        shinobisystems/shinobi:latest >> "$INSTALL_LOG" 2>&1

    print_success "Shinobi NVR diinstal"
    ufw allow 8081/tcp comment 'Shinobi NVR' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  SHINOBI NVR SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8081${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Login : Buka ${CYAN}http://$HOSTNAME:8081/super${NC}         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Kamera: Tambahkan ${YELLOW}192.168.101.6${NC}                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Rekaman: $DATA_DIR/My Videos/NVR            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_motioneye() {
    print_info "Menginstal MotionEye NVR (port 8765)..."
    print_estimation "MotionEye" "~200MB"
    check_storage 400 "MotionEye" || return

    run_cmd "apt install -y python3-pip python3-dev libssl-dev libcurl4-openssl-dev libjpeg-dev motion ffmpeg v4l-utils 2>/dev/null || true" "Menginstal dependensi"
    print_info "Menginstal motioneye..."
    apt install -y motioneye 2>/dev/null && print_success "motioneye via apt" || \
    python3 -m pip install motioneye --break-system-packages 2>/dev/null && print_success "motioneye via python3 -m pip" || \
    pip3 install motioneye --break-system-packages 2>/dev/null && print_success "motioneye via pip3" || \
    pip3 install motioneye 2>/dev/null && print_success "motioneye via pip3 (legacy)" || \
    print_warning "Gagal install motioneye via pip, coba dari source..."
    if ! command -v meyectl &>/dev/null; then
        pip3 install git+https://github.com/motioneye-project/motioneye.git --break-system-packages 2>/dev/null || true
    fi

    mkdir -p /etc/motioneye /var/log/motioneye

    cat > /etc/motioneye/motioneye.conf << 'MEYEEOF'
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
    systemctl enable motioneye || true
    systemctl restart motioneye || {
        print_warning "MotionEye service gagal, coba jalankan langsung..."
        nohup /usr/local/bin/meyectl startserver -c /etc/motioneye/motioneye.conf > /var/log/motioneye.log 2>&1 &
    }

    print_success "MotionEye NVR diinstal"
    ufw allow 8765/tcp comment 'MotionEye NVR' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  MOTIONEYE NVR SIAP!                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8765${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Setup:                                             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  1. Buka dan buat user admin / admin12345678        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  2. Tambah kamera Network Camera:                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${CYAN}rtsp://192.168.101.6:554/stream1${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  3. Movies Location:                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${CYAN}$DATA_DIR/My Videos/NVR${NC}         ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_frigate() {
    print_info "Menginstal Frigate NVR (port 8971)..."
    print_estimation "Frigate" "~1GB"
    check_storage 2000 "Frigate" || return

    ensure_docker
    mkdir -p "$DATA_DIR/frigate/config"

    # Deteksi Google Coral
    if [ -e /dev/apex_0 ] || [ -e /dev/apex_1 ]; then
        CORAL_DEVICE="-v /dev/apex_0:/dev/apex_0"
        CORAL_MSG="Google Coral TPU terdeteksi!"
    else
        CORAL_DEVICE=""
        CORAL_MSG="Google Coral TPU tidak terdeteksi (AI detection via CPU)"
    fi
    print_info "$CORAL_MSG"

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
detectors:
  cpu1:
    type: cpu
birdseye:
  enabled: true
  mode: continuous
FRIGATECFG

    print_info "Mendownload Frigate image (ukuran besar, mungkin butuh waktu)..."
    docker pull ghcr.io/blakeblackshear/frigate:stable >> "$INSTALL_LOG" 2>&1 || {
        print_error "Gagal mendownload Frigate"
        return
    }

    docker rm -f frigate 2>/dev/null || true
    docker run -d --name frigate --restart unless-stopped --privileged \
        --shm-size=512mb \
        --network host \
        -v "$DATA_DIR/frigate/config:/config" \
        -v "$DATA_DIR/My Videos/NVR:/media/frigate/recordings" \
        -v /etc/localtime:/etc/localtime:ro \
        $CORAL_DEVICE \
        -e FRIGATE_RTSP_PASSWORD='admin12345678' \
        ghcr.io/blakeblackshear/frigate:stable

    print_success "Frigate NVR diinstal (port 8971)"
    ufw allow 8971/tcp comment 'Frigate NVR' >/dev/null 2>&1
    ufw allow 8554/tcp comment 'Frigate RTSP' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  FRIGATE NVR SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8971${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Login : admin / lihat password di log:              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     ${CYAN}docker logs frigate | grep -i password${NC}          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Kamera: ${CYAN}192.168.101.6${NC} (otomatis)                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Rekaman: $DATA_DIR/My Videos/NVR            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $CORAL_MSG    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  5. MICRO BLOG (Ghost / WriteFreely / Liveblog)
# ============================================================
install_blog() {
    print_step "5/7" "MICRO BLOG - Ghost, WriteFreely, atau Liveblog"

    echo -e "${WHITE}  Pilihan platform blog:${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC}) ${CYAN}Ghost       ${NC}- Platform blogging modern (Node.js)"
    echo -e "     ${DIM}Estimasi storage: ~200MB | Port: 2368${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC}) ${CYAN}WriteFreely ${NC}- Platform minimalis (Go)"
    echo -e "     ${DIM}Estimasi storage: ~50MB | Port: 8082${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC}) ${CYAN}Liveblog    ${NC}- Live blogging ringan (Python)"
    echo -e "     ${DIM}Estimasi storage: ~10MB | Port: 8083${NC}"
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
    print_info "Menginstal Ghost CMS (port 2368)..."
    print_estimation "Ghost CMS" "~200MB"
    check_storage 500 "Ghost" || return

    ensure_docker
    mkdir -p "$DATA_DIR/ghost"

    docker pull ghost:5-alpine >> "$INSTALL_LOG" 2>&1 || {
        print_warning "Ghost 5-alpine gagal, coba ghost:latest..."
        docker pull ghost:latest >> "$INSTALL_LOG" 2>&1 || {
            print_error "Gagal mendownload Ghost"
            return
        }
    }

    docker rm -f ghost-blog 2>/dev/null || true
    docker run -d --name ghost-blog --restart always \
        -p 2368:2368 \
        -v "$DATA_DIR/ghost:/var/lib/ghost/content" \
        -e url=http://$(hostname -I | awk '{print $1}'):2368 \
        ghost:5-alpine || \
    docker run -d --name ghost-blog --restart always \
        -p 2368:2368 \
        -v "$DATA_DIR/ghost:/var/lib/ghost/content" \
        -e url=http://$(hostname -I | awk '{print $1}'):2368 \
        ghost:latest

    print_success "Ghost CMS diinstal"
    ufw allow 2368/tcp comment 'Ghost CMS' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  GHOST CMS SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:2368${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Admin : ${CYAN}http://$HOSTNAME:2368/ghost${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Buat user admin saat pertama akses                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Gunakan: admin@localhost / admin12345678             ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_writefreely() {
    print_info "Menginstal WriteFreely (port 8082)..."
    print_estimation "WriteFreely" "~50MB"
    check_storage 150 "WriteFreely" || return

    # Prefer Docker untuk kemudahan
    ensure_docker
    print_info "Menggunakan Docker untuk WriteFreely..."
    docker pull writeas/writefreely:latest >> "$INSTALL_LOG" 2>&1 || {
        print_warning "Gagal download WriteFreely Docker"
        return
    }

    mkdir -p "$DATA_DIR/writefreely"
    docker rm -f writefreely 2>/dev/null || true
    docker run -d --name writefreely --restart always \
        -p 8082:8080 \
        -v "$DATA_DIR/writefreely:/data" \
        writeas/writefreely:latest

    print_success "WriteFreely via Docker diinstal"
    ufw allow 8082/tcp comment 'WriteFreely Blog' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  WRITEFREELY SIAP!                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8082${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Register user baru untuk admin                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Gunakan: admin / admin12345678                       ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

install_liveblog() {
    print_info "Menginstal Liveblog (port 8083)..."
    print_estimation "Liveblog" "~10MB"
    check_storage 50 "Liveblog" || return

    local LB_DIR="$DATA_DIR/liveblog"
    mkdir -p "$LB_DIR"

    cat > "$LB_DIR/app.py" << 'LBPYEOF'
#!/usr/bin/env python3
from flask import Flask, render_template_string, request, jsonify
import json, os, time
from datetime import datetime
app = Flask(__name__)
DATA_FILE = os.path.join(os.path.dirname(__file__), 'posts.json')
def load_posts():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE) as f:
                return json.load(f)
        except: return []
    return []
def save_posts(posts):
    with open(DATA_FILE, 'w') as f:
        json.dump(posts, f, indent=2)
IDX = '''<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Liveblog</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:#0a0e17;color:#c8d6e5;padding:20px}
.container{max-width:800px;margin:0 auto}
h1{text-align:center;margin:30px 0;background:linear-gradient(135deg,#00d2ff,#3a7bd5);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.desc{text-align:center;color:#576574;margin-bottom:30px}
.post{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:20px;margin-bottom:15px}
.post h3{color:#48dbfb;margin-bottom:6px}
.post .date{color:#576574;font-size:.8em;margin-bottom:10px}
.post p{line-height:1.7;color:#c8d6e5}
.nav{text-align:center;margin:20px 0}
.btn{display:inline-block;background:linear-gradient(135deg,#00d2ff,#3a7bd5);border:none;padding:10px 25px;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;text-decoration:none}
.empty{text-align:center;padding:40px;color:#576574}
</style></head><body><div class="container"><h1>Liveblog</h1><p class="desc">Blog ringan untuk update cepat</p><div id="posts"></div><div class="nav"><a href="/admin" class="btn">+ Tulis Postingan</a></div></div>
<script>let posts=[]
function render(){const c=document.getElementById('posts');if(posts.length===0){c.innerHTML='<div class="empty">Belum ada postingan</div>';return}c.innerHTML=posts.map(p=>'<div class="post"><h3>'+p.title+'</h3><div class="date">'+p.date+'</div><p>'+p.content+'</p><p><small>'+p.author+'</small></p></div>').join('')}
function fetchPosts(){fetch('/api/posts').then(r=>r.json()).then(d=>{posts=d;render()}).catch(()=>{})}
fetchPosts();setInterval(fetchPosts,10000)</script></body></html>'''
ADM = '''<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Admin Liveblog</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:#0a0e17;color:#c8d6e5;padding:20px}
.container{max-width:600px;margin:0 auto}
h1{text-align:center;margin:30px 0;background:linear-gradient(135deg,#00d2ff,#3a7bd5);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
form{background:#111827;border:1px solid #1e293b;border-radius:12px;padding:25px}
label{display:block;color:#8395a7;font-size:.85em;margin-bottom:5px;margin-top:15px}
label:first-child{margin-top:0}
input,textarea{width:100%;padding:10px;background:#0f1729;border:1px solid #1e293b;border-radius:8px;color:#c8d6e5;font-size:1em}
textarea{min-height:150px;resize:vertical}
button{background:linear-gradient(135deg,#00d2ff,#3a7bd5);border:none;padding:12px 30px;border-radius:8px;color:#fff;font-weight:600;cursor:pointer;font-size:1em;margin-top:10px}
a.back{display:block;text-align:center;margin-top:15px;color:#576574;text-decoration:none}
.msg{padding:10px;border-radius:8px;margin:10px 0;display:none}
.msg.success{display:block;background:#1a3a2a;border:1px solid #2ecc71;color:#2ecc71}
</style></head><body><div class="container"><h1>Tulis Postingan</h1><div id="msg" class="msg"></div>
<form id="postForm"><label>Judul</label><input type="text" id="title" required>
<label>Konten</label><textarea id="content" required></textarea>
<label>Author</label><input type="text" id="author" value="Admin">
<button type="submit">Publikasikan</button></form>
<a href="/" class="back">&larr; Kembali</a></div>
<script>
document.getElementById('postForm').addEventListener('submit',function(e){
e.preventDefault();const data={title:document.getElementById('title').value,content:document.getElementById('content').value,author:document.getElementById('author').value||'Admin'}
fetch('/api/posts',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})
.then(r=>r.json()).then(d=>{const m=document.getElementById('msg')
if(d.status==='ok'){m.className='msg success';m.textContent='Berhasil!';document.getElementById('title').value='';document.getElementById('content').value=''}
else{m.className='msg error';m.textContent='Gagal: '+d.message}}).catch(()=>{})})</script></body></html>'''
@app.route('/')
def index(): return render_template_string(IDX)
@app.route('/admin')
def admin(): return render_template_string(ADM)
@app.route('/api/posts', methods=['GET'])
def get_posts(): return jsonify(load_posts())
@app.route('/api/posts', methods=['POST'])
def create_post():
    data = request.get_json()
    if not data or not data.get('title') or not data.get('content'):
        return jsonify({'status':'error','message':'Judul dan konten diperlukan'}),400
    posts = load_posts()
    posts.insert(0,{'id':int(time.time()*1000),'title':data['title'],'content':data['content'],'author':data.get('author','Admin'),'date':datetime.now().strftime('%Y-%m-%d %H:%M')})
    save_posts(posts)
    return jsonify({'status':'ok'})
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=False)
LBPYEOF
    chmod +x "$LB_DIR/app.py"

    cat > /etc/systemd/system/liveblog.service << 'LBEOF'
[Unit]
Description=Liveblog - My Home Server v3
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
    ufw allow 8083/tcp comment 'Liveblog' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  LIVEBLOG SIAP!                                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:8083${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Admin : ${CYAN}http://$HOSTNAME:8083/admin${NC}                ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  6. CLOUDFLARED
# ============================================================
install_cloudflared() {
    print_step "6/7" "CLOUDFLARED - Cloudflare Tunnel"

    print_info "Mendownload Cloudflared..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O /usr/local/bin/cloudflared 2>/dev/null || \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -o /usr/local/bin/cloudflared 2>/dev/null || {
        print_error "Gagal mendownload Cloudflared"
        return
    }
    chmod +x /usr/local/bin/cloudflared
    print_success "Cloudflared terinstal"

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  KONFIGURASI CLOUDFLARED                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Untuk akses server dari internet:                 ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  1. cloudflared tunnel login                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  2. cloudflared tunnel create homeserver            ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  3. Edit ~/.cloudflared/config.yml:                 ${YELLOW}║${NC}"
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
    echo -e "${YELLOW}║${NC}  4. cloudflared service install                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if confirm "Login ke Cloudflare sekarang?"; then
        cloudflared tunnel login || print_warning "Login dibatalkan"
    fi
}

# ============================================================
#  7. TTYD + BTOP
# ============================================================
install_ttyd() {
    print_step "7/7" "TTYD - Terminal BTOP via Browser (port 7681)"

    print_info "Menginstal btop..."
    apt install -y btop 2>/dev/null || {
        wget -q "https://github.com/aristocratos/btop/releases/latest/download/btop-aarch64-linux-musl.tgz" -O /tmp/btop.tgz
        mkdir -p /tmp/btop && tar -xzf /tmp/btop.tgz -C /tmp/btop
        cp /tmp/btop/btop /usr/local/bin/btop
        chmod +x /usr/local/bin/btop
    }

    print_info "Menginstal TTYD..."
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) TTYD_ARCH="arm64" ;;
        armv7l|armhf)  TTYD_ARCH="armhf" ;;
        *)             TTYD_ARCH="arm64" ;;
    esac

    wget -q "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.$TTYD_ARCH" -O /usr/local/bin/ttyd 2>/dev/null || {
        print_warning "Gagal download ttyd, coba versi lain..."
        curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.$TTYD_ARCH" -o /usr/local/bin/ttyd 2>/dev/null || {
            print_error "Gagal mendownload ttyd"
            return
        }
    }
    chmod +x /usr/local/bin/ttyd

    cat > /etc/systemd/system/ttyd.service << 'TTYDEOF'
[Unit]
Description=TTYD - BTOP Terminal via Browser
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
    ufw allow 7681/tcp comment 'TTYD BTOP' >/dev/null 2>&1

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  TTYD SIAP!                                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Akses : ${CYAN}http://$HOSTNAME:7681${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  User  : admin / Pass: admin12345678                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  BTOP  : System monitor interaktif                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  INSTALL ALL-IN-ONE (urut dari paling penting)
# ============================================================
install_all() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}INSTALASI ALL-IN-ONE${NC}                                       ${RED}║${NC}"
    echo -e "${RED}║${NC}  Seluruh komponen akan diinstal berurutan:                   ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}1${NC}. Optimasi Sistem (WAJIB)                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}2${NC}. Dashboard Monitor                                    ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}3${NC}. File Manager (pilihan)                                ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}4${NC}. CCTV NVR (pilihan)                                    ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}5${NC}. Micro Blog (pilihan)                                  ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}6${NC}. Cloudflared                                          ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}7${NC}. TTYD + BTOP (pilihan)                                 ${RED}║${NC}"
    echo -e "${RED}║${NC}  Estimasi waktu: ~30-60 menit (tergantung koneksi)          ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! confirm "Mulai instalasi semua komponen?"; then
        print_info "Dibatalkan"
        return
    fi

    log "=== INSTALASI ALL-IN-ONE DIMULAI ==="
    install_optimization
    install_dashboard

    echo ""
    echo -ne "${YELLOW}[?]${NC} Instal File Manager? ${CYAN}[y/N]: ${NC}"
    read -r yn
    [[ "$yn" =~ ^[yY] ]] && install_filemanager

    echo ""
    echo -ne "${YELLOW}[?]${NC} Instal CCTV NVR? ${CYAN}[y/N]: ${NC}"
    read -r yn
    [[ "$yn" =~ ^[yY] ]] && install_nvr

    echo ""
    echo -ne "${YELLOW}[?]${NC} Instal Micro Blog? ${CYAN}[y/N]: ${NC}"
    read -r yn
    [[ "$yn" =~ ^[yY] ]] && install_blog

    install_cloudflared

    echo ""
    echo -ne "${YELLOW}[?]${NC} Instal TTYD + BTOP? ${CYAN}[y/N]: ${NC}"
    read -r yn
    [[ "$yn" =~ ^[yY] ]] && install_ttyd

    log "=== INSTALASI ALL-IN-ONE SELESAI ==="

    local HOSTNAME=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}INSTALASI MY HOME SERVER V3 SELESAI!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}AKSES LAYANAN:${NC}                                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Dashboard     : ${CYAN}http://$HOSTNAME${NC}                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  FileBrowser   : ${CYAN}http://$HOSTNAME:8080${NC}                  admin/admin12345678${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  FileGator     : ${CYAN}http://$HOSTNAME:8084${NC}                  admin/admin123${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  FileRise      : ${CYAN}http://$HOSTNAME:8085${NC}                  (buat user baru)${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Shinobi NVR   : ${CYAN}http://$HOSTNAME:8081${NC}/super             (setup awal)${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  MotionEye NVR : ${CYAN}http://$HOSTNAME:8765${NC}                  admin/admin12345678${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Frigate NVR   : ${CYAN}http://$HOSTNAME:8971${NC}                  (auto-generate)${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Ghost Blog    : ${CYAN}http://$HOSTNAME:2368${NC}/ghost             (setup awal)${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  WriteFreely   : ${CYAN}http://$HOSTNAME:8082${NC}                  (register baru)${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Liveblog      : ${CYAN}http://$HOSTNAME:8083${NC}                  /admin${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  BTOP Terminal : ${CYAN}http://$HOSTNAME:7681${NC}                  admin/admin12345678${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}FOLDER DATA:${NC}                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Document                                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Music                                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Pictures                                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  $DATA_DIR/My Videos/NVR (rekaman CCTV)                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}LOG INSTALASI:${NC} ${DIM}$INSTALL_LOG${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================
#  MAIN MENU
# ============================================================
show_menu() {
    print_banner
    echo -e "${BOLD}Pilih komponen (diurutkan dari yang paling penting):${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC})  Optimasi Sistem     ${DIM}(WAJIB - ZRAM, SWAP, tuning)${NC}"
    echo -e "  ${GREEN}2${NC})  Dashboard Monitor   ${DIM}(Grafik real-time, navigasi)${NC}"
    echo -e "  ${GREEN}3${NC})  File Manager         ${DIM}(FileBrowser/FileGator/FileRise)${NC}"
    echo -e "  ${GREEN}4${NC})  CCTV NVR             ${DIM}(Shinobi/MotionEye/Frigate)${NC}"
    echo -e "  ${GREEN}5${NC})  Micro Blog           ${DIM}(Ghost/WriteFreely/Liveblog)${NC}"
    echo -e "  ${GREEN}6${NC})  Cloudflared          ${DIM}(Cloudflare Tunnel)${NC}"
    echo -e "  ${GREEN}7${NC})  TTYD + BTOP          ${DIM}(Terminal via browser)${NC}"
    echo ""
    echo -e "  ${YELLOW}8${NC})  ${BOLD}INSTAL ALL-IN-ONE${NC}  ${DIM}(Semua komponen)${NC}"
    echo ""
    echo -e "  ${RED}0${NC})  Keluar"
    echo ""
    echo -ne "${YELLOW}Pilihan [0-8]: ${NC}"
    read -r menu_choice

    case "$menu_choice" in
        1) install_optimization ;;
        2) install_dashboard ;;
        3) install_filemanager ;;
        4) install_nvr ;;
        5) install_blog ;;
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
#  MAIN
# ============================================================
main() {
    echo "" > "$INSTALL_LOG"
    log "=== MY HOME SERVER v3 INSTALLER ==="

    check_root
    detect_sdcard
    check_armbian

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
