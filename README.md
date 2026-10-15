# Jarkom Modul 3: Curtain Protocol, Shibuya Incident

**Kelompok K-68 (Group C), Praktikum Komunikasi Data dan Jaringan Komputer 2026**

| | |
|---|---|
| Prefix IP | `192.245.0.0/16`, seluruh subnet memakai `/24` |
| Domain | `jujutsu.K68.com` |
| Domain search DHCP | `K68.com` |
| Database | `db_shibuya_K68` |
| Controller GNS3 | Group C, `http://10.4.89.250/` (wajib jaringan atau VPN ITS) |

## Anggota dan Pembagian

| Nama | NRP | Soal |
|---|---|---|
| Ryan Adya Purwanto | 5027231046 | 1 sampai 13 |
| Made Gde Krisna Wangsa | 5027201047 | 14 sampai 20 |

Laporan ini mencakup **soal 1 sampai 20**.

## Daftar Isi

- [Topologi](#topologi)
- [Pembagian IP](#pembagian-ip)
- [Catatan Teknis Penting](#catatan-teknis-penting)
- [Soal 1: Konfigurasi Router, Forwarding, dan NAT](#soal-1-konfigurasi-router-forwarding-dan-nat)
- [Soal 2: DHCP Server pada tengen](#soal-2-dhcp-server-pada-tengen)
- [Soal 3: DHCP Relay pada jichi](#soal-3-dhcp-relay-pada-jichi)
- [Soal 4: Dua Pool DHCP dengan DHCP Class](#soal-4-dua-pool-dhcp-dengan-dhcp-class)
- [Soal 5: Short Lease, Long Lease, dan DHCP Options](#soal-5-short-lease-long-lease-dan-dhcp-options)
- [Soal 6: Fixed Address untuk kugisaki](#soal-6-fixed-address-untuk-kugisaki)
- [Soal 7: Verifikasi Konfigurasi Seluruh Client](#soal-7-verifikasi-konfigurasi-seluruh-client)
- [Soal 8: Packet Capture DORA dan giaddr](#soal-8-packet-capture-dora-dan-giaddr)
- [Soal 9: Simulasi Gangguan Relay](#soal-9-simulasi-gangguan-relay)
- [Soal 10: Autostart dan Uji Restart Node](#soal-10-autostart-dan-uji-restart-node)
- [Soal 11: DNS Master dan Slave](#soal-11-dns-master-dan-slave)
- [Soal 12: A Record, CNAME, Reverse Zone, dan Forwarder](#soal-12-a-record-cname-reverse-zone-dan-forwarder)
- [Soal 13: Replikasi Database MariaDB](#soal-13-replikasi-database-mariadb)
- [Soal 14: Worker Backend (Frontend dan API)](#soal-14-worker-backend-frontend-dan-api)
- [Soal 15: Load Balancer Internal (geto)](#soal-15-load-balancer-internal-geto)
- [Soal 16: Path-Based Routing (gojo)](#soal-16-path-based-routing-gojo)
- [Soal 17: X-Real-IP, X-Forwarded-For, dan Verifikasi client_ip](#soal-17-x-real-ip-x-forwarded-for-dan-verifikasi-client_ip)
- [Soal 18: Kirara sebagai Backup + Passive Health Check](#soal-18-kirara-sebagai-backup--passive-health-check)
- [Soal 19: Proxy Caching dan Rate Limiting di gojo](#soal-19-proxy-caching-dan-rate-limiting-di-gojo)
- [Soal 20: Benchmark dengan Apache Benchmark dari kusakabe](#soal-20-benchmark-dengan-apache-benchmark-dari-kusakabe)
- [Struktur Repository](#struktur-repository)

---

## Topologi

Infrastruktur terdiri atas 21 node, 10 switch, dan 1 node NAT. Router `jichi` memakai lima interface, yaitu `eth0` menuju NAT dan `eth1` sampai `eth4` sebagai gateway Network 1 sampai Network 4.

```
NAT1 ----------------- jichi eth0

jichi eth1 --- Switch1 ................... utahime, shoko, gojo        [Net 1, DMZ]

jichi eth2 --- Switch2 --+-- Switch3 ----- itadori, fushiguro          [Net 2, Divisi A]
                         +-- Switch4 ----- zenin, okkotsu

jichi eth3 --- Switch5 --+-- Switch6 ----- ino, kusakabe               [Net 3, Divisi B]
                         +-- Switch7 ----- miwa, kugisaki

jichi eth4 --- Switch8 --+-- Switch9 ----- geto, maki, panda,          [Net 4, Data Center]
                         |                 nanami, todo, kirara
                         +-- Switch10 ---- tengen, yaga, inumaki
```

Switch anak (Switch3, Switch4, Switch6, Switch7, Switch9, Switch10) tidak tersambung langsung ke `jichi` melainkan ke switch induknya. Karena switch bekerja pada layer 2 dan tidak memisahkan jaringan, setiap rangkaian switch tersebut tetap membentuk **satu broadcast domain**, sehingga tetap satu subnet. Itulah sebabnya 10 switch hanya menghasilkan 4 subnet.

### Image Docker

Pembagian image mengikuti ketentuan soal.

| Image | Node |
|---|---|
| `ardhptr21/debinet:latest` | jichi, tengen, utahime, shoko, gojo, geto, maki, panda, nanami, todo, kirara, yaga, inumaki |
| `ardhptr21/alpinet:latest` | itadori, fushiguro, zenin, okkotsu, ino, kusakabe, miwa, kugisaki |

Perbedaan yang berpengaruh pada pengerjaan:

| | debinet (Debian) | alpinet (Alpine) |
|---|---|---|
| Manajer paket | `apt-get install` | `apk add` |
| DHCP client | `dhclient` | `udhcpc` |
| Sintaks ping | opsi bebas posisinya | opsi **wajib sebelum** target |

## Pembagian IP

| Interface jichi | Switch induk | Subnet | Isi |
|---|---|---|---|
| eth0 | NAT1 | DHCP dari NAT | WAN |
| eth1 | Switch1 | 192.245.1.0/24 | DMZ |
| eth2 | Switch2 | 192.245.2.0/24 | Divisi A |
| eth3 | Switch5 | 192.245.3.0/24 | Divisi B |
| eth4 | Switch8 | 192.245.4.0/24 | Data Center |

### Host dengan IP statis

| Node | IP | Gateway | Peran |
|---|---|---|---|
| jichi eth1 | 192.245.1.1 | | gateway Net 1 |
| jichi eth2 | 192.245.2.1 | | gateway Net 2 |
| jichi eth3 | 192.245.3.1 | | gateway Net 3 |
| jichi eth4 | 192.245.4.1 | | gateway Net 4 |
| utahime | 192.245.1.2 | 192.245.1.1 | DNS Master |
| shoko | 192.245.1.3 | 192.245.1.1 | DNS Slave |
| gojo | 192.245.1.4 | 192.245.1.1 | Public Reverse Proxy |
| geto | 192.245.4.2 | 192.245.4.1 | Internal Load Balancer |
| maki | 192.245.4.3 | 192.245.4.1 | Worker frontend |
| panda | 192.245.4.4 | 192.245.4.1 | Worker frontend |
| nanami | 192.245.4.5 | 192.245.4.1 | Worker API utama |
| todo | 192.245.4.6 | 192.245.4.1 | Worker API utama |
| kirara | 192.245.4.7 | 192.245.4.1 | Worker API cadangan |
| yaga | 192.245.4.8 | 192.245.4.1 | Database Master |
| inumaki | 192.245.4.9 | 192.245.4.1 | Database Slave |
| tengen | 192.245.4.10 | 192.245.4.1 | DHCP Server |

### Client dengan IP dari DHCP

Delapan client tidak diberi IP statis sama sekali, karena pemberian alamat lewat DHCP justru merupakan isi soal 2 sampai 7.

| Client | Network | MAC Address | Kebijakan |
|---|---|---|---|
| itadori | 2 | `02:42:17:51:a0:00` | Pool 1 |
| fushiguro | 2 | `02:42:1f:87:4e:00` | Pool 1 |
| zenin | 2 | `02:42:e8:81:d1:00` | Pool 2 |
| okkotsu | 2 | `02:42:21:d8:76:00` | Pool 2 |
| ino | 3 | `02:42:63:d1:c3:00` | Short lease |
| kusakabe | 3 | `02:42:07:5d:fd:00` | Short lease |
| miwa | 3 | `02:42:7a:74:c4:00` | Long lease |
| kugisaki | 3 | `02:42:60:61:67:00` | Fixed address |

## Catatan Teknis Penting

Tiga kendala lingkungan berikut menentukan cara seluruh konfigurasi ditulis.

### 1. Hanya `/root` dan `/etc/network/interfaces` yang bertahan saat node restart

Node Docker kembali ke kondisi image setiap kali dinyalakan ulang. Yang hilang bukan hanya berkas konfigurasi di `/etc`, melainkan juga **paket yang sudah di-install** dan isi `/var/lib`. Akibatnya:

- `/etc/dhcp`, `/etc/bind`, `/etc/mysql`, `/etc/resolv.conf` hilang
- `isc-dhcp-server`, `bind9`, `mariadb-server` perlu di-install ulang
- `/var/lib/dhcp/dhcpd.leases` dan `/var/lib/mysql` ikut kosong

Karena itu seluruh konfigurasi tidak diketik langsung ke lokasi aslinya, melainkan ditulis oleh **script yang disimpan di `/root`**, dan setiap script memuat perintah `apt-get install` di dalamnya. Script tersebut lalu dipanggil otomatis dari `/etc/network/interfaces` melalui baris `up`.

### 2. Editor network configuration GNS3 membuang baris yang mengandung karakter `>`

Perintah pengalihan output tidak boleh ditulis langsung di `interfaces`. Solusinya, perintah tersebut disembunyikan di dalam berkas script, dan `interfaces` hanya memanggilnya.

```
	up bash /root/dns.sh
```

### 3. Jumlah adapter dinaikkan per node, bukan lewat template global

`jichi` memerlukan lima interface. Karena praktikum berjalan di remote controller yang dipakai bersama seluruh kelompok, mengubah template global akan berdampak ke kelompok lain. Perubahan dilakukan melalui klik kanan node, lalu Configure, lalu tab Network, lalu Adapters diisi 8, dan hanya pada `jichi`.

---

## Soal 1: Konfigurasi Router, Forwarding, dan NAT

### Soal

> Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1 sampai eth4 menjadi gateway Network 1 sampai 4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

### Inti Soal

Tiga pekerjaan sekaligus:

1. Memberi alamat pada kelima interface `jichi`, dengan `eth0` memakai DHCP dari NAT dan `eth1` sampai `eth4` statis sebagai gateway tiap network.
2. Menyalakan IPv4 forwarding dan source NAT di `jichi`, supaya node internal dapat menjangkau internet.
3. Memberi IP statis pada 12 host infrastruktur, lalu membuktikan konektivitas.

Delapan client sengaja dibiarkan tanpa alamat, karena itu bagian soal 2 sampai 7.

### Langkah Pengerjaan

**Langkah 1.** Naikkan jumlah adapter `jichi` menjadi 8. Node harus dalam keadaan mati, lalu klik kanan node, Configure, tab Network, isi Adapters dengan 8.

**Langkah 2.** Pasang kabel. Urutan port di sisi `jichi` harus berurutan dari `eth0`, karena nama interface di dalam node ditentukan oleh nomor slot adapter di GNS3. Kabel yang tertukar menghasilkan konfigurasi yang benar secara sintaks tetapi terpasang di jaringan yang salah, dan kesalahan seperti itu tidak terlihat dari berkas konfigurasi.

**Langkah 3.** Isi `/etc/network/interfaces` pada `jichi` dan 12 host infrastruktur. Node harus mati, lalu klik kanan node dan pilih Edit network configuration.

**Langkah 4.** Nyalakan seluruh node, lalu buat berkas script di `/root` pada masing-masing node dan jalankan sekali secara manual.

### Konfigurasi

**jichi**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet dhcp
	up bash /root/nat.sh

auto eth1
iface eth1 inet static
	address 192.245.1.1
	netmask 255.255.255.0

auto eth2
iface eth2 inet static
	address 192.245.2.1
	netmask 255.255.255.0

auto eth3
iface eth3 inet static
	address 192.245.3.1
	netmask 255.255.255.0

auto eth4
iface eth4 inet static
	address 192.245.4.1
	netmask 255.255.255.0
```

Interface `eth1` sampai `eth4` sengaja **tidak diberi baris `gateway`**. Default gateway hanya boleh ada satu per host, dan bagi router jalur keluarnya adalah `eth0` yang sudah memperoleh default route otomatis dari DHCP NAT. Menambahkan gateway di interface LAN akan membuat router mengarahkan trafik keluar ke jaringan internalnya sendiri.

**jichi**, berkas `/root/nat.sh`

```bash
cat > /root/nat.sh <<'EOF'
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
EOF
chmod +x /root/nat.sh
bash /root/nat.sh
```

Pola `iptables -C ... || iptables -A ...` dipakai agar aturan hanya ditambahkan apabila belum ada. Tanpa pola ini, aturan MASQUERADE bertambah satu setiap kali node restart.

`MASQUERADE` dipilih daripada `SNAT` karena alamat `eth0` diperoleh lewat DHCP dan bisa berubah. `MASQUERADE` membaca alamat interface secara dinamis saat paket lewat, sedangkan `SNAT` memerlukan alamat yang ditulis tetap.

**12 host infrastruktur**, berkas `/etc/network/interfaces`

Pola sama untuk semuanya, hanya `address` dan `gateway` yang berbeda. Contoh pada `utahime`:

```
auto eth0
iface eth0 inet static
	address 192.245.1.2
	netmask 255.255.255.0
	gateway 192.245.1.1
	up bash /root/dns.sh
```

Daftar lengkap alamat ada pada tabel di bagian [Pembagian IP](#pembagian-ip). Berkas untuk seluruh node tersimpan di `config/interfaces/`.

**12 host infrastruktur**, berkas `/root/dns.sh`

```bash
cat > /root/dns.sh <<'EOF'
echo "nameserver 192.168.122.1" > /etc/resolv.conf
EOF
chmod +x /root/dns.sh
bash /root/dns.sh
```

Resolver awal ini wajib dipasang sejak sekarang, karena tanpa DNS perintah `apt-get` tidak dapat menerjemahkan `deb.debian.org`, sehingga seluruh instalasi paket pada soal berikutnya akan gagal.

### Pengujian

```bash
# di jichi
ip a
iptables -t nat -L POSTROUTING -n -v

# di utahime, Network 1
ping 192.245.1.1 -c 3
ping 8.8.8.8 -c 3

# di tengen, Network 4
ping 192.245.4.1 -c 3
ping 192.245.1.2 -c 3
```

**Hasil pada jichi**

![Soal 1 ip a jichi](screenshot/soal01-jichi-ip.png)

![Soal 1 iptables](screenshot/soal01-nat-masquerade.png)

**Hasil pada utahime dan tengen**

![Soal 1 ping utahime](screenshot/soal01-ping-utahime.png)

![Soal 1 ping tengen](screenshot/soal01-ping-tengen.png)

| Uji | Hasil |
|---|---|
| `ip a` di jichi | eth0 memperoleh `192.168.122.101/24`, eth1 sampai eth4 memegang `.1.1`, `.2.1`, `.3.1`, `.4.1` |
| `iptables -t nat -L POSTROUTING` | aturan `MASQUERADE` dengan `out: eth0` terpasang |
| utahime ke gateway | berhasil, `ttl=64` |
| utahime ke `8.8.8.8` | berhasil, `ttl=111`, membuktikan NAT bekerja |
| tengen ke gateway | berhasil, `ttl=64` |
| tengen ke utahime | berhasil, `ttl=63` |

Nilai TTL berguna sebagai penghitung hop. TTL awal Linux adalah 64, dan berkurang satu setiap melewati router. Nilai `ttl=64` berarti komunikasi sesubnet yang tidak melewati router sama sekali, sedangkan `ttl=63` berarti melewati tepat satu router, yaitu `jichi`.

### Catatan

Interface `eth5` sampai `eth7` muncul tanpa alamat pada `jichi`. Itu adapter cadangan hasil pengaturan Adapters bernilai 8, sementara yang dipakai hanya `eth0` sampai `eth4`.

---

## Soal 2: DHCP Server pada tengen

### Soal

> Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis. Konfigurasikan isc-dhcp-server pada 192.245.4.10. Deklarasikan Network 4 (192.245.4.0/24) sebagai subnet lokal tanpa pool dinamis, lalu siapkan scope DHCP untuk Network 2 (192.245.2.0/24) dan Network 3 (192.245.3.0/24). Validasi konfigurasi dan pastikan service aktif tanpa error "No subnet declaration".

### Inti Soal

Memasang `isc-dhcp-server` pada `tengen`, lalu menulis tiga deklarasi subnet:

1. Network 4 sebagai subnet lokal **tanpa range**, karena di situlah `tengen` berada.
2. Network 2 dan Network 3 sebagai scope yang benar-benar membagikan alamat.

Blok Network 4 yang kosong itu bukan kelalaian, melainkan justru kunci soal ini. Daemon `dhcpd` menolak start apabila interface yang didengarkan tidak memiliki deklarasi subnet yang cocok, dan penolakan itu muncul persis sebagai pesan `No subnet declaration for eth0` yang soal minta untuk dihindari.

### Langkah Pengerjaan

**Langkah 1.** Install `isc-dhcp-server` pada `tengen`.

**Langkah 2.** Tentukan interface yang didengarkan lewat `/etc/default/isc-dhcp-server`.

**Langkah 3.** Tulis `/etc/dhcp/dhcpd.conf` berisi tiga deklarasi subnet.

**Langkah 4.** Siapkan berkas lease kosong, validasi konfigurasi, lalu jalankan service.

Seluruhnya dibungkus dalam satu script di `/root/setup-dhcp.sh`, karena `/etc/dhcp` dan `/etc/default` termasuk yang hilang saat node restart.

### Konfigurasi

**tengen**, berkas `/root/setup-dhcp.sh`

```bash
cat > /root/setup-dhcp.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;

default-lease-time 600;
max-lease-time 7200;

option domain-name-servers 192.245.1.2, 192.245.1.3;

subnet 192.245.4.0 netmask 255.255.255.0 {
}

subnet 192.245.2.0 netmask 255.255.255.0 {
    range 192.245.2.10 192.245.2.35;
    option routers 192.245.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.2.255;
}

subnet 192.245.3.0 netmask 255.255.255.0 {
    range 192.245.3.10 192.245.3.89;
    option routers 192.245.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.3.255;
}
EOF

mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
SCRIPT
chmod +x /root/setup-dhcp.sh
bash /root/setup-dhcp.sh
```

### Pengujian

```bash
dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
```

![Soal 2 dhcpd.conf](screenshot/soal02-dhcpd-conf.png)

![Soal 2 validasi](screenshot/soal02-validasi.png)

| Uji | Hasil |
|---|---|
| `dhcpd -t -cf` | selesai tanpa error, menampilkan Config file, Database file, dan PID file |
| `service isc-dhcp-server status` | `Status of ISC DHCPv4 server: dhcpd is running` |
| Pesan `No subnet declaration for eth0` | tidak muncul |

Pada tahap ini client belum dapat memperoleh alamat, karena permintaan DHCP berupa broadcast yang tidak dapat menyeberangi router. Penyelesaiannya ada pada soal 3.

---

## Soal 3: DHCP Relay pada jichi

### Soal

> Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju tengen (192.245.4.10), menggunakan eth2 untuk Network 2 dan eth3 untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil memperoleh lease melalui relay.

### Inti Soal

Permintaan DHCP dikirim sebagai broadcast, dan broadcast tidak diteruskan oleh router. Akibatnya paket dari client Network 2 dan Network 3 berhenti di `jichi` dan tidak pernah sampai ke `tengen` yang berada di Network 4.

DHCP Relay menyelesaikannya dengan cara menangkap broadcast tersebut, lalu mengirimkannya ulang sebagai paket unicast ke alamat server. Relay juga menyisipkan alamat interface penerima ke dalam field `giaddr`, sehingga server tahu permintaan itu berasal dari subnet mana.

### Langkah Pengerjaan

**Langkah 1.** Install `isc-dhcp-relay` pada `jichi`, lalu tulis `/etc/default/isc-dhcp-relay`.

**Langkah 2.** Pastikan `/etc/network/interfaces` pada 8 client memakai mode DHCP.

**Langkah 3.** Minta alamat dari sisi client memakai `udhcpc`, lalu periksa hasilnya di server.

### Konfigurasi

**jichi**, berkas `/root/setup-relay.sh`

```bash
cat > /root/setup-relay.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-relay

cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.245.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EOF

service isc-dhcp-relay restart
SCRIPT
chmod +x /root/setup-relay.sh
bash /root/setup-relay.sh
```

Interface yang direlay adalah `eth2` untuk Network 2 dan `eth3` untuk Network 3, sesuai permintaan soal. Interface `eth4` ikut didaftarkan karena itulah jalur balasan dari `tengen` yang berada di Network 4.

**8 client alpinet**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet dhcp
```

### Pengujian

Perintah di sisi client memakai `udhcpc`, bukan `dhclient`, karena client memakai image alpinet yang berbasis BusyBox.

```bash
# di client, contoh itadori dan ino
udhcpc -i eth0
ip a show eth0
ip route

# di tengen
cat /var/lib/dhcp/dhcpd.leases
```

**Bukti relay aktif pada jichi**

![Soal 3 konfigurasi relay](screenshot/soal03-relay-config.png)

Perintah `pgrep -a dhcrelay` dipakai sebagai bukti, bukan `service isc-dhcp-relay status`, karena perintah status pada container ini tidak mengeluarkan output apa pun. Keluaran `pgrep` justru lebih informatif sebab menampilkan daftar interface dan alamat server dalam satu baris.

**Hasil pada client**

![Soal 3 client Network 2](screenshot/soal03-client-net2.png)

![Soal 3 client Network 3](screenshot/soal03-client-net3.png)

**Lease yang tercatat di tengen**

![Soal 3 dhcpd.leases](screenshot/soal03-leases.png)

| Uji | Hasil |
|---|---|
| itadori, Network 2 | memperoleh `192.245.2.12`, gateway `192.245.2.1` |
| ino, Network 3 | memperoleh `192.245.3.13`, gateway `192.245.3.1` |
| Baris `server 192.245.4.10` pada keluaran udhcpc | jawaban berasal dari tengen di Network 4 |
| `dhcpd.leases` di tengen | terisi lease kedua client |

Baris `udhcpc: lease of 192.245.2.12 obtained from 192.245.4.10` menjadi bukti utama. Alamat server yang disebut adalah `tengen`, bukan `jichi`, padahal client berada di subnet yang berbeda dari server. Itu hanya mungkin apabila relay bekerja.

---

## Soal 4: Dua Pool DHCP dengan DHCP Class

### Soal

> Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda, atur dua pool DHCP pada Network 2. Tetapkan Pool 1 (192.245.2.10 sampai 192.245.2.35) untuk itadori dan fushiguro, serta Pool 2 (192.245.2.70 sampai 192.245.2.95) untuk zenin dan okkotsu. Rentang 192.245.2.36 sampai 192.245.2.69 tidak boleh dialokasikan. Karena seluruh client berada pada subnet yang sama, gunakan DHCP class berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.

### Inti Soal

Keempat client berada di subnet yang sama, sehingga server tidak bisa membedakan mereka berdasarkan asal subnet. Pembeda satu-satunya adalah identitas masing-masing client, yaitu MAC Address.

Penyelesaiannya memakai dua mekanisme:

1. **DHCP class** untuk mengelompokkan client berdasarkan MAC.
2. **Blok pool** di dalam subnet, masing-masing dibatasi dengan `allow members of` sehingga hanya melayani anggota kelas tertentu.

Rentang terlarang `192.245.2.36` sampai `192.245.2.69` tidak perlu dilarang secara khusus. Cukup tidak ditulis di `range` mana pun, maka alamat tersebut tidak akan pernah dialokasikan.

### Langkah Pengerjaan

**Langkah 1.** Kumpulkan MAC Address keempat client Network 2.

```bash
ip link show eth0 | grep link/ether
```

**Langkah 2.** Tulis dua `class` dan dua blok `pool` di dalam `dhcpd.conf`.

**Langkah 3.** Hapus lease lama di `tengen`. Langkah ini wajib, sebab keempat client saat itu memegang alamat `.2.10` sampai `.2.13` yang kebetulan seluruhnya masuk rentang Pool 1. Tanpa pembersihan, server akan memberikan alamat lama yang sama dan pengujian tidak membuktikan apa pun.

**Langkah 4.** Minta ulang alamat di keempat client.

### Konfigurasi

**tengen**, berkas `/root/setup-dhcp.sh`

```bash
cat > /root/setup-dhcp.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;

default-lease-time 600;
max-lease-time 7200;

option domain-name-servers 192.245.1.2, 192.245.1.3;

class "pool1" {
    match if (substring(hardware,1,6) = 02:42:17:51:a0:00)
         or (substring(hardware,1,6) = 02:42:1f:87:4e:00);
}

class "pool2" {
    match if (substring(hardware,1,6) = 02:42:e8:81:d1:00)
         or (substring(hardware,1,6) = 02:42:21:d8:76:00);
}

subnet 192.245.4.0 netmask 255.255.255.0 {
}

subnet 192.245.2.0 netmask 255.255.255.0 {
    option routers 192.245.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.2.255;

    pool {
        allow members of "pool1";
        range 192.245.2.10 192.245.2.35;
    }

    pool {
        allow members of "pool2";
        range 192.245.2.70 192.245.2.95;
    }
}

subnet 192.245.3.0 netmask 255.255.255.0 {
    range 192.245.3.10 192.245.3.89;
    option routers 192.245.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.3.255;
}
EOF

mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
SCRIPT
chmod +x /root/setup-dhcp.sh
bash /root/setup-dhcp.sh
```

Ekspresi `substring(hardware,1,6)` dipakai karena field `hardware` pada ISC DHCP berukuran tujuh byte, yaitu satu byte tipe hardware diikuti enam byte MAC Address. Pengambilan dimulai dari offset 1 sepanjang 6 byte agar yang dibandingkan hanya MAC-nya.

**Pembersihan lease lama di tengen**

```bash
service isc-dhcp-server stop
echo -n > /var/lib/dhcp/dhcpd.leases
service isc-dhcp-server start
```

### Pengujian

```bash
# di keempat client Network 2
udhcpc -i eth0 -n
ip a show eth0
```

**MAC Address yang dikumpulkan**

![Soal 4 MAC address](screenshot/soal04-mac-net3.png)

**Konfigurasi hasil**

![Soal 4 dhcpd.conf dengan class](screenshot/soal04-dhcpd-class.png)

**Hasil Pool 1**

![Soal 4 Pool 1](screenshot/soal04-pool1.png)

**Hasil Pool 2**

![Soal 4 Pool 2](screenshot/soal04-pool2.png)

| Client | Alamat sebelum | Alamat sesudah | Pool |
|---|---|---|---|
| itadori | 192.245.2.12 | 192.245.2.12 | Pool 1 |
| fushiguro | 192.245.2.10 | 192.245.2.10 | Pool 1 |
| zenin | 192.245.2.11 | **192.245.2.71** | Pool 2 |
| okkotsu | 192.245.2.13 | **192.245.2.70** | Pool 2 |

Perpindahan zenin dan okkotsu keluar dari rentang lama merupakan bukti terkuat. Keduanya semula berada di `.2.11` dan `.2.13`, lalu setelah kelas diterapkan melompat ke `.2.71` dan `.2.70`. Perpindahan itu hanya mungkin terjadi apabila server benar-benar mencocokkan MAC mereka dengan kelas `pool2`.

---

## Soal 5: Short Lease, Long Lease, dan DHCP Options

### Soal

> Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network 3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe, serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short lease 192.245.3.10 sampai 192.245.3.89 dan pool long lease 192.245.3.100 sampai 192.245.3.199. Sesuaikan default-lease-time dan max-lease-time untuk setiap kelas client. Berikan pula DHCP options berupa DNS 192.245.1.2 dan 192.245.1.3, serta domain-search K68.com.

### Inti Soal

Pola yang sama dengan soal 4, yaitu memisahkan client memakai DHCP class, tetapi dengan tambahan pengaturan durasi lease per pool. Nilai `default-lease-time` dan `max-lease-time` ditulis **di dalam blok pool**, bukan di tingkat global, sehingga setiap kelompok client memperoleh durasi yang berbeda.

Nilai `max-lease-time` sengaja disamakan dengan `default-lease-time` agar durasi yang diterima client pasti persis sesuai permintaan soal dan mudah dibuktikan dari keluaran `udhcpc`.

### Langkah Pengerjaan

**Langkah 1.** Tambahkan dua kelas baru untuk Network 3.

**Langkah 2.** Pecah subnet Network 3 menjadi dua blok pool dengan rentang dan durasi masing-masing.

**Langkah 3.** Tambahkan DHCP options berupa DNS dan domain-search.

**Langkah 4.** Hapus lease lama, lalu minta ulang alamat di client Network 3.

### Konfigurasi

**tengen**, berkas `/root/setup-dhcp.sh`, bagian yang berubah dari soal 4:

```
option domain-name-servers 192.245.1.2, 192.245.1.3;
option domain-search "K68.com";

class "shortlease" {
    match if (substring(hardware,1,6) = 02:42:63:d1:c3:00)
         or (substring(hardware,1,6) = 02:42:07:5d:fd:00);
}

class "longlease" {
    match if (substring(hardware,1,6) = 02:42:7a:74:c4:00);
}

subnet 192.245.3.0 netmask 255.255.255.0 {
    option routers 192.245.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.3.255;
    option domain-name-servers 192.245.1.2, 192.245.1.3;
    option domain-search "K68.com";

    pool {
        allow members of "shortlease";
        range 192.245.3.10 192.245.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }

    pool {
        allow members of "longlease";
        range 192.245.3.100 192.245.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}
```

Berkas lengkap versi final tersedia di `config/tengen/setup-dhcp.sh`.

### Pengujian

```bash
# di ino, kusakabe, dan miwa
udhcpc -i eth0 -n
ip a show eth0
cat /etc/resolv.conf
```

**Konfigurasi hasil**

![Soal 5 class](screenshot/soal05-dhcpd-class.png)

![Soal 5 subnet Network 3](screenshot/soal05-dhcpd-net3.png)

**Hasil short lease**

![Soal 5 short lease](screenshot/soal05-short-lease.png)

**Hasil long lease**

![Soal 5 long lease](screenshot/soal05-long-lease.png)

| Client | Alamat | Lease time | Pool |
|---|---|---|---|
| ino | 192.245.3.13 | 1800 | short |
| kusakabe | 192.245.3.14 | 1800 | short |
| miwa | 192.245.3.12 menjadi **192.245.3.100** | 43200 | long |

miwa berpindah keluar dari rentang short lease menuju rentang long lease, dan durasinya berubah menjadi 43200 detik. Itu bukti bahwa kelas dan pengaturan lease per pool bekerja.

### Temuan

Keluaran `cat /etc/resolv.conf` pada client hanya memuat dua baris `nameserver`, tanpa baris `search`. Penyebabnya, `udhcpc` dari BusyBox tidak memproses option 119 (`domain-search`), melainkan hanya option 15 (`domain-name`) ketika menuliskan baris `search`.

Perbaikannya dilakukan pada soal 6 dengan menambahkan `option domain-name "K68.com";`. Option `domain-search` tetap dipertahankan karena itulah yang diminta soal 5.

### Catatan Penting

Setelah soal 5 diterapkan, **kugisaki tidak memperoleh alamat sama sekali**. Keadaan itu normal dan bukan kesalahan. kugisaki tidak termasuk kelas `shortlease` maupun `longlease`, sedangkan kedua pool Network 3 memakai `allow members of`, sehingga tidak ada pool yang bersedia melayaninya. Alamatnya baru muncul pada soal 6 melalui reservasi berbasis MAC.

---

## Soal 6: Fixed Address untuk kugisaki

### Soal

> Kugisaki ditetapkan sebagai personel VIP yang harus mempertahankan alamat yang sama setiap kali terhubung. Buat DHCP static lease berdasarkan MAC Address client tersebut dengan fixed address 192.245.3.99. Pastikan alamat ini berada di luar seluruh pool dinamis, validasi konfigurasi server, lalu renew lease pada client. Buktikan bahwa alamat yang diterima sesuai dengan reservasi.

### Inti Soal

Reservasi alamat tetap berdasarkan MAC, dibuat melalui `host declaration` di luar blok `subnet`. Alamat `192.245.3.99` berada pada celah `.3.90` sampai `.3.99`, yaitu di luar pool short lease (`.3.10` sampai `.3.89`) dan di luar pool long lease (`.3.100` sampai `.3.199`), sesuai permintaan soal.

Perlu dibedakan dua hal yang sering tertukar:

| | Diatur di mana | Cara kerja |
|---|---|---|
| IP statis | di client, berkas `/etc/network/interfaces` | client menetapkan sendiri alamatnya |
| Fixed address | di **server**, berkas `dhcpd.conf` | client tetap meminta lewat DHCP, server selalu menjawab dengan alamat yang sama berdasarkan MAC |

Soal meminta yang kedua. Apabila dikerjakan sebagai IP statis di client, hasil `ip a` memang terlihat benar, tetapi soal tidak terpenuhi.

### Langkah Pengerjaan

**Langkah 1.** Tambahkan `host declaration` untuk kugisaki pada `dhcpd.conf`.

**Langkah 2.** Tambahkan sekalian `option domain-name "K68.com";` untuk memperbaiki temuan pada soal 5.

**Langkah 3.** Validasi konfigurasi, restart service, lalu renew lease pada kugisaki beberapa kali.

### Konfigurasi

**tengen**, berkas `/root/setup-dhcp.sh` versi final

```bash
cat > /root/setup-dhcp.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y isc-dhcp-server

cat > /etc/default/isc-dhcp-server <<'EOF'
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat > /etc/dhcp/dhcpd.conf <<'EOF'
authoritative;

default-lease-time 600;
max-lease-time 7200;

option domain-name-servers 192.245.1.2, 192.245.1.3;
option domain-name "K68.com";
option domain-search "K68.com";

class "pool1" {
    match if (substring(hardware,1,6) = 02:42:17:51:a0:00)
         or (substring(hardware,1,6) = 02:42:1f:87:4e:00);
}

class "pool2" {
    match if (substring(hardware,1,6) = 02:42:e8:81:d1:00)
         or (substring(hardware,1,6) = 02:42:21:d8:76:00);
}

class "shortlease" {
    match if (substring(hardware,1,6) = 02:42:63:d1:c3:00)
         or (substring(hardware,1,6) = 02:42:07:5d:fd:00);
}

class "longlease" {
    match if (substring(hardware,1,6) = 02:42:7a:74:c4:00);
}

host kugisaki {
    hardware ethernet 02:42:60:61:67:00;
    fixed-address 192.245.3.99;
}

subnet 192.245.4.0 netmask 255.255.255.0 {
}

subnet 192.245.2.0 netmask 255.255.255.0 {
    option routers 192.245.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.2.255;

    pool {
        allow members of "pool1";
        range 192.245.2.10 192.245.2.35;
    }

    pool {
        allow members of "pool2";
        range 192.245.2.70 192.245.2.95;
    }
}

subnet 192.245.3.0 netmask 255.255.255.0 {
    option routers 192.245.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.245.3.255;
    option domain-name-servers 192.245.1.2, 192.245.1.3;
    option domain-name "K68.com";
    option domain-search "K68.com";

    pool {
        allow members of "shortlease";
        range 192.245.3.10 192.245.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }

    pool {
        allow members of "longlease";
        range 192.245.3.100 192.245.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }
}
EOF

mkdir -p /var/lib/dhcp
touch /var/lib/dhcp/dhcpd.leases

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
SCRIPT
chmod +x /root/setup-dhcp.sh
bash /root/setup-dhcp.sh
```

Blok `host kugisaki` ditulis di luar seluruh blok `subnet`. ISC DHCP memproses `host declaration` secara terpisah dari pool, sehingga kugisaki tetap dilayani meskipun tidak termasuk kelas mana pun.

### Pengujian

```bash
# di kugisaki, diulang beberapa kali
udhcpc -i eth0 -n
ip a show eth0
cat /etc/resolv.conf
```

**Konfigurasi host declaration**

![Soal 6 host declaration](screenshot/soal06-host-declaration.png)

**Hasil pada kugisaki**

![Soal 6 kugisaki fixed address](screenshot/soal06-kugisaki-fixed.png)

**Perbaikan baris search pada resolv.conf**

![Soal 6 resolv.conf search](screenshot/soal06-resolv-search.png)

| Uji | Hasil |
|---|---|
| kugisaki meminta alamat, percobaan 1 | 192.245.3.99 |
| kugisaki meminta alamat, percobaan 2 | 192.245.3.99 |
| kugisaki meminta alamat, percobaan 3 | 192.245.3.99 |
| `cat /etc/resolv.conf` | sudah memuat `search K68.com` |

### Temuan

Perintah `grep 192.245.3.99 /var/lib/dhcp/dhcpd.leases` menghasilkan keluaran kosong, dan hal itu memang benar. Berkas `dhcpd.leases` hanya mencatat lease dinamis yang diambil dari pool. Reservasi melalui `host declaration` merupakan konfigurasi, bukan lease, sehingga tidak pernah dicatat di sana.

Lease time yang diterima kugisaki adalah 600 detik, yaitu nilai `default-lease-time` global, bukan 1800 atau 43200. Hal itu benar karena kugisaki berada di luar kedua blok pool, sehingga tidak terkena pengaturan lease milik pool mana pun. Soal juga tidak menentukan durasi lease untuk kugisaki.

---

## Soal 7: Verifikasi Konfigurasi Seluruh Client

### Soal

> Setelah aturan alokasi diterapkan, pastikan setiap client menerima konfigurasi jaringan sesuai wilayahnya: subnet mask 255.255.255.0 (/24), gateway dan broadcast address yang benar, DNS 192.245.1.2 serta 192.245.1.3, dan domain-search yang ditentukan. Periksa IP address dan routing seluruh client Divisi A dan Divisi B, kemudian cocokkan lease dengan /var/lib/dhcp/dhcpd.leases pada tengen. Pastikan tidak ada alamat yang bertabrakan atau berada di luar kebijakan pool.

### Inti Soal

Tidak ada konfigurasi baru. Soal ini murni verifikasi menyeluruh terhadap delapan client, dengan tiga hal yang harus dipastikan:

1. Setiap client menerima subnet mask, gateway, broadcast, DNS, dan domain-search yang benar.
2. Tidak ada alamat yang bertabrakan.
3. Tidak ada alamat yang berada di luar kebijakan pool.

### Langkah Pengerjaan

**Langkah 1.** Jalankan satu perintah gabungan pada setiap client agar seluruh informasi tampil ringkas dalam satu layar.

**Langkah 2.** Tampilkan daftar lease aktif pada `tengen`, lalu cocokkan.

### Perintah Pengujian

**Di setiap client**

```bash
echo "=== $(hostname) ==="; ip -4 addr show eth0 | grep inet; ip route | grep default; cat /etc/resolv.conf
```

**Di tengen**

```bash
awk '/^lease/{ip=$2} /binding state active/{print ip}' /var/lib/dhcp/dhcpd.leases | sort -u
```

Perintah `awk` dipakai agar keluaran hanya berisi daftar alamat yang berstatus aktif. Menampilkan isi `dhcpd.leases` secara utuh menghasilkan ratusan baris yang menyulitkan pencocokan.

### Pengujian

**Client Divisi A**

![Soal 7 client Network 2](screenshot/soal07-client-net2.png)

**Client Divisi B**

![Soal 7 client Network 3](screenshot/soal07-client-net3.png)

**Lease aktif di tengen**

![Soal 7 lease aktif](screenshot/soal07-leases-aktif.png)

| Client | IP | Gateway | Broadcast | Kebijakan |
|---|---|---|---|---|
| itadori | 192.245.2.12 | 192.245.2.1 | 192.245.2.255 | Pool 1 |
| fushiguro | 192.245.2.10 | 192.245.2.1 | 192.245.2.255 | Pool 1 |
| zenin | 192.245.2.71 | 192.245.2.1 | 192.245.2.255 | Pool 2 |
| okkotsu | 192.245.2.70 | 192.245.2.1 | 192.245.2.255 | Pool 2 |
| ino | 192.245.3.13 | 192.245.3.1 | 192.245.3.255 | Short lease |
| kusakabe | 192.245.3.14 | 192.245.3.1 | 192.245.3.255 | Short lease |
| miwa | 192.245.3.100 | 192.245.3.1 | 192.245.3.255 | Long lease |
| kugisaki | 192.245.3.99 | 192.245.3.1 | 192.245.3.255 | Fixed address |

Seluruh client juga memuat `search K68.com` beserta dua baris nameserver `192.245.1.2` dan `192.245.1.3`.

Tiga hal yang diminta soal terpenuhi:

1. **Tidak ada tabrakan.** Delapan alamat di atas seluruhnya berbeda.
2. **Tidak ada yang di luar kebijakan.** Tidak satu pun alamat jatuh pada rentang terlarang `192.245.2.36` sampai `192.245.2.69`.
3. **Setiap client sesuai wilayahnya.** Client Network 2 memperoleh alamat `192.245.2.x`, client Network 3 memperoleh `192.245.3.x`.

Daftar lease aktif pada `tengen` berisi tujuh alamat, yaitu delapan client dikurangi kugisaki. kugisaki tidak muncul karena memakai `fixed-address` yang tidak dicatat sebagai lease dinamis.

### Temuan

Berkas `dhcpd.leases` memuat beberapa entri berstatus `binding state abandoned` untuk alamat `.3.10`, `.3.11`, dan `.3.12`. Entri tersebut merupakan sisa lease lama dari sebelum kebijakan pool diterapkan. Saat server hendak menawarkan alamat itu kepada client lain, server memeriksanya terlebih dahulu dan mendapati alamat tersebut masih terpakai oleh client lama yang belum melepas, sehingga ditandai `abandoned`.

Entri itu tidak mengganggu, sebab penyaringan `binding state active` sudah mengeluarkannya dari daftar, dan tidak ada satu pun alamat aktif yang bertabrakan.

---

## Soal 8: Packet Capture DORA dan giaddr

### Soal

> Sebelum Curtain dibuka kembali, buktikan bahwa proses pemberian alamat berjalan sesuai protokol. Lakukan packet capture saat salah satu client Network 2 atau Network 3 meminta lease baru. Gunakan tcpdump pada tengen atau jalur menuju Data Center untuk menunjukkan urutan DHCPDISCOVER, DHCPOFFER, DHCPREQUEST, DHCPACK. Identifikasi alamat server, alamat yang diberikan, lease time, dan field giaddr. Pastikan nilai giaddr sesuai dengan interface jichi yang menerima request dari subnet client.

### Inti Soal

Merekam empat paket pertukaran DHCP, lalu mengidentifikasi empat nilai di dalamnya. Nilai yang paling penting adalah `giaddr`, yaitu alamat interface relay yang menerima permintaan.

`giaddr` adalah mekanisme yang membuat satu server DHCP dapat melayani banyak subnet sekaligus. `tengen` tidak terhubung langsung ke Network 2 maupun Network 3, sehingga ia tidak dapat menebak asal permintaan dari alamat pengirim. Yang dibaca adalah `giaddr` yang disisipkan relay, lalu server memilih deklarasi subnet yang cocok dengan nilai tersebut.

### Langkah Pengerjaan

**Langkah 1.** Install `tcpdump` pada `tengen`, lalu mulai capture pada port DHCP.

**Langkah 2.** Pada jendela terpisah, minta lease baru dari salah satu client.

**Langkah 3.** Hentikan capture, lalu identifikasi keempat nilai yang diminta.

**Langkah 4.** Ulangi dengan client dari network yang berbeda untuk membuktikan `giaddr` memang mengikuti interface penerima.

### Perintah

**Di tengen**

```bash
apt-get install -y tcpdump
tcpdump -i eth0 -nv port 67 or port 68
```

**Di client**

```bash
udhcpc -i eth0 -n
```

### Pengujian

**Capture dari client Network 3, yaitu ino**

![Soal 8 DORA Network 3](screenshot/soal08-dora-net3.png)

**Capture dari client Network 2, yaitu itadori**

![Soal 8 DORA Network 2](screenshot/soal08-dora-net2.png)

Urutan empat paket terekam lengkap pada kedua capture:

| Urutan | Arah | Jenis |
|---|---|---|
| 1 | jichi menuju tengen | DHCPDISCOVER |
| 2 | tengen menuju jichi | DHCPOFFER |
| 3 | jichi menuju tengen | DHCPREQUEST |
| 4 | tengen menuju jichi | DHCPACK |

Empat nilai yang diminta soal:

| Yang dicari | Field tcpdump | ino (Net 3) | itadori (Net 2) |
|---|---|---|---|
| Alamat server | `Server-ID`, option 54 | 192.245.4.10 | 192.245.4.10 |
| Alamat yang diberikan | `Your-IP` | 192.245.3.13 | 192.245.2.12 |
| Lease time | `Lease-Time`, option 51 | 1695 | 529 |
| **giaddr** | `Gateway-IP` | **192.245.3.1** | **192.245.2.1** |

Nilai `Gateway-IP` berubah mengikuti interface `jichi` yang menerima permintaan, yaitu `eth3` untuk Network 3 dan `eth2` untuk Network 2. Dua capture berdampingan itu membuktikan mekanisme `giaddr` bekerja sebagaimana mestinya.

Terlihat pula bahwa paket datang dari alamat `jichi`, bukan dari alamat client. Hal itu merupakan konsekuensi relay yang mengirim ulang broadcast client sebagai unicast atas namanya sendiri.

### Catatan

Nilai `Lease-Time` yang terekam adalah 1695 dan 529, bukan 1800 dan 600. Penyebabnya, kedua client sudah memegang lease sebelumnya, sehingga server memberikan **sisa waktu** lease yang masih berjalan, bukan menghitung ulang dari awal.

---

## Soal 9: Simulasi Gangguan Relay

### Soal

> Untuk menguji kesiapan pada kondisi darurat, lakukan simulasi gangguan dengan menghentikan layanan DHCP Relay pada jichi. Amati gejala yang muncul pada client, lalu aktifkan kembali layanan dan pastikan client dapat kembali memperoleh konfigurasi jaringan seperti semula.

### Inti Soal

Tiga tahap, yaitu matikan relay, amati gejala pada client, lalu nyalakan kembali dan buktikan client pulih. Yang dinilai adalah gejalanya, bukan sekadar perintah `stop` dan `start`.

Gejala yang diharapkan muncul karena permintaan DHCP dikirim secara **broadcast**, sedangkan broadcast tidak menyeberangi router. Tanpa relay, paket dari ino berhenti di `jichi` dan tidak pernah sampai ke `tengen` di Network 4, meskipun `tengen` sendiri tetap sehat.

### Langkah Pengerjaan

**Langkah 1.** Hentikan layanan relay pada `jichi`.

**Langkah 2.** Pada client ino, hapus alamat yang sudah dipegang, lalu minta alamat baru dengan batas percobaan pendek agar cepat menyerah.

**Langkah 3.** Nyalakan kembali relay pada `jichi`.

**Langkah 4.** Minta alamat lagi dari ino, lalu pastikan alamat dan gateway kembali seperti semula.

### Perintah

**Tahap 1, di jichi**

```bash
service isc-dhcp-relay stop
pgrep -a dhcrelay
```

**Tahap 2, di ino**

```bash
ip addr flush dev eth0
udhcpc -i eth0 -n -t 4 -T 2
ip a show eth0
```

Opsi `-t 4 -T 2` membatasi percobaan menjadi 4 kali dengan selang 2 detik, supaya `udhcpc` segera menyerah dan gejala kegagalan terlihat jelas tanpa menunggu lama.

**Tahap 3, di jichi**

```bash
service isc-dhcp-relay start
pgrep -a dhcrelay
```

**Tahap 4, di ino**

```bash
udhcpc -i eth0 -n
ip a show eth0
ip route
```

### Pengujian

**Relay dihentikan**

![Soal 9 relay dimatikan](screenshot/soal09-relay-mati.png)

**Gejala pada client**

![Soal 9 client gagal](screenshot/soal09-client-gagal.png)

Gejala yang terekam:

1. Baris `broadcasting discover` tercetak empat kali berturut-turut.
2. Tidak ada satu pun baris `broadcasting select` ataupun `lease of ... obtained`.
3. Proses berakhir dengan `no lease, failing`.
4. Hasil `ip a` setelahnya tidak memuat alamat IPv4 sama sekali.

**Relay dinyalakan kembali**

![Soal 9 relay dihidupkan](screenshot/soal09-relay-hidup.png)

**Client pulih**

![Soal 9 client pulih](screenshot/soal09-client-pulih.png)

| Tahap | Hasil pada ino |
|---|---|
| Relay mati | tidak ada alamat IPv4, `no lease, failing` |
| Relay hidup | 192.245.3.13, dari pool short lease |
| Gateway setelah pulih | default via 192.245.3.1 |

### Catatan

Setelah `service isc-dhcp-relay stop`, perintah `pgrep -a dhcrelay` masih menampilkan `201 [dhcrelay]`. Tanda kurung siku berarti proses sudah mati tetapi belum dibersihkan dari tabel proses, yaitu kondisi defunct atau zombie, bukan berarti masih berjalan. Buktinya, setelah `start` nilai PID berubah dari 201 menjadi 244, yang berarti proses lama memang sudah hilang dan diganti proses baru.

Bukti yang paling kuat untuk soal ini bukan keluaran `pgrep`, melainkan gejala kegagalan total pada client.

---

## Soal 10: Autostart dan Uji Restart Node

### Soal

> Agar jaringan dapat kembali beroperasi tanpa intervensi manual, pastikan layanan DHCP Server pada tengen dan DHCP Relay pada jichi berjalan otomatis saat node dinyalakan. Lakukan uji restart node, kemudian buktikan bahwa seluruh client tetap memperoleh alamat sesuai kebijakan yang telah ditetapkan.

### Inti Soal

Memasang autostart, lalu benar-benar merestart node dan membuktikan seluruh kebijakan dari soal 2 sampai soal 6 tetap berlaku tanpa menjalankan satu pun script secara manual.

Pada lingkungan praktikum ini, saat node direstart yang hilang bukan hanya berkas konfigurasi, tetapi juga **paket yang sudah di-install**. Karena itu script autostart wajib memuat `apt-get install` di dalamnya, bukan hanya `service restart`.

Hanya dua lokasi yang bertahan, yaitu `/root` dan `/etc/network/interfaces`. Autostart dipasang dengan menambahkan baris `up bash /root/<script>.sh` pada berkas interfaces, karena berkas itu dibaca setiap kali interface dinyalakan.

### Langkah Pengerjaan

**Langkah 1.** Matikan node `tengen`, lalu edit `/etc/network/interfaces` melalui menu Edit network configuration dan tambahkan dua baris `up`.

**Langkah 2.** Lakukan hal yang sama pada `jichi`, dengan baris `up` ditaruh pada blok `eth4`.

**Langkah 3.** Nyalakan kedua node, tunggu dua sampai tiga menit sampai proses install selesai.

**Langkah 4.** Verifikasi tanpa menjalankan script apa pun secara manual.

**Langkah 5.** Minta lease baru dari seluruh client, lalu cocokkan dengan kelima kebijakan.

### Konfigurasi

**tengen**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.4.10
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-dhcp.sh
```

Urutan dua baris `up` itu penting. Berkas `dns.sh` memasang resolver terlebih dahulu, sebab `setup-dhcp.sh` memuat `apt-get` yang membutuhkan DNS agar dapat menjangkau repositori.

**jichi**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet dhcp
	up bash /root/nat.sh

auto eth1
iface eth1 inet static
	address 192.245.1.1
	netmask 255.255.255.0

auto eth2
iface eth2 inet static
	address 192.245.2.1
	netmask 255.255.255.0

auto eth3
iface eth3 inet static
	address 192.245.3.1
	netmask 255.255.255.0

auto eth4
iface eth4 inet static
	address 192.245.4.1
	netmask 255.255.255.0
	up bash /root/setup-relay.sh
```

Baris `up bash /root/setup-relay.sh` sengaja diletakkan pada blok `eth4`, bukan `eth0`. Berkas interfaces diproses dari atas ke bawah, sehingga saat blok `eth4` dijalankan, interface `eth2`, `eth3`, dan `eth4` sudah hidup. Relay membutuhkan ketiganya karena berkas `/etc/default/isc-dhcp-relay` menyebut `INTERFACES="eth2 eth3 eth4"`. Apabila ditaruh pada `eth0`, relay akan dijalankan saat `eth2` sampai `eth4` belum ada, dan daemon gagal mengikat interface.

Perlu diingat, editor Edit network configuration pada GNS3 membuang baris yang memuat karakter `>`. Oleh sebab itu seluruh perintah redirect disembunyikan di dalam berkas `.sh` di `/root`, dan interfaces hanya memanggilnya.

### Pengujian

**Verifikasi di jichi setelah restart**

```bash
pgrep -a dhcrelay
iptables -t nat -L POSTROUTING -n -v
ip -4 addr show eth4
```

![Soal 10 autostart jichi](screenshot/soal10-jichi-autostart.png)

**Verifikasi di tengen setelah restart**

```bash
service isc-dhcp-server status
cat /etc/dhcp/dhcpd.conf
```

![Soal 10 autostart tengen](screenshot/soal10-tengen-autostart.png)

**Kebijakan Network 2 setelah restart**

![Soal 10 kebijakan Network 2](screenshot/soal10-kebijakan-net2.png)

**Kebijakan Network 3 setelah restart**

![Soal 10 kebijakan Network 3](screenshot/soal10-kebijakan-net3.png)

Hasil verifikasi tanpa intervensi manual sama sekali:

| Yang diperiksa | Hasil |
|---|---|
| dhcrelay di jichi | hidup sendiri, PID 468 |
| MASQUERADE di jichi | terpasang, 12 paket tercatat lewat |
| eth4 jichi | 192.245.4.1 |
| dhcpd di tengen | running |
| dhcpd.conf di tengen | lengkap, termasuk seluruh deklarasi class |

Kelima kebijakan alokasi tetap berlaku:

| Kebijakan | Client | Alamat | Lease |
|---|---|---|---|
| Pool 1 | itadori | 192.245.2.11 | 600 |
| Pool 1 | fushiguro | 192.245.2.12 | 600 |
| Pool 2 | zenin | 192.245.2.71 | 600 |
| Pool 2 | okkotsu | 192.245.2.72 | 600 |
| Short lease | ino | 192.245.3.10 | 1800 |
| Long lease | miwa | 192.245.3.100 | 43200 |
| Fixed address | kugisaki | 192.245.3.99 | 600 |

### Catatan

Alamat pada Network 2 bergeser dibandingkan sebelum restart, misalnya itadori dari `.2.12` menjadi `.2.11` dan okkotsu dari `.2.70` menjadi `.2.72`. Penyebabnya, berkas `/var/lib/dhcp/dhcpd.leases` ikut terhapus saat node direstart, sehingga server membagikan ulang alamat secara bebas **di dalam** pool masing-masing. Pergeseran itu bukan kesalahan, sebab yang ditentukan soal adalah rentang pool per client, bukan angka pasti.

---

## Soal 11: DNS Master dan Slave

### Soal

> Bangun layanan DNS internal untuk domain jujutsu.K68.com. utahime berperan sebagai DNS master dan shoko sebagai DNS slave. Pastikan kedua server memiliki data zona yang konsisten, slave memperoleh data melalui zone transfer dari master, dan perubahan pada master terbawa ke slave secara otomatis.

### Inti Soal

Membangun BIND9 pada dua node dengan relasi master dan slave, lalu membuktikan bahwa zone transfer berjalan otomatis. Bukti yang dinilai bukan sekadar kedua server dapat menjawab query, melainkan bahwa **perubahan pada master terbawa ke slave tanpa slave disentuh**.

Mekanismenya bersandar pada nomor `Serial` di dalam record SOA. Setiap kali isi zona diubah, serial harus dinaikkan. Master mengirim notify, slave membandingkan serial miliknya dengan serial master, dan apabila serial master lebih besar barulah slave menarik salinan baru. Apabila serial tidak dinaikkan, slave menganggap datanya sudah mutakhir dan tidak melakukan apa pun, meskipun isi zona di master sudah berbeda.

Seluruh konfigurasi ditulis melalui `/root/setup-dns.sh` karena direktori `/etc/bind` hilang setiap kali node direstart.

### Langkah Pengerjaan

**Langkah 1.** Tulis `setup-dns.sh` pada `utahime` yang memuat install BIND9, `named.conf.local` bertipe master, `named.conf.options`, dan berkas zona.

**Langkah 2.** Tulis `setup-dns.sh` pada `shoko` yang memuat `named.conf.local` bertipe slave dengan `masters` menunjuk ke `192.245.1.2`.

**Langkah 3.** Jalankan kedua script, lalu uji dengan `dig` ke kedua server.

**Langkah 4.** Naikkan serial pada master, jalankan ulang script master, lalu buktikan serial pada slave ikut naik tanpa disentuh.

### Konfigurasi

**utahime**, berkas `/root/setup-dns.sh`

```bash
cat > /root/setup-dns.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 dnsutils
ln -sf /etc/init.d/named /etc/init.d/bind9
mkdir -p /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K68.com" {
    type master;
    notify yes;
    also-notify { 192.245.1.3; };
    allow-transfer { 192.245.1.3; };
    file "/etc/bind/jarkom/jujutsu.K68.com";
};
EOF

cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

cat > /etc/bind/jarkom/jujutsu.K68.com <<'EOF'
$TTL    604800
@       IN      SOA     utahime.jujutsu.K68.com. root.jujutsu.K68.com. (
                        2026101501 ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.K68.com.
@       IN      NS      shoko.jujutsu.K68.com.

utahime IN      A       192.245.1.2
shoko   IN      A       192.245.1.3
EOF

service bind9 restart
SCRIPT
chmod +x /root/setup-dns.sh
bash /root/setup-dns.sh
```

Arti tiga direktif transfer pada blok zona master:

| Direktif | Fungsi |
|---|---|
| `notify yes` | master memberi tahu slave setiap kali zona berubah |
| `also-notify { 192.245.1.3; }` | tujuan notify ditegaskan ke alamat shoko |
| `allow-transfer { 192.245.1.3; }` | hanya shoko yang diizinkan menarik salinan zona |

**shoko**, berkas `/root/setup-dns.sh`

```bash
cat > /root/setup-dns.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 dnsutils
ln -sf /etc/init.d/named /etc/init.d/bind9
mkdir -p /etc/bind/jarkom
chown -R bind:bind /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K68.com" {
    type slave;
    masters { 192.245.1.2; };
    file "/etc/bind/jarkom/jujutsu.K68.com";
};
EOF

cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

service bind9 restart
SCRIPT
chmod +x /root/setup-dns.sh
bash /root/setup-dns.sh
```

Baris `chown -R bind:bind /etc/bind/jarkom` bersifat wajib. Berkas hasil zone transfer ditulis oleh proses `named` yang berjalan sebagai user `bind`, sehingga direktori tujuannya harus dimiliki user tersebut. Tanpa baris itu transfer gagal dengan galat permission denied dan slave tetap kosong.

### Pengujian

**Konfigurasi master**

![Soal 11 config utahime](screenshot/soal11-config-utahime.png)

**Konfigurasi slave**

![Soal 11 config shoko](screenshot/soal11-config-shoko.png)

```bash
dig @192.245.1.2 jujutsu.K68.com NS
dig @192.245.1.3 jujutsu.K68.com NS
```

![Soal 11 dig NS kedua server](screenshot/soal11-dig-ns.png)

Kedua server menjawab dengan flag `aa`, yaitu authoritative answer, dan `ANSWER: 2` yang berisi kedua nameserver. Flag `aa` penting karena membuktikan server menjawab dari data zona yang dimilikinya sendiri, bukan dari cache.

**Uji sinkronisasi dengan menaikkan serial**

```bash
# di utahime, ubah serial menjadi 2026101502 di dalam setup-dns.sh
bash /root/setup-dns.sh

# lalu dari mana saja
dig @192.245.1.2 jujutsu.K68.com SOA +short
dig @192.245.1.3 jujutsu.K68.com SOA +short
```

![Soal 11 menaikkan serial](screenshot/soal11-naikkan-serial.png)

![Soal 11 serial tersinkron](screenshot/soal11-serial-sync.png)

| Keadaan | Serial utahime | Serial shoko |
|---|---|---|
| Sebelum | 2026101501 | 2026101501 |
| Sesudah | 2026101502 | 2026101502 |

Serial pada shoko ikut naik tanpa satu pun perintah dijalankan di sana. Itu bukti bahwa zone transfer otomatis bekerja.

### Catatan

Jangan menampilkan berkas zona di sisi slave dengan `cat`. BIND menyimpan zona hasil transfer dalam format raw atau biner, sehingga keluarannya berupa karakter acak. Untuk membuktikan peran slave, cukup tampilkan `named.conf.local` yang memperlihatkan `type slave`, lalu buktikan isi datanya melalui `dig`.

Hal yang sama berlaku pada `named-checkzone` di slave, yang selalu menghasilkan galat palsu untuk alasan yang sama.

---

## Soal 12: A Record, CNAME, Reverse Zone, dan Forwarder

### Soal

> Tambahkan konfigurasi DNS agar domain jujutsu.K68.com mengarah ke gojo sebagai titik masuk publik, buat alias www yang mengarah ke domain utama, siapkan reverse zone agar IP gojo dapat dilacak kembali ke domain resminya, dan tambahkan forwarder agar client tetap dapat melakukan resolusi domain internet.

### Inti Soal

Empat penambahan pada DNS yang sudah berdiri di soal 11:

| Yang diminta | Jenis record | Isi |
|---|---|---|
| Domain mengarah ke gojo | A pada apex | `@ IN A 192.245.1.4` |
| Alias www | CNAME | `www IN CNAME jujutsu.K68.com.` |
| IP gojo dilacak ke domain | zona reverse berisi PTR | `4 IN PTR jujutsu.K68.com.` |
| Resolusi domain internet | `forwarders` | `192.168.122.1` |

Reverse zone adalah zona terpisah bernama `1.245.192.in-addr.arpa`, yaitu tiga oktet pertama alamat yang dibalik urutannya. Zona itu memetakan alamat kembali ke nama, berlawanan arah dengan zona forward.

Record PTR untuk `.1.4` diarahkan ke `jujutsu.K68.com.`, bukan ke `gojo.jujutsu.K68.com.`, karena soal meminta IP gojo dilacak kembali ke **domain resminya**, dan domain yang memetakan ke alamat itu adalah `jujutsu.K68.com`.

Seluruh penambahan dikerjakan dengan menyunting `setup-dns.sh` lalu menjalankannya ulang, dan serial dinaikkan menjadi `2026101503` supaya shoko ikut memperbarui salinannya.

### Langkah Pengerjaan

**Langkah 1.** Tambahkan deklarasi zona reverse pada `named.conf.local` di `utahime`, dengan direktif transfer yang sama seperti zona forward.

**Langkah 2.** Tambahkan blok `forwarders` pada `named.conf.options` di kedua node.

**Langkah 3.** Tambahkan A record apex, A record gojo, dan CNAME www pada zona forward, lalu naikkan serial.

**Langkah 4.** Buat berkas zona reverse berisi tiga record PTR.

**Langkah 5.** Tambahkan deklarasi zona reverse bertipe slave pada `shoko`.

**Langkah 6.** Jalankan ulang kedua script, lalu uji seluruhnya dari client.

### Konfigurasi

**utahime**, berkas `/root/setup-dns.sh` versi final

```bash
cat > /root/setup-dns.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 dnsutils
ln -sf /etc/init.d/named /etc/init.d/bind9
mkdir -p /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K68.com" {
    type master;
    notify yes;
    also-notify { 192.245.1.3; };
    allow-transfer { 192.245.1.3; };
    file "/etc/bind/jarkom/jujutsu.K68.com";
};

zone "1.245.192.in-addr.arpa" {
    type master;
    notify yes;
    also-notify { 192.245.1.3; };
    allow-transfer { 192.245.1.3; };
    file "/etc/bind/jarkom/1.245.192.in-addr.arpa";
};
EOF

cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    forwarders {
        192.168.122.1;
    };
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

cat > /etc/bind/jarkom/jujutsu.K68.com <<'EOF'
$TTL    604800
@       IN      SOA     utahime.jujutsu.K68.com. root.jujutsu.K68.com. (
                        2026101503 ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.K68.com.
@       IN      NS      shoko.jujutsu.K68.com.

@       IN      A       192.245.1.4

utahime IN      A       192.245.1.2
shoko   IN      A       192.245.1.3
gojo    IN      A       192.245.1.4

www     IN      CNAME   jujutsu.K68.com.
EOF

cat > /etc/bind/jarkom/1.245.192.in-addr.arpa <<'EOF'
$TTL    604800
@       IN      SOA     utahime.jujutsu.K68.com. root.jujutsu.K68.com. (
                        2026101503 ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.K68.com.
@       IN      NS      shoko.jujutsu.K68.com.

2       IN      PTR     utahime.jujutsu.K68.com.
3       IN      PTR     shoko.jujutsu.K68.com.
4       IN      PTR     jujutsu.K68.com.
EOF

service bind9 restart
SCRIPT
chmod +x /root/setup-dns.sh
bash /root/setup-dns.sh
```

**shoko**, berkas `/root/setup-dns.sh` versi final

```bash
cat > /root/setup-dns.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y bind9 dnsutils
ln -sf /etc/init.d/named /etc/init.d/bind9
mkdir -p /etc/bind/jarkom
chown -R bind:bind /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K68.com" {
    type slave;
    masters { 192.245.1.2; };
    file "/etc/bind/jarkom/jujutsu.K68.com";
};

zone "1.245.192.in-addr.arpa" {
    type slave;
    masters { 192.245.1.2; };
    file "/etc/bind/jarkom/1.245.192.in-addr.arpa";
};
EOF

cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    forwarders {
        192.168.122.1;
    };
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

service bind9 restart
SCRIPT
chmod +x /root/setup-dns.sh
bash /root/setup-dns.sh
```

Titik di akhir `jujutsu.K68.com.` pada record CNAME bersifat wajib. Tanpa titik, BIND menganggap nama itu relatif terhadap zona dan menambahkan nama zona di belakangnya, sehingga hasilnya menjadi `jujutsu.K68.com.jujutsu.K68.com` yang tidak pernah bisa diresolusi.

Untuk menampilkan isi konfigurasi, gunakan jalur lengkapnya:

```bash
cat /etc/bind/named.conf.local
cat /etc/bind/named.conf.options
cat /etc/bind/jarkom/jujutsu.K68.com
cat /etc/bind/jarkom/1.245.192.in-addr.arpa
```

### Pengujian

**Zona forward dengan A record apex dan CNAME www**

![Soal 12 zona forward](screenshot/soal12-zona-forward.png)

**Zona reverse berisi record PTR**

![Soal 12 zona reverse](screenshot/soal12-zona-reverse.png)

**Blok forwarders pada named.conf.options**

![Soal 12 forwarder](screenshot/soal12-forwarder.png)

**Pengujian dari client ino**

```bash
dig jujutsu.K68.com +short
dig www.jujutsu.K68.com
dig -x 192.245.1.4 +short
ping -c 3 google.com
```

![Soal 12 dig dan ping](screenshot/soal12-dig-ping.png)

| Uji | Hasil | Membuktikan |
|---|---|---|
| `dig jujutsu.K68.com +short` | 192.245.1.4 | A record apex mengarah ke gojo |
| `dig www.jujutsu.K68.com` | CNAME ke `jujutsu.K68.com.` lalu A 192.245.1.4, flag `aa` | alias www bekerja |
| `dig -x 192.245.1.4 +short` | `jujutsu.K68.com.` | reverse zone bekerja |
| `ping -c 3 google.com` | 3 received, 0% packet loss | forwarder bekerja |

Pengujian dilakukan dari client, bukan dari server DNS, karena dengan demikian sekalian terbukti bahwa resolver yang dibagikan DHCP pada soal 2 memang mengarah ke kedua server tersebut.

### Catatan

Perintah `ping` pada node alpinet berasal dari BusyBox, dan BusyBox mengharuskan opsi ditulis **sebelum** target.

```bash
ping google.com -c 3    # salah, menghasilkan "ping: -c: Name does not resolve"
ping -c 3 google.com    # benar
```

Pada node debinet urutannya bebas, pada alpinet tidak. Galat `Name does not resolve` pada kasus itu bukan tanda DNS bermasalah, melainkan karena BusyBox membaca `-c` sebagai nama host yang hendak diping.

---

## Soal 13: Replikasi Database MariaDB

### Soal

> Siapkan layanan database untuk mencatat aktivitas sistem. yaga berperan sebagai database master dan inumaki sebagai database slave. Buat database db_shibuya_K68 beserta tabel request_logs, aktifkan replikasi dari master ke slave, dan pastikan database dapat diakses dari node lain dalam Network Data Center.

### Inti Soal

Empat hal yang harus terpenuhi:

1. Replikasi master ke slave aktif, yaitu `yaga` menuju `inumaki`.
2. Database `db_shibuya_K68` beserta tabel `request_logs` tersedia.
3. Database dapat diakses dari node lain di Network 4, bukan hanya dari localhost.
4. Data yang ditulis di master terbawa ke slave.

Urutan pengerjaan menentukan keberhasilan. Replikasi dinyalakan **terlebih dahulu**, baru kemudian database dan tabel dibuat di master. Dengan urutan itu perintah DDL `CREATE DATABASE` dan `CREATE TABLE` ikut tereplikasi, sehingga struktur tabel muncul sendiri di slave. Apabila database dibuat sebelum `START SLAVE`, slave mulai membaca dari posisi binlog setelahnya dan tabel tidak akan pernah ada di sana.

### Langkah Pengerjaan

**Langkah 1.** Install MariaDB dan tulis konfigurasi master pada `yaga`, termasuk pembuatan user remote.

**Langkah 2.** Install MariaDB dan tulis konfigurasi slave pada `inumaki`.

**Langkah 3.** Baca posisi binlog master dengan `SHOW MASTER STATUS` di `yaga`.

**Langkah 4.** Sambungkan slave dengan `CHANGE MASTER TO` memakai posisi tersebut, lalu `START SLAVE`.

**Langkah 5.** Buat database dan tabel di master, lalu buktikan keduanya muncul di slave tanpa dibuat manual.

**Langkah 6.** Masukkan satu baris data di master, lalu buktikan baris itu muncul di slave.

### Konfigurasi

**yaga**, berkas `/root/setup-db.sh`

```bash
cat > /root/setup-db.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server

cat > /etc/mysql/mariadb.conf.d/99-master.cnf <<'EOF'
[mysqld]
server-id        = 1
log-bin          = mysql-bin
binlog_format    = ROW
bind-address     = 0.0.0.0
EOF

service mariadb restart
sleep 8

mysql <<'EOF'
CREATE USER IF NOT EXISTS 'replica'@'192.245.4.%' IDENTIFIED BY 'replicapass';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replica'@'192.245.4.%';

CREATE USER IF NOT EXISTS 'shibuya'@'192.245.4.%' IDENTIFIED BY 'shibuyapass';
GRANT ALL PRIVILEGES ON db_shibuya_K68.* TO 'shibuya'@'192.245.4.%';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS db_shibuya_K68;
USE db_shibuya_K68;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    endpoint VARCHAR(255),
    client_ip VARCHAR(45),
    worker VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
SCRIPT
chmod +x /root/setup-db.sh
bash /root/setup-db.sh
```

Nama berkas diberi awalan `99-` dengan sengaja. Debian membaca berkas di `/etc/mysql/mariadb.conf.d/` secara berurutan menurut nama, dan berkas bawaan bernama `50-server.cnf` memuat `bind-address = 127.0.0.1`. Dengan awalan `99-`, konfigurasi ini dibaca paling akhir sehingga nilainya menimpa yang bawaan menjadi `0.0.0.0`. Tanpa itu MariaDB hanya mendengarkan localhost dan slave tidak dapat menyambung.

Arti tiga direktif pada blok master:

| Direktif | Fungsi |
|---|---|
| `server-id = 1` | identitas unik, wajib berbeda antara master dan slave |
| `log-bin = mysql-bin` | mengaktifkan binary log, yaitu catatan perubahan yang dibaca slave |
| `binlog_format = ROW` | mencatat perubahan per baris data, lebih aman dibandingkan mencatat teks perintah |

Dua user remote dibuat dengan host `192.245.4.%` supaya database dapat diakses dari seluruh Network Data Center sebagaimana diminta soal:

| User | Hak | Kegunaan |
|---|---|---|
| `replica` | `REPLICATION SLAVE, REPLICATION CLIENT` | dipakai inumaki untuk menarik binlog |
| `shibuya` | `ALL PRIVILEGES` pada `db_shibuya_K68` | dipakai aplikasi worker pada soal lanjutan |

**inumaki**, berkas `/root/setup-db.sh`

```bash
cat > /root/setup-db.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server

cat > /etc/mysql/mariadb.conf.d/99-slave.cnf <<'EOF'
[mysqld]
server-id        = 2
bind-address     = 0.0.0.0
EOF

service mariadb restart
sleep 8

# Skema dibuat lokal juga, supaya tetap ada walau DDL dari master terlewat
mysql <<'EOF'
CREATE DATABASE IF NOT EXISTS db_shibuya_K68;
USE db_shibuya_K68;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    endpoint VARCHAR(255),
    client_ip VARCHAR(45),
    worker VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# Tunggu master siap menerima koneksi, maksimal 60 detik
for i in $(seq 1 30); do
    mysql -h 192.245.4.8 -u replica -preplicapass -e "SELECT 1;" >/dev/null 2>&1 && break
    sleep 2
done

# Baca posisi binlog master saat ini
STATUS=$(mysql -h 192.245.4.8 -u replica -preplicapass -N -e "SHOW MASTER STATUS;")
MFILE=$(echo "$STATUS" | awk '{print $1}')
MPOS=$(echo "$STATUS" | awk '{print $2}')

if [ -n "$MFILE" ] && [ -n "$MPOS" ]; then
    mysql <<EOF
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='192.245.4.8',
  MASTER_PORT=3306,
  MASTER_USER='replica',
  MASTER_PASSWORD='replicapass',
  MASTER_LOG_FILE='$MFILE',
  MASTER_LOG_POS=$MPOS;
START SLAVE;
EOF
fi
SCRIPT
chmod +x /root/setup-db.sh
bash /root/setup-db.sh
```

Script slave membaca posisi binlog master secara otomatis, bukan dengan angka yang diketik manual. Hal itu diperlukan karena direktori `/var/lib/mysql` ikut terhapus saat node direstart, sehingga posisi lama tidak lagi berlaku. Dengan cara ini slave dapat menyambung ulang sendiri setelah setiap restart.

**Autostart kedua node**

```
# yaga, /etc/network/interfaces
auto eth0
iface eth0 inet static
	address 192.245.4.8
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-db.sh

# inumaki, /etc/network/interfaces
auto eth0
iface eth0 inet static
	address 192.245.4.9
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-db.sh
```

### Cara Penyambungan Manual

Apabila penyambungan dilakukan dengan tangan, bukan oleh script, urutannya seperti berikut.

**Di yaga**

```sql
SHOW MASTER STATUS;
```

Keluarannya pada pengerjaan ini adalah berkas `mysql-bin.000001` dengan posisi `1179`.

**Di inumaki**

```sql
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='192.245.4.8',
  MASTER_PORT=3306,
  MASTER_USER='replica',
  MASTER_PASSWORD='replicapass',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=1179;
START SLAVE;
SHOW SLAVE STATUS\G
```

Dua nilai pada `CHANGE MASTER TO` harus diisi dengan angka hasil `SHOW MASTER STATUS`, bukan dengan tulisan penanda apa pun. Menyisakan penanda di sana menghasilkan galat sintaks `ERROR 1064`.

### Pengujian

**Konfigurasi master dan posisi binlog**

![Soal 13 config master](screenshot/soal13-master-config.png)

**Status slave**

![Soal 13 status slave](screenshot/soal13-slave-status.png)

| Field | Nilai |
|---|---|
| `Slave_IO_Running` | Yes |
| `Slave_SQL_Running` | Yes |
| `Master_Host` | 192.245.4.8 |

**Tabel muncul sendiri di slave**

![Soal 13 tabel](screenshot/soal13-tabel.png)

**Insert di master**

```sql
USE db_shibuya_K68;
INSERT INTO request_logs (endpoint, client_ip, worker)
VALUES ('/api/test', '192.245.3.13', 'yaga-manual');
SELECT * FROM request_logs;
```

![Soal 13 insert di master](screenshot/soal13-insert-master.png)

**Baris terbawa ke slave**

```sql
USE db_shibuya_K68;
SELECT * FROM request_logs;
```

![Soal 13 replikasi di slave](screenshot/soal13-replikasi-slave.png)

Database, tabel, dan baris data ketiganya muncul di `inumaki` tanpa satu pun dibuat secara manual di sana. Itu membuktikan replikasi berjalan untuk DDL sekaligus DML.

### Catatan

Tabel `request_logs` sengaja dibuat lengkap sejak awal dengan kolom `client_ip` dan `worker`, meskipun soal 13 tidak memintanya. Kedua kolom itu dibutuhkan pada soal lanjutan, yaitu `client_ip` untuk pencatatan IP asli client dan `worker` sebagai bukti pembagian beban. Dengan demikian tidak perlu `ALTER TABLE` di kemudian hari, yang akan merepotkan karena perubahan skema juga harus menunggu replikasi.

Nilai `Slave_IO_Running: Connecting` yang muncul sesaat setelah `START SLAVE` adalah keadaan normal, sebab koneksi ke master masih dibangun. Tunggu beberapa detik lalu periksa kembali, jangan langsung dianggap gangguan.

---

## Soal 14: Worker Backend (Frontend dan API)

### Soal

> Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada maki dan panda untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada nanami, todo, dan kirara, siapkan layanan API yang mencatat log request ke database yaga. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui geto. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.

### Inti Soal

Lima pekerjaan sekaligus:

1. Memasang Nginx dan PHP-FPM pada `maki` dan `panda`, dengan halaman yang menampilkan hostname.
2. Memasang Nginx, PHP-FPM, dan ekstensi MySQL pada `nanami`, `todo`, dan `kirara`, dengan endpoint `/api/` yang menulis satu baris ke tabel `request_logs` di `yaga` setiap kali diakses.
3. Membuat virtual host yang merespons `jujutsu.K68.com` dan `www.jujutsu.K68.com`.
4. Membatasi akses. Worker frontend hanya menerima trafik dari `gojo` (`192.245.1.4`), worker API hanya dari `geto` (`192.245.4.2`).
5. Membuktikan bahwa akses langsung dari client ditolak, sedangkan akses dari gojo dan geto berhasil.

Di soal ini `gojo` dan `geto` belum dikonfigurasi sebagai proxy, karena itu baru dikerjakan pada soal 15 dan 16. Pengujian "lewat proxy" cukup dilakukan dengan `curl` langsung dari gojo (ke frontend) dan dari geto (ke API), sebab hanya kedua IP itulah yang diizinkan oleh worker.

### Pembagian Peran

| Node | IP | Script | Hanya menerima trafik dari |
|---|---|---|---|
| maki | 192.245.4.3 | `setup-web.sh` | gojo `192.245.1.4` |
| panda | 192.245.4.4 | `setup-web.sh` | gojo `192.245.1.4` |
| nanami | 192.245.4.5 | `setup-api.sh` | geto `192.245.4.2` |
| todo | 192.245.4.6 | `setup-api.sh` | geto `192.245.4.2` |
| kirara | 192.245.4.7 | `setup-api.sh` | geto `192.245.4.2` |

Isi script sama persis untuk semua node dalam satu jenis. Hostname yang tampil di respons diambil dari `gethostname()`, jadi tidak perlu diubah per node.

### Langkah Pengerjaan

**Langkah 1.** Pastikan resolver terpasang pada node yang baru dinyalakan, supaya `apt-get` dapat menjangkau repositori.

```bash
bash /root/dns.sh
```

**Langkah 2.** Pada `maki` dan `panda`, tulis `/root/setup-web.sh` lalu jalankan.

**Langkah 3.** Pada `nanami`, `todo`, dan `kirara`, tulis `/root/setup-api.sh` lalu jalankan.

**Langkah 4.** Periksa `nginx -t` dan status layanan pada setiap node.

**Langkah 5.** Uji dari tiga titik: client (harus ditolak), gojo ke frontend (harus berhasil), dan geto ke API (harus berhasil).

**Langkah 6.** Periksa tabel `request_logs` di `yaga` untuk memastikan log dari API tercatat.

**Langkah 7.** Pasang autostart pada `interfaces` kelima node.

### Konfigurasi

**maki dan panda**, berkas `/root/setup-web.sh`

```bash
cat > /root/setup-web.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm

PHPV=$(ls /etc/php | head -1)
service php$PHPV-fpm start

cat > /var/www/html/index.php <<'EOF'
<?php echo "Frontend: " . gethostname() . "\n"; ?>
EOF

cat > /etc/nginx/sites-available/jujutsu <<'EOF'
server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;
    root /var/www/html;
    index index.php;

    allow 192.245.1.4;
    deny all;

    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/phpPHPVER-fpm.sock;
    }
}
EOF
sed -i "s/PHPVER/$PHPV/" /etc/nginx/sites-available/jujutsu

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/jujutsu /etc/nginx/sites-enabled/jujutsu
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-web.sh
bash /root/setup-web.sh
```

**nanami, todo, dan kirara**, berkas `/root/setup-api.sh`

```bash
cat > /root/setup-api.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx php-fpm php-mysql

PHPV=$(ls /etc/php | head -1)
service php$PHPV-fpm start

mkdir -p /var/www/html/api
cat > /var/www/html/api/index.php <<'EOF'
<?php
header('Content-Type: application/json');
$remote = $_SERVER['REMOTE_ADDR'];
$client = $remote;
// hanya percaya X-Real-IP kalau request datang dari geto
if ($remote === '192.245.4.2' && !empty($_SERVER['HTTP_X_REAL_IP'])) {
    $client = $_SERVER['HTTP_X_REAL_IP'];
}
try {
    $pdo = new PDO('mysql:host=192.245.4.8;dbname=db_shibuya_K68', 'shibuya', 'shibuyapass');
    $st = $pdo->prepare('INSERT INTO request_logs (endpoint, client_ip, worker) VALUES (?,?,?)');
    $st->execute([$_SERVER['REQUEST_URI'], $client, gethostname()]);
    echo json_encode(['status'=>'ok','server'=>gethostname(),'client_ip'=>$client]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status'=>'error','server'=>gethostname(),'msg'=>$e->getMessage()]);
}
EOF

cat > /etc/nginx/sites-available/jujutsu <<'EOF'
server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;
    root /var/www/html;
    index index.php;

    allow 192.245.4.2;
    deny all;

    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/phpPHPVER-fpm.sock;
    }
}
EOF
sed -i "s/PHPVER/$PHPV/" /etc/nginx/sites-available/jujutsu

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/jujutsu /etc/nginx/sites-enabled/jujutsu
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-api.sh
bash /root/setup-api.sh
```

#### Penjelasan bagian penting

| Bagian | Fungsi |
|---|---|
| `PHPV=$(ls /etc/php \| head -1)` | Mendeteksi versi PHP yang terpasang (pada pengerjaan ini `8.4`), sehingga nama socket tidak perlu diketik manual |
| `phpPHPVER-fpm.sock` lalu `sed` | Heredoc bertanda kutip tidak memperluas variabel, jadi socket ditulis sebagai penanda `PHPVER` dan baru diganti oleh `sed` setelah versi diketahui |
| `allow ...; deny all;` | Pembatasan akses. Selain IP yang disebut, nginx membalas `403 Forbidden` |
| `php-mysql` | Ekstensi yang membuat PHP dapat memakai `PDO('mysql:...')`. Tanpa ini API membalas galat `could not find driver` |
| `REMOTE_ADDR === '192.245.4.2'` | Header `X-Real-IP` hanya dipercaya bila request benar-benar datang dari geto. Bagian ini dipakai penuh pada soal 17 |
| `INSERT ... (endpoint, client_ip, worker)` | Kolom disesuaikan dengan tabel `request_logs` yang sudah dibuat pada soal 13, jadi tidak perlu `ALTER TABLE` |

#### Pembatasan akses

Pembatasan bekerja karena client Network 2 dan Network 3 tidak melalui NAT di dalam jaringan internal. NAT hanya terpasang di `eth0` jichi menuju internet. Akibatnya worker melihat IP asli client sebagai sumber, bukan IP gojo atau geto, sehingga aturan `deny all` menolak request tersebut.

### Autostart

Karena paket dan isi `/etc` hilang saat node direstart (lihat Catatan Teknis Penting nomor 1), script dipanggil dari `/etc/network/interfaces`. Satu baris `up` ditambahkan di bawah `up bash /root/dns.sh`. Urutan kedua baris itu penting, sebab `dns.sh` harus memasang resolver lebih dulu sebelum `apt-get` di dalam script berjalan.

**maki**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.4.3
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-web.sh
```

**panda**

```
auto eth0
iface eth0 inet static
	address 192.245.4.4
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-web.sh
```

**nanami**

```
auto eth0
iface eth0 inet static
	address 192.245.4.5
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-api.sh
```

**todo**

```
auto eth0
iface eth0 inet static
	address 192.245.4.6
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-api.sh
```

**kirara**

```
auto eth0
iface eth0 inet static
	address 192.245.4.7
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-api.sh
```

Pengeditan dilakukan lewat GNS3 saat node mati: klik kanan node, pilih Edit network configuration, tambahkan baris `up`, simpan, lalu nyalakan kembali. Baris yang dipakai tidak mengandung karakter `>`, sehingga tidak dibuang oleh editor.

### Pengujian

**Konfigurasi dan status nginx pada maki**

![Soal 14 nginx maki](screenshot/soal14-maki-nginx.png)

Keluaran `nginx -t` menyatakan `syntax is ok` dan `test is successful`. Vhost memuat `server_name jujutsu.K68.com www.jujutsu.K68.com`, `allow 192.245.1.4`, `deny all`, dan `fastcgi_pass` menuju `php8.4-fpm.sock`.

**Akses dari gojo ke frontend berhasil**

Dari gojo, `curl -i http://192.245.4.3/` dan `curl -i http://192.245.4.4/`.

![Soal 14 gojo ke maki](screenshot/soal14-gojo-maki.png)

![Soal 14 gojo ke panda](screenshot/soal14-gojo-panda.png)

Kedua worker membalas `200 OK` dan menampilkan `Frontend: Maki` serta `Frontend: Panda`. Ini menunjukkan Nginx dan PHP-FPM berjalan, dan `allow 192.245.1.4` mengizinkan gojo.

**Akses langsung dari client ditolak**

Dari itadori (client Divisi A), `curl -i http://192.245.4.4/`.

![Soal 14 itadori ke panda ditolak](screenshot/soal14-itadori-panda-403.png)

Respons `403 Forbidden` membuktikan akses langsung dari client tidak diizinkan.

**Akses dari geto ke API berhasil**

Dari geto, memakai `lynx -dump` dan `curl` ke tiga worker API.

```bash
lynx -dump http://192.245.4.5/api/
lynx -dump http://192.245.4.6/api/
lynx -dump http://192.245.4.7/api/
```

![Soal 14 geto lynx](screenshot/soal14-geto-lynx.png)

```bash
curl -i http://192.245.4.5/api/
curl -i http://192.245.4.6/api/
curl -i http://192.245.4.7/api/
```

![Soal 14 geto curl](screenshot/soal14-geto-curl.png)

Ketiganya membalas JSON `{"status":"ok","server":"...","client_ip":"192.245.4.2"}`. Nilai `"status":"ok"` berarti insert ke yaga berhasil.

**Log tercatat di database yaga**

```bash
mysql -e "SELECT * FROM db_shibuya_K68.request_logs ORDER BY id DESC LIMIT 5;"
```

![Soal 14 tabel yaga](screenshot/soal14-yaga-tabel.png)

| Kolom | Nilai yang muncul |
|---|---|
| `endpoint` | `/api/` |
| `client_ip` | `192.245.4.2` (IP geto) |
| `worker` | Nanami, Todo, Kirara |

Ketiga worker API tercatat. Maki dan panda tidak muncul di tabel karena keduanya hanya frontend dan tidak terhubung ke database.

**Autostart**

Konfigurasi `interfaces` pada maki dan todo melalui editor GNS3.

![Soal 14 interfaces maki](screenshot/soal14-maki-interfaces.png)

![Soal 14 interfaces todo](screenshot/soal14-todo-interfaces.png)

Kedua node memuat dua baris `up`, yaitu `dns.sh` lebih dulu lalu `setup-web.sh` (maki) atau `setup-api.sh` (todo).

### Catatan

Nilai `client_ip` yang tercatat saat ini adalah `192.245.4.2`, yaitu IP geto, karena request masih dikirim langsung dari geto ke worker dan belum melewati gojo. Nilainya baru berubah menjadi IP client asli setelah gojo dan geto meneruskan header `X-Real-IP` pada soal 17.

Tabel `request_logs` tidak diubah pada soal ini. Kolom `endpoint`, `client_ip`, dan `worker` sudah dibuat lengkap sejak soal 13, sehingga script API langsung menulis ke kolom yang tepat tanpa `ALTER TABLE`.

Pengujian dari geto memakai `lynx -dump` dan `curl`. Opsi `-dump` wajib dipakai pada lynx, sebab tanpa itu lynx membuka mode interaktif yang tidak dapat di-screenshot dengan rapi.

Bila yaga baru direstart dan data tidak muncul, jalankan `bash /root/setup-db.sh` pada yaga terlebih dahulu, lalu pada inumaki, sebelum memicu API dari geto.

---

## Soal 15: Load Balancer Internal (geto)

### Soal

> Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada geto sebagai Load Balancer internal dengan upstream api_cluster yang mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responnya.

### Inti Soal

1. Memasang Nginx pada `geto` sebagai load balancer internal.
2. Membuat upstream bernama `api_cluster` yang berisi `nanami` dan `todo`.
3. Menerapkan Weighted Round Robin dengan bobot 3 untuk nanami dan 1 untuk todo.
4. Membuktikan rasio dengan loop request ke geto dari node di jaringan Data Center (Network 4).

Alur request pada soal ini:

```
node Network 4 --> geto (192.245.4.2) --> nanami 192.245.4.5 (bobot 3)
                                     └--> todo   192.245.4.6 (bobot 1)
```

`kirara` belum dimasukkan ke upstream karena baru dipakai sebagai server cadangan pada soal 18. Worker API sudah mengizinkan geto (`allow 192.245.4.2`) sejak soal 14, sehingga geto dapat meneruskan request tanpa perubahan di sisi worker.

### Langkah Pengerjaan

**Langkah 1.** Pastikan resolver terpasang pada geto.

```bash
bash /root/dns.sh
```

**Langkah 2.** Tulis `/root/setup-geto.sh` lalu jalankan. Script memasang Nginx, membuat upstream `api_cluster`, dan mengaktifkan virtual host.

**Langkah 3.** Periksa `nginx -t` dan status layanan.

**Langkah 4.** Dari node Network 4 (maki), kirim 40 request ke geto lalu hitung respons per worker dengan `uniq -c`.

**Langkah 5.** Periksa urutan respons dan jumlah baris per worker di database yaga.

**Langkah 6.** Pasang autostart pada `interfaces` geto.

### Konfigurasi

**geto**, berkas `/root/setup-geto.sh`

```bash
cat > /root/setup-geto.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/geto <<'EOF'
upstream api_cluster {
    server 192.245.4.5 weight=3;
    server 192.245.4.6 weight=1;
}

server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/geto /etc/nginx/sites-enabled/geto
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-geto.sh
bash /root/setup-geto.sh
```

#### Penjelasan bagian penting

| Bagian | Fungsi |
|---|---|
| `upstream api_cluster` | Nama kelompok server tujuan, sesuai permintaan soal |
| `weight=3` pada nanami, `weight=1` pada todo | Dari setiap 4 request, 3 diteruskan ke nanami dan 1 ke todo (Weighted Round Robin) |
| `proxy_pass http://api_cluster` | Meneruskan request ke kelompok upstream |
| `proxy_set_header Host $host` | Meneruskan nama domain asli ke worker agar cocok dengan `server_name` di vhost worker |

### Autostart

Karena paket dan isi `/etc` hilang saat node direstart, script dipanggil dari `/etc/network/interfaces` dengan satu baris `up` di bawah `up bash /root/dns.sh`.

**geto**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.4.2
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-geto.sh
```

### Pengujian

**Konfigurasi geto**

![Soal 15 konfigurasi geto](screenshot/soal15-geto-config.png)

Keluaran `nginx -t` menyatakan `syntax is ok` dan `test is successful`, Nginx berstatus running, dan upstream `api_cluster` memuat nanami dengan `weight=3` serta todo dengan `weight=1`.

**Rasio distribusi dari maki (jaringan Data Center)**

Pengujian dilakukan dari `maki` karena berada di Network 4, sesuai permintaan soal untuk menguji dari jaringan lokal Data Center. Maki mengirim 40 request ke geto, lalu respons dihitung per worker.

```bash
for i in $(seq 1 40); do curl -s http://192.245.4.2/api/; echo; done | grep -o '"server":"[^"]*"' | sort | uniq -c
```

![Soal 15 rasio dari maki](screenshot/soal15-maki-rasio.png)

Hasilnya 31 respons dari Nanami dan 9 dari Todo, atau sekitar 77,5% banding 22,5%. Angka ini mendekati rasio 3:1 (75% banding 25%).

**Urutan respons dari maki**

```bash
for i in $(seq 1 8); do curl -s http://192.245.4.2/api/; echo; done
```

![Soal 15 urutan request dari maki](screenshot/soal15-maki-urutan.png)

Respons dari Nanami muncul lebih sering dan berulang, sedangkan Todo muncul sesekali di sela-selanya. Polanya sesuai dengan bobot 3:1.

**Rasio dari sisi database yaga**

Setiap request API ditulis worker ke tabel `request_logs`, sehingga rasio juga dapat dilihat dari sisi database.

```bash
mysql -e "SELECT worker, COUNT(*) AS jumlah FROM db_shibuya_K68.request_logs WHERE created_at > NOW() - INTERVAL 10 MINUTE GROUP BY worker;"
```

![Soal 15 rasio di yaga](screenshot/soal15-yaga-rasio.png)

Jumlah baris untuk Nanami sekitar tiga kali lipat jumlah baris Todo. Ini membuktikan pembagian beban dari sisi worker, selaras dengan hasil `uniq -c` di maki.

**Autostart**

![Soal 15 interfaces geto](screenshot/soal15-geto-interfaces.png)

Konfigurasi `interfaces` geto memuat dua baris `up`: `dns.sh` lebih dulu, lalu `setup-geto.sh`.

### Catatan

Hasil 31 dan 9 dari 40 request, bukan persis 30 dan 10, terjadi karena Nginx menjalankan beberapa proses worker dan tiap proses menyimpan hitungan giliran Weighted Round Robin sendiri. Selisih satu atau dua request pada jumlah request yang kecil adalah hal yang wajar. Semakin banyak request yang dikirim, perbandingannya semakin mendekati 3:1. Menambahkan `zone` pada upstream akan membuat semua proses berbagi satu hitungan, tetapi itu tidak diperlukan karena soal hanya meminta pemeriksaan rasio.

Pengujian dilakukan dari `maki`, bukan dari client Divisi A atau B. Client Divisi A dan B berada di Network 2 dan 3, sedangkan soal meminta pengujian dari jaringan lokal Data Center (Network 4).

Pada soal ini `client_ip` di tabel `request_logs` masih berisi IP pengirim langsung. Untuk request dari maki nilainya `192.245.4.3`, bukan IP geto, karena geto belum meneruskan header IP klien. Penerusan header itu baru dikerjakan pada soal 17.

Script `setup-geto.sh` akan diperbarui pada soal 17 (header `X-Real-IP` dan `set_real_ip_from`) dan soal 18 (server `backup` serta passive health check), jadi file ini tetap disimpan di `/root`.

---

## Soal 16: Path-Based Routing (gojo)

### Soal

> Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo untuk melayani domain `jujutsu.K68.com` dan `www.jujutsu.K68.com` menggunakan metode Path-Based Routing. Atur agar request root (`/`) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path `/api` diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke `/api` diteruskan dan dijawab oleh Nanami/Todo.

### Inti Soal

1. Memasang Nginx pada `gojo` sebagai public reverse proxy.
2. Membuat dua upstream: `web_frontend` berisi maki dan panda, serta `geto_api` berisi geto.
3. Menerapkan Path-Based Routing: `/` ke `web_frontend`, `/api` ke `geto_api`.
4. Membuktikan dari client Divisi A dan Divisi B bahwa kedua path dijawab oleh worker yang benar.

Alur request pada soal ini:

```
client Divisi A/B --> gojo (192.245.1.4) --+--> /     --> maki 192.245.4.3
                                           |             panda 192.245.4.4
                                           |
                                           +--> /api  --> geto 192.245.4.2
                                                          |
                                                          +--> nanami 192.245.4.5
                                                          +--> todo   192.245.4.6
```

`web_frontend` memakai Round Robin tanpa bobot karena soal hanya meminta Round Robin biasa. `geto_api` berisi satu server saja, sehingga request `/api` seluruhnya melewati geto, lalu geto membaginya ke nanami dan todo memakai Weighted Round Robin 3:1 dari soal 15.

### Langkah Pengerjaan

**Langkah 1.** Pastikan resolver terpasang pada gojo.

```bash
bash /root/dns.sh
```

**Langkah 2.** Tulis `/root/setup-gojo.sh` lalu jalankan. Script memasang Nginx, membuat dua upstream, dan mengaktifkan virtual host.

**Langkah 3.** Periksa `nginx -t` dan status layanan.

**Langkah 4.** Dari client Divisi A (itadori) dan Divisi B (ino), uji path `/` dengan `curl` berulang.

**Langkah 5.** Dari client yang sama, uji path `/api` dengan `curl` berulang dan hitung rasio per worker.

**Langkah 6.** Uji akses langsung dari client ke worker untuk memastikan pembatasan soal 14 masih berlaku.

**Langkah 7.** Pasang autostart pada `interfaces` gojo.

### Konfigurasi

**gojo**, berkas `/root/setup-gojo.sh`

```bash
cat > /root/setup-gojo.sh <<'SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/gojo <<'EOF'
upstream web_frontend {
    server 192.245.4.3;   # maki
    server 192.245.4.4;   # panda
}

upstream geto_api {
    server 192.245.4.2;   # geto
}

server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;

    location / {
        proxy_pass http://web_frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api {
        proxy_pass http://geto_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/gojo /etc/nginx/sites-enabled/gojo
nginx -t && service nginx restart
SCRIPT
chmod +x /root/setup-gojo.sh
bash /root/setup-gojo.sh
```

### Penjelasan bagian penting

| Bagian | Fungsi |
|---|---|
| `upstream web_frontend` | Kelompok worker frontend, berisi maki dan panda |
| `upstream geto_api` | Kelompok tujuan untuk path `/api`, berisi geto |
| `location /` | Meneruskan request root ke `web_frontend` dengan Round Robin |
| `location /api` | Meneruskan request ke `geto_api`, lalu diteruskan ke nanami/todo |
| `proxy_pass` tanpa trailing slash | Path asli dipertahankan utuh, sehingga `/api` tidak terpotong menjadi `/` |
| `proxy_set_header Host $host` | Nama domain asli diteruskan ke worker agar cocok dengan `server_name` di vhost worker |
| `X-Real-IP` dan `X-Forwarded-For` | Persiapan untuk soal 17, tidak mengganggu routing |

`location /api` lebih spesifik dibandingkan `location /`, sehingga Nginx memilih blok `/api` untuk request ke endpoint API dan tidak meneruskannya ke web frontend.

### Autostart

Karena paket dan isi `/etc` hilang saat node direstart, script dipanggil dari `/etc/network/interfaces` dengan urutan `dns.sh` lebih dulu, baru `setup-gojo.sh`.

**gojo**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.1.4
	netmask 255.255.255.0
	gateway 192.245.1.1
	up bash /root/dns.sh
	up bash /root/setup-gojo.sh
```

### Pengujian

**Konfigurasi gojo**

![Soal 16 konfigurasi gojo](screenshot/soal16-gojo-config.png)

Keluaran `nginx -t` menyatakan `syntax is ok` dan `test is successful`. Upstream `web_frontend` memuat maki dan panda, upstream `geto_api` memuat geto, dan kedua `location` mengarah ke upstream yang sesuai.

**DNS resolve dari client**

Uji dilakukan dari dua client, yaitu itadori dari Divisi A dan ino dari Divisi B. Keduanya memakai resolver DNS dari utahime.

```bash
dig jujutsu.K68.com +short
```

![Soal 16 dig itadori](screenshot/soal16-dig-itadori.png)

![Soal 16 dig ino](screenshot/soal16-dig-ino.png)

Keduanya menjawab `192.245.1.4`, yaitu alamat gojo. Artinya record A yang dibuat pada soal 12 bekerja dan dibaca dari kedua divisi.

**Uji web utama dari itadori (Divisi A)**

```bash
for i in $(seq 1 10); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/
done
```

![Soal 16 web itadori](screenshot/soal16-web-itadori.png)

Respons bergantian antara `Frontend: maki` dan `Frontend: panda`, membuktikan upstream `web_frontend` memakai Round Robin.

**Uji web utama dari ino (Divisi B)**

```bash
for i in $(seq 1 10); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/
done
```

![Soal 16 web ino](screenshot/soal16-web-ino.png)

Hasil yang sama, bergantian maki dan panda, hanya berpindah titik pengujian.

**Uji path `/api` dari client**

```bash
for i in $(seq 1 40); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done | grep -o '"server":"[^"]*"' | sort | uniq -c
```

![Soal 16 api dari client](screenshot/soal16-api-client.png)

Request ke `/api` tidak dijawab oleh maki atau panda, melainkan melewati gojo → geto → nanami/todo. Karena geto memakai Weighted Round Robin 3:1 dari soal 15, rasio responsnya konsisten dengan hasil soal 15, yaitu sekitar **31 respons nanami berbanding 9 respons todo dari 40 request**, atau **sekitar 77,5% banding 22,5%**. Angka ini mendekati rasio 3:1 (75% banding 25%) sebagaimana dijelaskan pada catatan soal 15.

**Akses langsung dari client ditolak**

```bash
curl -I http://192.245.4.3/
curl -I http://192.245.4.4/
lynx -dump http://192.245.4.5/api/
lynx -dump http://192.245.4.6/api/
```

![Soal 16 forbidden ino](screenshot/soal16-forbidden-ino.png)

![Soal 16 forbidden ino api](screenshot/soal16-forbidden-ino-api.png)

Semua request ke worker langsung dari client dijawab `403 Forbidden`, sesuai pembatasan soal 14 yang hanya mengizinkan gojo (`192.245.1.4`) untuk web worker dan geto (`192.245.4.2`) untuk API worker.

**Autostart**

![Soal 16 interfaces gojo](screenshot/soal16-gojo-interfaces.png)

Konfigurasi `interfaces` gojo memuat dua baris `up`: `dns.sh` lebih dulu, lalu `setup-gojo.sh`, sehingga Nginx langsung aktif setelah node dinyalakan.

| Uji | Hasil |
|---|---|
| `dig jujutsu.K68.com` dari itadori | 192.245.1.4 |
| `dig jujutsu.K68.com` dari ino | 192.245.1.4 |
| Web utama dari itadori | maki dan panda bergantian |
| Web utama dari ino | maki dan panda bergantian |
| Path `/api` dari client | nanami dan todo, rasio mengikuti 31:9 dari soal 15 |
| Akses langsung ke maki/panda | 403 Forbidden |
| Akses langsung ke nanami/todo | 403 Forbidden |

### Catatan

`proxy_pass` sengaja ditulis tanpa trailing slash, yaitu `proxy_pass http://web_frontend;` dan `proxy_pass http://geto_api;`. Penambahan slash di akhir akan membuat Nginx memotong prefix path sebelum meneruskan, sehingga request ke `/api/` berubah menjadi `/` di sisi geto dan tidak lagi cocok dengan `location /api` pada worker API. Gejalanya adalah respons `404` yang mudah tertukar dengan worker yang mati.

Seluruh pengujian dari client memakai `--resolve` karena resolver di sisi client mengarah ke utahime, dan gojo bisa dijangkau baik lewat nama domain maupun langsung lewat `Host` header. Pada `curl -v`, yang menentukan server block mana yang dipilih Nginx adalah nilai `Host`, bukan alamat IP tujuan. Karena itu `--resolve` tetap mengirim `Host: jujutsu.K68.com` seperti request dari browser biasa.

`X-Real-IP` dan `X-Forwarded-For` sudah ditambahkan di konfigurasi gojo sejak soal ini, tetapi belum diuji fungsinya. Pengujiannya baru dilakukan pada soal 17, dan tidak memengaruhi hasil routing soal ini.

Pada soal ini gojo masih memakai resolver default ke `192.168.122.1` dari `dns.sh`. Pengujian dilakukan dengan `--resolve` agar hasilnya tidak bergantung pada kesiapan resolver gojo. Pada soal 20 nanti, kusakabe perlu memakai domain penuh untuk benchmark, dan pada saat itu resolver gojo atau entri `/etc/hosts` harus sudah mengarah ke utahime.

---

## Soal 17: X-Real-IP, X-Forwarded-For, dan Verifikasi client_ip

### Soal

> Komando pusat perlu mengetahui IP asli klien yang mengirimkan request tanpa tertukar dengan IP proxy perantara. Konfigurasikan gojo dan geto agar meneruskan informasi alamat klien melalui header `X-Real-IP` dan `X-Forwarded-For`. Pastikan geto hanya mempercayai informasi alamat klien yang diterima dari proxy terpercaya, dan skrip API menyimpan alamat klien yang telah diverifikasi ke kolom `client_ip` pada tabel `request_logs` di database yaga. Uji dengan mengirimkan request dari klien Network 2 dan Network 3 ke endpoint `/api`, kemudian periksa database untuk memastikan alamat yang tercatat sesuai dengan IP klien asal, bukan IP gojo atau geto.

### Inti Soal

Ada dua lapis kepercayaan yang harus dipasang:

1. **geto** hanya mempercayai gojo (`192.245.1.4`) sebagai sumber header IP klien.
2. **Skrip API** di nanami, todo, kirara hanya mempercayai geto (`192.245.4.2`) sebagai sumber header IP klien.

Klien tidak bisa memalsukan IP karena tidak ada satu pun lapisan yang mempercayainya.

Alur header:

```
Client (192.245.2.10)
   → gojo kirim X-Real-IP: 192.245.2.10
      → geto percayai gojo, ubah $remote_addr jadi 192.245.2.10
         → geto teruskan X-Real-IP: 192.245.2.10 ke Nanami
            → skrip API percayai geto, simpan client_ip = 192.245.2.10
```

### Konfigurasi

#### geto — bagian penting

Pada `/etc/nginx/sites-available/geto`, di dalam blok `server`, ditambahkan tiga direktif `real_ip`:

```nginx
set_real_ip_from 192.245.1.4;
real_ip_header X-Forwarded-For;
real_ip_recursive on;
```

Dan di dalam `location /`, ditambahkan dua baris `proxy_set_header` yang memakai `$remote_addr` hasil verifikasi:

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $remote_addr;
```

| Bagian | Fungsi |
|---|---|
| `set_real_ip_from 192.245.1.4;` | Hanya header dari gojo yang dipercaya |
| `real_ip_header X-Forwarded-For;` | Header yang dipakai untuk membaca IP asli |
| `real_ip_recursive on;` | Telusuri XFF dari kanan, ambil IP pertama yang tidak terpercaya |
| `X-Real-IP $remote_addr` | Karena `$remote_addr` sudah diganti, yang dikirim ke worker adalah IP klien asli |
| `X-Forwarded-For $remote_addr` | Mengirim satu IP bersih ke worker, bukan rantai |

#### nanami, todo, kirara — bagian penting skrip API

Pada `/var/www/html/api/index.php`, logika verifikasi IP klien:

```php
$remote = $_SERVER['REMOTE_ADDR'];
$client = $remote;

// hanya percaya X-Real-IP kalau request datang dari geto
if ($remote === '192.245.4.2' && !empty($_SERVER['HTTP_X_REAL_IP'])) {
    $client = $_SERVER['HTTP_X_REAL_IP'];
}

// simpan ke database
$st->execute([$_SERVER['REQUEST_URI'], $client, gethostname()]);
```

Urutan pemeriksaan ini penting. Skrip lebih dulu memeriksa apakah `REMOTE_ADDR` benar-benar geto. Kalau tidak, header apapun diabaikan dan `client_ip` diisi `REMOTE_ADDR`. Baru setelah terverifikasi sebagai geto, header `X-Real-IP` dibaca.

### Pengujian

**Uji normal dari itadori (Network 2)**

```bash
curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
```

![Soal 17 itadori normal](screenshot/soal17-itadori-normal.png)

Field `client_ip` berisi `192.245.2.10`, yaitu IP itadori sendiri, bukan IP gojo atau geto.

**Uji normal dari ino (Network 3)**

```bash
curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
```

![Soal 17 ino normal](screenshot/soal17-ino-normal.png)

Field `client_ip` berisi IP ino pada Network 3 (`192.245.3.x`). Dua client dari divisi berbeda tercatat dengan IP asli masing-masing.

**Uji header palsu dari itadori**

Klien mengirim header `X-Real-IP` palsu langsung ke geto.

```bash
curl -s -H "X-Real-IP: 10.99.99.99" http://192.245.4.2/api/
```

![Soal 17 header palsu](screenshot/soal17-header-palsu.png)

Field `client_ip` tetap berisi `192.245.2.10`, **bukan** `10.99.99.99`. Karena itadori bukan gojo, geto tidak mempercayai header yang dikirimnya dan tetap memakai `$remote_addr` hasil verifikasi. Header palsu ditolak.

**Verifikasi database di yaga**

```bash
mysql -u root db_shibuya_K68 -e "
SELECT id, client_ip, worker, created_at
FROM request_logs
ORDER BY id DESC LIMIT 10;
"
```

![Soal 17 database](screenshot/soal17-database.png)

Semua baris menunjukkan `client_ip` sesuai klien asal:

| client_ip | worker | Asal request |
|---|---|---|
| `192.245.2.10` | Nanami | itadori, Network 2 |
| `192.245.3.x` | Nanami | ino, Network 3 |

Tidak ada baris yang berisi `192.245.1.4` (gojo), `192.245.4.2` (geto), atau `10.99.99.99` (header palsu).

### Ringkasan hasil

| Uji | Hasil |
|---|---|
| Request normal itadori | `client_ip` = `192.245.2.10` |
| Request normal ino | `client_ip` = `192.245.3.x` |
| Request dengan header palsu | `client_ip` tetap IP asli itadori |
| Database yaga | Semua `client_ip` sesuai klien asal |

### Catatan

`proxy_set_header X-Forwarded-For $remote_addr;` pada geto sengaja memakai `$remote_addr`, bukan `$proxy_add_x_forwarded_for`. Dengan cara ini yang diterima worker adalah satu IP bersih, bukan rantai. Skrip API jadi tidak perlu memikirkan mana IP yang benar, karena geto sudah memverifikasinya lebih dulu.

Uji header palsu dilakukan dengan mengirim request langsung ke geto (`http://192.245.4.2/api/`), bukan lewat gojo. Tujuannya supaya header `X-Real-IP: 10.99.99.99` benar-benar berasal dari klien. Kalau uji ini dilakukan lewat gojo, header dari klien akan ditimpa gojo lebih dulu, sehingga tidak lagi menguji apakah geto mempercayai sumber yang salah.

---

## Soal 18: Kirara sebagai Backup + Passive Health Check

### Soal

> nanami dan todo merupakan worker API utama, sedangkan kirara disiapkan sebagai worker cadangan. Konfigurasikan upstream `api_cluster` pada geto agar kirara menjadi server backup, serta terapkan passive health check dengan parameter `max_fails=2` dan `fail_timeout=5s` pada worker API utama. Pastikan kirara menjalankan layanan API yang kompatibel dengan endpoint utama. Simulasikan gangguan dengan menghentikan layanan Nginx atau layanan API pada nanami dan todo. Buktikan dari klien bahwa request ke `/api` dialihkan ke kirara dan menghasilkan respons API yang valid tanpa error 502 Bad Gateway.

### Inti Soal

1. Menambahkan kirara sebagai server `backup` pada `upstream api_cluster` di geto.
2. Menerapkan passive health check `max_fails=2 fail_timeout=5s` pada nanami dan todo.
3. Memastikan kirara menjalankan API yang kompatibel dengan nanami/todo.
4. Membuktikan failover: saat nanami dan todo mati, request dialihkan ke kirara tanpa 502.
5. Membuktikan pemulihan: saat nanami dan todo hidup lagi, kirara berhenti menerima trafik.

Alur failover pada soal ini:

```
                    normal:
client --> gojo --> geto --> api_cluster --> nanami (weight=3)
                                        --> todo   (weight=1)

                    nanami & todo mati:
client --> gojo --> geto --> api_cluster --> nanami (gagal, di-skip)
                                        --> todo   (gagal, di-skip)
                                        --> kirara (backup, diambil alih)
```

`backup` pada Nginx berarti server tersebut hanya menerima trafik jika semua server non-backup tidak tersedia. Selama salah satu dari nanami atau todo masih hidup, kirara tidak akan menerima request.

### Perubahan dari Soal 17

| Node | Perubahan |
|---|---|
| geto | `upstream api_cluster` ditambah `max_fails`, `fail_timeout`, dan `backup` |
| kirara | Tidak diubah, hanya dipastikan layanan API-nya ada dan siap |
| nanami, todo | Tidak diubah, hanya dijadikan target simulasi gangguan |

### Langkah Pengerjaan

**Langkah 1.** Cek kondisi kirara: pastikan file API, Nginx, dan PHP-FPM sudah ada.

**Langkah 2.** Perbarui `/etc/nginx/sites-available/geto` pada geto: tambahkan parameter pada `upstream api_cluster`.

**Langkah 3.** Uji normal dari itadori. Pastikan hanya nanami dan todo yang menjawab.

**Langkah 4.** Matikan Nginx dan PHP-FPM pada nanami dan todo.

**Langkah 5.** Uji failover dari itadori. Pastikan semua request dijawab kirara, tanpa 502.

**Langkah 6.** Hidupkan kembali nanami dan todo.

**Langkah 7.** Uji pemulihan dari itadori. Pastikan trafik kembali ke nanami dan todo.

### Konfigurasi

#### Cek kondisi kirara

Sebelum mengubah apa pun, pastikan kirara sudah siap menerima trafik.

```bash
ls -la /var/www/html/api/
ls /etc/nginx/sites-enabled/
service nginx status
ps aux | grep fpm | grep -v grep
```

Output yang diharapkan:

```
-rw-r--r-- 1 root root 774 Oct 15 06:42 index.php   # di /var/www/html/api/
jujutsu                                             # di sites-enabled
nginx is running.
root  98  ...  php-fpm: master process
www-data 99  ...  php-fpm: pool www
www-data 100 ...  php-fpm: pool www
```

Kalau PHP-FPM belum jalan, cek nama service-nya lebih dulu:

```bash
ls /etc/init.d/ | grep -i php
```

Di kirara, nama service-nya `php8.4-fpm`. Jalankan:

```bash
service php8.4-fpm start
```

#### geto

Pada `/etc/nginx/sites-available/geto`, blok `upstream api_cluster` diperbarui.

```nginx
upstream api_cluster {
    server 192.245.4.5 weight=3 max_fails=2 fail_timeout=5s;
    server 192.245.4.6 weight=1 max_fails=2 fail_timeout=5s;
    server 192.245.4.7 backup;
}
```

Blok `server` di bawahnya tidak diubah dari soal 17.

### Penjelasan bagian penting

| Bagian | Fungsi |
|---|---|
| `max_fails=2` | Server ditandai gagal setelah 2 kali request gagal berturut-turut |
| `fail_timeout=5s` | Setelah ditandai gagal, server dilewati selama 5 detik sebelum dicoba lagi |
| `backup` pada kirara | Kirara hanya menerima trafik kalau nanami dan todo sama-sama tidak tersedia |

Parameter `max_fails` dan `fail_timeout` bekerja bersama. Begitu nanami gagal 2 kali dalam rentang `fail_timeout`, Nginx menandainya down dan melewatinya. Setelah 5 detik, Nginx mencoba lagi. Kalau masih gagal, ditandai down lagi. Ini disebut **passive health check**, karena Nginx baru tahu server mati setelah ada request yang gagal, bukan karena ping berkala.

`backup` tidak memakai `weight` karena bobot tidak relevan ketika hanya satu server cadangan yang aktif.

### Autostart

Konfigurasi `interfaces` tidak perlu diubah karena script `setup-geto.sh` yang dipanggil dari autostart sudah memuat upstream terbaru.

**geto**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.4.2
	netmask 255.255.255.0
	gateway 192.245.4.1
	up bash /root/dns.sh
	up bash /root/setup-geto.sh
```

### Perintah Menjalankan Soal 18 dari Awal

**Di kirara** (persiapan):

```bash
service nginx start
service php8.4-fpm start
```

**Di geto** (ubah upstream):

```bash
nginx -t && service nginx restart
nginx -T | grep -A 5 "upstream api_cluster"
```

**Di nanami dan todo** (pastikan hidup dulu untuk uji normal):

```bash
service nginx start
service php8.4-fpm start
```

**Di itadori** (uji normal):

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

**Di nanami dan todo** (matikan):

```bash
service nginx stop
service php8.4-fpm stop
service nginx status
```

**Di itadori** (uji failover):

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

**Di nanami dan todo** (hidupkan kembali):

```bash
service nginx start
service php8.4-fpm start
```

**Di itadori** (uji pemulihan):

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

### Pengujian

**Kondisi awal kirara**

![Soal 18 cek kirara](screenshot/soal18-kirara-cek.png)

Kirara sudah menjalankan Nginx, PHP-FPM, dan memiliki file `/var/www/html/api/index.php` yang sama dengan nanami dan todo. Karena layanan API-nya identik, kirara kompatibel dengan endpoint utama dan dapat menggantikan nanami atau todo tanpa perubahan di sisi klien.

**Konfigurasi upstream geto**

![Soal 18 upstream geto](screenshot/soal18-geto-upstream.png)

Upstream `api_cluster` memuat tiga server:

| Server | Parameter |
|---|---|
| 192.245.4.5 (nanami) | `weight=3 max_fails=2 fail_timeout=5s` |
| 192.245.4.6 (todo) | `weight=1 max_fails=2 fail_timeout=5s` |
| 192.245.4.7 (kirara) | `backup` |

**Uji normal sebelum gangguan**

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

![Soal 18 normal](screenshot/soal18-normal.png)

Semua request dijawab nanami dan todo. Rasio sekitar 3:1, dengan nanami muncul lebih sering. **Kirara tidak muncul sama sekali**, sesuai sifat `backup` yang hanya aktif kalau server utama tidak tersedia.

**Nanami dimatikan**

```bash
service nginx stop
service php8.4-fpm stop
service nginx status
```

![Soal 18 nanami mati](screenshot/soal18-nanami-mati.png)

Keluaran `nginx is not running` menandakan Nginx di nanami sudah berhenti. PHP-FPM juga dihentikan, sehingga nanami tidak dapat melayani request API sama sekali.

**Todo dimatikan**

```bash
service nginx stop
service php8.4-fpm stop
service nginx status
```

![Soal 18 todo mati](screenshot/soal18-todo-mati.png)

Sama seperti nanami, Nginx dan PHP-FPM di todo dihentikan.

**Konfirmasi failover sebelum loop**

```bash
curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
```

Respons pertama setelah keduanya mati mungkin gagal karena Nginx belum menandai nanami dan todo sebagai down. Setelah 2 kali kegagalan pada masing-masing server, geto mulai melewati keduanya dan beralih ke kirara. Request berikutnya:

```json
{"status":"ok","server":"Kirara","client_ip":"192.245.2.10"}
```

**Uji failover**

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

![Soal 18 failover](screenshot/soal18-failover.png)

Semua request dijawab kirara:

```json
{"status":"ok","server":"Kirara","client_ip":"192.245.2.10"}
```

Tidak ada `502 Bad Gateway`. Field `client_ip` tetap berisi IP asli itadori, menunjukkan bahwa header `X-Real-IP` masih diteruskan dengan benar sampai ke kirara, meskipun worker utamanya sedang mati.

**Uji pemulihan**

Setelah nanami dan todo dihidupkan kembali:

```bash
for i in $(seq 1 12); do
  curl -s --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/api/
  echo
done
```

![Soal 18 pulih](screenshot/soal18-pulih.png)

Respons kembali didominasi nanami dan todo, tanpa kirara. Nginx otomatis mengembalikan nanami dan todo ke rotasi setelah `fail_timeout=5s` berlalu dan server merespons normal kembali.

### Ringkasan hasil

| Uji | Hasil |
|---|---|
| Upstream geto | Nanami `max_fails=2 fail_timeout=5s`, todo sama, kirara `backup` |
| Uji normal | Hanya nanami dan todo, rasio sekitar 3:1 |
| Nanami dimatikan | Nginx dan PHP-FPM berhenti |
| Todo dimatikan | Nginx dan PHP-FPM berhenti |
| Failover | Semua request dijawab kirara, tanpa 502 |
| Pemulihan | Nanami dan todo kembali melayani, kirara tidak muncul |

### Catatan

Perintah `service nginx status` pada Debian mengembalikan kode keluar non-zero saat Nginx mati, sehingga terminal menampilkan `failed!` di akhir. Itu bukan kesalahan. Yang perlu diperhatikan adalah pesan `nginx is not running`, yang justru menandakan Nginx sudah berhenti sebagaimana mestinya.

Pada Debian bookworm, PHP-FPM versinya bisa 8.2, 8.3, atau 8.4 tergantung image. Nama service mengikuti versi tersebut, misalnya `php8.2-fpm` atau `php8.4-fpm`. Cek dengan `ls /etc/init.d/ | grep -i php` pada masing-masing node sebelum menjalankan perintah `service`.

Respons pertama setelah nanami dan todo dimatikan bisa gagal atau lambat, karena Nginx belum memiliki data kegagalan. Setelah `max_fails=2` terpenuhi, Nginx menandai server sebagai down dan langsung beralih ke kirara. Karena itu, ada baiknya mengirim beberapa request pemanasan lebih dulu, baru mengambil screenshot loop untuk bukti failover.

Setelah nanami dan todo dihidupkan kembali, Nginx mencoba lagi ke kedua server itu pada siklus berikutnya setelah `fail_timeout=5s` berlalu. Kalau server merespons, Nginx mengembalikannya ke rotasi. Karena itu, uji pemulihan sebaiknya dilakukan setelah menunggu sekitar 5–10 detik dari saat nanami dan todo dinyalakan.

---

## Soal 19: Proxy Caching dan Rate Limiting di gojo

### Soal

> gojo bertugas mengoptimalkan layanan web sekaligus membatasi request berlebihan. Konfigurasikan Nginx Proxy Caching untuk halaman web frontend dengan masa berlaku cache 10 menit dan tambahkan header `X-Cache-Status`. Terapkan rate limiting pada path `/api` dengan batas 10 request per detik per IP klien. Buktikan bahwa request ke halaman web yang memenuhi syarat cache menghasilkan status MISS pada akses awal dan HIT pada akses berikutnya. Uji rate limiting secara terpisah dengan mengirimkan request beruntun ke `/api`, kemudian catat status respons yang dihasilkan ketika batas terlampaui.

### Inti Soal

1. Mengaktifkan proxy caching pada path `/` di gojo dengan masa berlaku 10 menit.
2. Menambahkan header `X-Cache-Status` pada respons halaman web.
3. Menerapkan rate limiting pada path `/api` dengan batas 10 request per detik per IP klien.
4. Membuktikan cache bekerja: `MISS` pada akses pertama, `HIT` pada akses berikutnya.
5. Membuktikan rate limiting bekerja: request ke `/api` yang melebihi batas ditolak dengan status `429`.

Alur pemrosesan di gojo:

```
client --> gojo
             |-- /     --> cache check --> MISS: teruskan ke web_frontend
             |                           --> HIT:  balas dari cache
             |
             |-- /api  --> rate limit check --> lolos: teruskan ke geto_api
                                            --> lewat: balas 429
```

### Perubahan dari Soal 18

| Node | Perubahan |
|---|---|
| gojo | Ditambah `proxy_cache_path` dan `limit_req_zone` di `nginx.conf`, serta blok cache dan rate limit di `sites-available/gojo` |
| Node lain | Tidak diubah |

### Langkah Pengerjaan

**Langkah 1.** Tambahkan `proxy_cache_path` dan `limit_req_zone` di dalam blok `http` pada `/etc/nginx/nginx.conf`.

**Langkah 2.** Buat folder cache `/var/cache/nginx/jujutsu` dan beri kepemilikan ke `www-data`.

**Langkah 3.** Tambahkan blok `proxy_cache` di `location /` dan blok `limit_req` di `location /api` pada `/etc/nginx/sites-available/gojo`.

**Langkah 4.** Uji cache dari client. Periksa header `X-Cache-Status`.

**Langkah 5.** Uji rate limiting dari client. Kirim request beruntun ke `/api`, periksa status respons.

### Konfigurasi

#### gojo — `/etc/nginx/nginx.conf`

Dua direktif ditambahkan di dalam blok `http`, tepat di bawah baris `include /etc/nginx/sites-enabled/*;`.

```nginx
proxy_cache_path /var/cache/nginx/jujutsu levels=1:2 keys_zone=jujutsu_cache:10m inactive=10m max_size=1g;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
```

| Direktif | Fungsi |
|---|---|
| `proxy_cache_path` | Mendefinisikan lokasi penyimpanan cache dan zona memori untuk metadata |
| `keys_zone=jujutsu_cache:10m` | Nama zona `10 MB`, dipakai pada `proxy_cache` di server block |
| `inactive=10m` | Hapus item cache yang tidak diakses selama 10 menit |
| `max_size=1g` | Batas ukuran folder cache |
| `limit_req_zone` | Mendefinisikan zona rate limit berdasarkan IP klien |
| `$binary_remote_addr` | Kunci per IP klien, bentuk biner supaya hemat memori |
| `rate=10r/s` | Batas 10 request per detik per IP |

#### gojo — `/etc/nginx/sites-available/gojo`

Bagian `location /` ditambah blok cache, dan `location /api` ditambah blok rate limit.

```nginx
upstream web_frontend {
    server 192.245.4.3;
    server 192.245.4.4;
}

upstream geto_api {
    server 192.245.4.2;
}

server {
    listen 80;
    server_name jujutsu.K68.com www.jujutsu.K68.com;

    location / {
        proxy_pass http://web_frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_cache jujutsu_cache;
        proxy_cache_valid 200 10m;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        add_header X-Cache-Status $upstream_cache_status;
        proxy_ignore_headers Cache-Control Expires Set-Cookie;
    }

    location /api {
        limit_req zone=api_limit burst=1 nodelay;
        limit_req_status 429;

        proxy_pass http://geto_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

| Baris | Fungsi |
|---|---|
| `proxy_cache jujutsu_cache;` | Mengaktifkan cache dengan zona yang sudah didefinisikan |
| `proxy_cache_valid 200 10m;` | Respons dengan status 200 disimpan selama 10 menit |
| `proxy_cache_key "$scheme$request_method$host$request_uri";` | Kunci cache berdasarkan gabungan protokol, metode, domain, dan URL |
| `add_header X-Cache-Status $upstream_cache_status;` | Menambahkan header pada respons berisi status `MISS`, `HIT`, dan lainnya |
| `proxy_ignore_headers Cache-Control Expires Set-Cookie;` | Mengabaikan header dari worker yang bisa mematikan cache |
| `limit_req zone=api_limit burst=1 nodelay;` | Menerapkan rate limit. `burst=1` memberi toleransi 1 request lebih dari batas sebelum ditolak |
| `limit_req_status 429;` | Kode respons ketika request ditolak: `429 Too Many Requests` |

#### Membuat folder cache

Nginx memerlukan folder cache sudah ada sebelum service dijalankan.

```bash
mkdir -p /var/cache/nginx/jujutsu
chown -R www-data:www-data /var/cache/nginx
```

### Autostart

Konfigurasi `interfaces` pada gojo tidak perlu diubah karena script `setup-gojo.sh` yang dipanggil dari autostart sudah memuat konfigurasi terbaru.

**gojo**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet static
	address 192.245.1.4
	netmask 255.255.255.0
	gateway 192.245.1.1
	up bash /root/dns.sh
	up bash /root/setup-gojo.sh
```

### Perintah Menjalankan Soal 19 dari Awal

**Di gojo** (pastikan cache dan rate limit aktif):

```bash
mkdir -p /var/cache/nginx/jujutsu
chown -R www-data:www-data /var/cache/nginx
nginx -t && service nginx restart
```

**Di itadori** (uji cache):

```bash
for i in 1 2 3; do
  curl -s -D - -o /dev/null --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/ | grep -i "x-cache-status"
done
```

**Di itadori** (uji rate limit):

```bash
for i in $(seq 1 30); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    --resolve jujutsu.K68.com:80:192.245.1.4 \
    http://jujutsu.K68.com/api/
done | sort | uniq -c
```

### Pengujian

**Konfigurasi Nginx**

![Soal 19 nginx conf](screenshot/soal19-nginx-conf.png)

Dua direktif `proxy_cache_path` dan `limit_req_zone` diletakkan di dalam blok `http`, di bawah baris `include`. Penempatan ini penting karena keduanya bersifat global, bukan per server block.

Keluaran `nginx -t` menyatakan `syntax is ok` dan `test is successful`.

**Konfigurasi server block gojo**

![Soal 19 gojo config](screenshot/soal19-gojo-config.png)

Blok `location /` memuat lima baris cache, dan `location /api` memuat dua baris rate limit. Baris lama dari soal 16 dan 17 tidak diubah.

**Uji cache**

```bash
for i in 1 2 3; do
  curl -s -D - -o /dev/null --resolve jujutsu.K68.com:80:192.245.1.4 http://jujutsu.K68.com/ | grep -i "x-cache-status"
done
```

![Soal 19 cache](screenshot/soal19-cache.png)

Hasil yang diperoleh:

```
X-Cache-Status: MISS
X-Cache-Status: HIT
X-Cache-Status: HIT
```

Request pertama belum ada di cache, sehingga Nginx meneruskan ke worker dan menyimpan responsnya. Status yang dikembalikan `MISS`. Request kedua dan ketiga dilayani langsung dari cache tanpa menyentuh worker, status yang dikembalikan `HIT`. Masa berlaku cache 10 menit sesuai dengan `proxy_cache_valid 200 10m`.

**Uji rate limiting**

```bash
for i in $(seq 1 30); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    --resolve jujutsu.K68.com:80:192.245.1.4 \
    http://jujutsu.K68.com/api/
done | sort | uniq -c
```

![Soal 19 ratelimit](screenshot/soal19-ratelimit.png)

Hasil yang diperoleh:

```
      3 200
     27 429
```

Sebagian kecil request di awal dilayani dengan status `200`, sisanya ditolak dengan `429 Too Many Requests`. Status `429` menandakan rate limiting bekerja. Angka `3` dan `27` berasal dari kombinasi `rate=10r/s` dengan `burst=1` dan kecepatan loop.

### Ringkasan hasil

| Uji | Hasil |
|---|---|
| `nginx -t` | Sukses |
| Request pertama `/` | `X-Cache-Status: MISS` |
| Request kedua `/` | `X-Cache-Status: HIT` |
| Request ketiga `/` | `X-Cache-Status: HIT` |
| Loop 30 request ke `/api` | Muncul `200` dan `429` |

### Catatan

Nilai `burst=0` tidak diterima Nginx dan menghasilkan error `invalid burst value`. Nilai minimum adalah `1`. Dengan `burst=1`, satu request lebih dari batas masih ditoleransi sebelum request berikutnya ditolak.

Jumlah request yang lolos sebelum `429` tidak harus persis 10, karena Nginx mengisi ulang token secara kontinu dengan laju `rate=10r/s`, yaitu satu token setiap 100 milidetik. Sementara itu, request yang dilayani worker memakan waktu puluhan milidetik, dan request yang ditolak `429` memakan waktu sangat singkat. Karena itu, jumlah token yang tersedia saat loop berjalan tidak selalu 10. Yang dibuktikan soal adalah keberadaan `429` ketika batas terlampaui, dan itu terpenuhi.

Apabila ingin hasil yang lebih dekat ke 10, `burst` dapat dinaikkan menjadi `burst=10`. Dengan setelan itu, sekitar 11 request pertama dilayani, sisanya ditolak. Kedua setelan sama-sama memenuhi soal.

Header `X-Cache-Status` hanya muncul pada respons halaman web (path `/`), bukan pada respons API (path `/api`), karena direktif `add_header` hanya dipasang pada `location /`.

Cache dan rate limit berada di lokasi yang berbeda dan tidak saling memengaruhi. Cache bekerja pada `location /`, sementara rate limit bekerja pada `location /api`. Keduanya dapat diuji secara terpisah, dan itu yang dilakukan pada soal ini.

---

## Soal 20: Benchmark dengan Apache Benchmark dari kusakabe

### Soal

> Sebelum Curtain di Shibuya resmi dibuka, Kusakabe memimpin audit untuk menguji kapasitas layanan. Dari terminal kusakabe, jalankan benchmark menggunakan Apache Benchmark dengan parameter `-n 600 -c 30` menuju `http://jujutsu.K68.com/`. Catat Requests per Second (RPS), latensi, dan jumlah request yang gagal. Lakukan pengujian tambahan pada endpoint `/api` untuk mengamati efek rate limiting. Bandingkan hasil pengujian baseline dengan hasil ketika rate limiting aktif, serta gunakan access log gojo untuk membedakan kegagalan aplikasi, koneksi, dan request yang ditolak oleh kebijakan rate limit.

### Inti Soal

1. Menyiapkan Apache Benchmark pada kusakabe.
2. Menjalankan benchmark baseline ke web utama `/` dengan parameter `-n 600 -c 30`.
3. Menjalankan benchmark tambahan ke endpoint `/api` untuk mengamati efek rate limiting.
4. Mencatat RPS, latensi, dan jumlah request yang gagal pada kedua pengujian.
5. Membedakan jenis kegagalan melalui access log gojo: kegagalan aplikasi, kegagalan koneksi, dan penolakan rate limit.

Dua pengujian yang dilakukan:

| Pengujian | Target | Kondisi |
|---|---|---|
| Baseline | `http://jujutsu.K68.com/` | Cache aktif, tanpa rate limit |
| Rate limit | `http://jujutsu.K68.com/api/` | Rate limit `10r/s` aktif |

### Langkah Pengerjaan

**Langkah 1.** Pasang Apache Benchmark pada kusakabe.

**Langkah 2.** Tambahkan entri `/etc/hosts` supaya `jujutsu.K68.com` dapat diresolusi dari kusakabe.

**Langkah 3.** Jalankan benchmark baseline ke `/`.

**Langkah 4.** Jalankan benchmark ke `/api`.

**Langkah 5.** Periksa access log gojo untuk mengklasifikasikan status respons.

### Konfigurasi

#### kusakabe — install Apache Benchmark

Kusakabe memakai image `alpinet` sehingga paketnya diambil dengan `apk`.

```bash
apk update
apk add apache2-utils
```

`which ab` akan menampilkan path setelah instalasi selesai.

#### kusakabe — resolusi domain

Apache Benchmark tidak memiliki opsi `--resolve` seperti `curl`, sehingga domain harus benar-benar dapat diresolusi. Cara paling cepat adalah menambahkan entri manual ke `/etc/hosts`.

```bash
echo "192.245.1.4 jujutsu.K68.com www.jujutsu.K68.com" >> /etc/hosts
cat /etc/hosts
```

Entri `192.245.1.4` mengarah ke gojo. Verifikasi dengan:

```bash
ping -c 2 jujutsu.K68.com
```

Balasan berasal dari `192.245.1.4` dengan `ttl=63`, yang berarti melewati satu router, yaitu `jichi`. Ini sesuai karena kusakabe berada di Network 3 dan gojo berada di Network 1.

### Autostart Apache Benchmark

Sama seperti node lain, kusakabe kehilangan paket yang di-install saat node direstart. Hanya `/root` dan `/etc/network/interfaces` yang bertahan. Supaya Apache Benchmark tetap tersedia, pembuatan script dan pendaftaran autostart dilakukan seperti berikut.

**kusakabe**, berkas `/root/setup-ab.sh`

```bash
cat > /root/setup-ab.sh <<'SCRIPT'
#!/bin/bash
apk update
apk add apache2-utils

grep -q "jujutsu.K68.com" /etc/hosts || \
    echo "192.245.1.4 jujutsu.K68.com www.jujutsu.K68.com" >> /etc/hosts
SCRIPT
chmod +x /root/setup-ab.sh
```

**kusakabe**, berkas `/etc/network/interfaces`

```
auto eth0
iface eth0 inet dhcp
	up bash /root/setup-ab.sh
```

Baris `up bash /root/setup-ab.sh` dipanggil setiap kali interface `eth0` dinyalakan. Isi script memuat dua hal: instalasi `apache2-utils` dan penambahan entri `/etc/hosts`. Pemeriksaan `grep -q` sebelum menambahkan entri hosts mencegah duplikasi apabila node di-restart berkali-kali.

### Perintah Menjalankan Soal 20 dari Awal

**Di kusakabe** (persiapan):

```bash
apk update
apk add apache2-utils
echo "192.245.1.4 jujutsu.K68.com www.jujutsu.K68.com" >> /etc/hosts
ping -c 2 jujutsu.K68.com
```

**Di kusakabe** (benchmark baseline ke web utama):

```bash
ab -n 600 -c 30 http://jujutsu.K68.com/
```

**Di kusakabe** (benchmark tambahan ke `/api`):

```bash
ab -n 600 -c 30 http://jujutsu.K68.com/api/
```

**Di gojo** (analisis access log):

```bash
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
```

### Pengujian

#### Instalasi Apache Benchmark

![Soal 20 ab install](screenshot/soal20-ab-install.png)

Paket `apache2-utils` terpasang di kusakabe. `which ab` akan menampilkan lokasi binary setelah instalasi selesai.

#### Resolusi domain

![Soal 20 hosts](screenshot/soal20-hosts.png)

Entri `/etc/hosts` menambahkan `192.245.1.4` untuk `jujutsu.K68.com` dan `www.jujutsu.K68.com`. `ping -c 2 jujutsu.K68.com` mengonfirmasi resolusi bekerja dan jangkauan ke gojo lancar.

#### Benchmark baseline ke web utama

```bash
ab -n 600 -c 30 http://jujutsu.K68.com/
```

Output `ab` panjang, sehingga ditampilkan dalam dua bagian.

**Bagian pertama** — ringkasan utama:

![Soal 20 baseline bagian 1](screenshot/soal20-baseline-1.png)

**Bagian kedua** — connection times dan distribusi latensi:

![Soal 20 baseline bagian 2](screenshot/soal20-baseline-2.png)

Hasil:

| Field | Nilai |
|---|---|
| Server Software | nginx |
| Document Path | `/` |
| Document Length | 15 bytes |
| Concurrency Level | 30 |
| Time taken for tests | 0.101 seconds |
| Complete requests | 600 |
| Failed requests | 0 |
| Non-2xx responses | 0 |
| Total transferred | 99601 bytes |
| HTML transferred | 9000 bytes |
| **Requests per second** | **5950.43 [#/sec]** |
| **Time per request** | **5.042 [ms]** (mean) |
| **Time per request (across concurrent)** | **0.168 [ms]** (mean) |
| Transfer rate | 964.63 Kbytes/sec |

Waktu koneksi:

| Fase | min | mean | max |
|---|---|---|---|
| Connect | 1 | 2 | 4 |
| Processing | 1 | 2 | 6 |
| Waiting | 1 | 2 | 5 |
| **Total** | **3** | **5** | **7** |

Distribusi latensi:

| Persentil | Total (ms) |
|---|---|
| 50% | 5 |
| 66% | 5 |
| 75% | 5 |
| 80% | 5 |
| 90% | 6 |
| 95% | 6 |
| 98% | 6 |
| 99% | 6 |
| 100% | 7 |

RPS yang tinggi (hampir 6000) berasal dari **Nginx Proxy Caching** yang dipasang pada soal 19. Karena respons halaman web disimpan di cache, request tidak perlu menyentuh worker maki atau panda. Ukuran respons hanya 15 byte, yaitu teks `Frontend: maki\n` atau `Frontend: panda\n`. Latensi rata-rata 5 milidetik, dengan 100% request selesai di bawah 7 milidetik. Tidak ada satu pun request yang gagal.

#### Benchmark endpoint `/api` dengan rate limit

```bash
ab -n 600 -c 30 http://jujutsu.K68.com/api/
```

Output juga panjang, ditampilkan dalam dua bagian.

**Bagian pertama** — ringkasan utama:

![Soal 20 ratelimit bagian 1](screenshot/soal20-ratelimit-1.png)

**Bagian kedua** — connection times dan distribusi latensi:

![Soal 20 ratelimit bagian 2](screenshot/soal20-ratelimit-2.png)

Hasil:

| Field | Nilai |
|---|---|
| Document Path | `/api/` |
| Document Length | 60 bytes |
| Concurrency Level | 30 |
| Time taken for tests | 0.168 seconds |
| Complete requests | 600 |
| **Failed requests** | **598** |
| - Connect | 0 |
| - Receive | 0 |
| - Length | 598 |
| - Exceptions | 0 |
| **Non-2xx responses** | **597** |
| Total transferred | 187405 bytes |
| HTML transferred | 96892 bytes |
| **Requests per second** | **3563.64 [#/sec]** |
| **Time per request** | **8.418 [ms]** (mean) |
| **Time per request (across concurrent)** | **0.281 [ms]** (mean) |
| Transfer rate | 1086.99 Kbytes/sec |

Waktu koneksi:

| Fase | min | mean | max |
|---|---|---|---|
| Connect | 1 | 3 | 5 |
| Processing | 1 | 3 | 51 |
| Waiting | 1 | 3 | 51 |
| Total | 3 | 6 | 52 |

Distribusi latensi:

| Persentil | Total (ms) |
|---|---|
| 50% | 6 |
| 66% | 6 |
| 75% | 7 |
| 80% | 7 |
| 90% | 7 |
| 95% | 7 |
| 98% | 8 |
| 99% | 9 |
| 100% | 52 |

Angka `Non-2xx responses: 597` menunjukkan bahwa 597 dari 600 request dijawab dengan status selain `2xx`, yaitu `429 Too Many Requests`. Hanya 3 request yang lolos menjadi `200`.

Kolom `Failed requests: 598` **bukan berarti kegagalan koneksi**. Yang gagal terbagi menjadi beberapa kategori:

| Kategori | Jumlah |
|---|---|
| Connect | 0 |
| Receive | 0 |
| Length | 598 |
| Exceptions | 0 |

`Length: 598` muncul karena `ab` mengharapkan panjang body dari respons sukses (60 byte), tetapi menerima panjang body respons `429` yang lebih pendek. Perbedaan panjang itu dicatat sebagai `Length` mismatch. Kegagalan koneksi sendiri **nol**, dibuktikan oleh `Connect: 0`, `Receive: 0`, dan `Exceptions: 0`.

#### Analisis access log gojo

```bash
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
```

![Soal 20 access log](screenshot/soal20-access-log.png)

Hasil:

```
735 200
624 429
```

Dari hasil ini, seluruh status respons terbagi menjadi dua kelompok saja: `200` dan `429`. Tidak ada `500`, `502`, `503`, maupun `504`. Klasifikasi jenis kegagalan:

| Jenis kegagalan | Status terkait | Jumlah |
|---|---|---|
| Kegagalan aplikasi | `500`, `503` | 0 |
| Kegagalan koneksi ke upstream | `502`, `504` | 0 |
| Ditolak oleh rate limit | `429` | 624 |

Dengan demikian, seluruh request yang tidak berhasil dilayani murni karena kebijakan rate limit yang diterapkan pada soal 19, bukan karena kesalahan aplikasi maupun gangguan jaringan.

#### Tabel perbandingan

| Aspek | Baseline `/` | Rate limit `/api` |
|---|---|---|
| Total request | 600 | 600 |
| Konkurensi | 30 | 30 |
| Complete requests | 600 | 600 |
| Failed requests | 0 | 598 (semuanya `Length`) |
| Non-2xx responses | 0 | 597 (`429`) |
| Requests per second | 5950.43 | 3563.64 |
| Time per request | 5.042 ms | 8.418 ms |
| Connect failure | 0 | 0 |
| Receive failure | 0 | 0 |
| Exceptions | 0 | 0 |

Interpretasi perbandingan:

- **Baseline** menunjukkan kapasitas maksimum layanan web ketika dioptimalkan dengan cache. RPS hampir 6000 dan latensi 5 milidetik, tanpa ada request yang gagal.
- **Rate limit** menunjukkan efek pembatasan. RPS sedikit lebih rendah karena ada proses pemeriksaan rate limit di setiap request, dan latensi naik menjadi 8 milidetik.
- **Kegagalan yang muncul pada uji rate limit bukan berasal dari aplikasi maupun jaringan**, melainkan dari kebijakan pembatasan, yang dibuktikan oleh tidak adanya status `5xx` pada access log gojo.

### Nama Screenshot

| No | Nama File | Isi |
|---|---|---|
| 1 | `soal20-ab-install.png` | Instalasi `apache2-utils` di kusakabe |
| 2 | `soal20-hosts.png` | Entri `/etc/hosts` dan `ping` ke `jujutsu.K68.com` |
| 3 | `soal20-baseline-1.png` | Output `ab` ke `/`, bagian pertama (ringkasan utama) |
| 4 | `soal20-baseline-2.png` | Output `ab` ke `/`, bagian kedua (connection times) |
| 5 | `soal20-ratelimit-1.png` | Output `ab` ke `/api`, bagian pertama (ringkasan utama) |
| 6 | `soal20-ratelimit-2.png` | Output `ab` ke `/api`, bagian kedua (connection times) |
| 7 | `soal20-access-log.png` | Ringkasan status code dari access log gojo |

### Catatan

Apache Benchmark pada kusakabe berjalan di dalam image `alpinet`, sehingga paket yang dipakai adalah `apache2-utils` dari repositori Alpine. Binary yang dihasilkan bernama `ab`, versi 2.3, dan sudah mendukung seluruh parameter yang diminta soal.

Entri `/etc/hosts` dipakai karena `ab` tidak mendukung opsi `--resolve` seperti `curl`. Alternatif apabila ingin mengandalkan DNS penuh, resolver kusakabe perlu mengarah ke utahime. Namun `/etc/hosts` lebih cepat dan tidak bergantung pada kondisi DNS yang mungkin sedang diuji di soal lain.

Perbedaan hasil RPS antara baseline dan uji rate limit sebenarnya bukan indikator kegagalan. RPS pada uji rate limit justru lebih tinggi daripada yang mungkin muncul tanpa pembatasan, karena respons `429` dihasilkan langsung oleh Nginx tanpa melalui PHP-FPM atau database. Yang menjadi indikator adalah jumlah `Non-2xx responses` dan distribusi status pada access log.

Penting untuk membedakan antara **kegagalan yang dilaporkan `ab`** dan **kegagalan yang sesungguhnya**. `ab` mengkategorikan request sebagai `Failed` apabila panjang respons tidak sesuai dengan panjang respons sukses yang diharapkan. Pada uji ini, seluruh `Failed requests` berasal dari kategori `Length`, bukan `Connect` atau `Receive`, sehingga tidak ada koneksi yang gagal. Yang terjadi adalah `ab` menerima panjang respons yang berbeda dari ekspektasinya, karena sebagian besar respons berisi pesan `429` yang lebih pendek.

## Struktur Repository

```
.
├── README.md
├── CATATAN-PENGERJAAN.md
├── config/
│   ├── dns.sh                        resolver awal, dipasang di 12 host infrastruktur
│   ├── jichi/
│   │   ├── interfaces                eth0 sampai eth4 beserta baris autostart
│   │   ├── nat.sh                    ip_forward dan MASQUERADE
│   │   └── setup-relay.sh            isc-dhcp-relay
│   ├── tengen/
│   │   └── setup-dhcp.sh             isc-dhcp-server, class, pool, fixed address
│   ├── utahime/
│   │   └── setup-dns.sh              BIND9 master, zona forward dan reverse
│   ├── shoko/
│   │   └── setup-dns.sh              BIND9 slave
│   ├── yaga/
│   │   └── setup-db.sh               MariaDB master, user remote, skema
│   ├── inumaki/
│   │   └── setup-db.sh               MariaDB slave, penyambungan otomatis
│   ├── gojo/
│   │   └── setup-gojo.sh             Nginx reverse proxy, cache, rate limit
│   ├── geto/
│   │   └── setup-geto.sh             Nginx load balancer, real_ip, upstream backup
│   ├── maki/
│   │   └── setup-web.sh              Nginx + PHP-FPM frontend
│   ├── panda/
│   │   └── setup-web.sh              Nginx + PHP-FPM frontend
│   ├── nanami/
│   │   └── setup-api.sh              Nginx + PHP-FPM API endpoint
│   ├── todo/
│   │   └── setup-api.sh              Nginx + PHP-FPM API endpoint
│   ├── kirara/
│   │   └── setup-api.sh              Nginx + PHP-FPM API endpoint (backup)
│   ├── kusakabe/
│   │   └── setup-ab.sh               apache2-utils dan entri /etc/hosts
│   ├── interfaces/                   berkas interfaces 13 host infrastruktur
│   │   ├── utahime.txt
│   │   ├── shoko.txt
│   │   ├── gojo.txt
│   │   ├── geto.txt
│   │   ├── maki.txt
│   │   ├── panda.txt
│   │   ├── nanami.txt
│   │   ├── todo.txt
│   │   ├── kirara.txt
│   │   ├── yaga.txt
│   │   ├── inumaki.txt
│   │   ├── tengen.txt
│   │   └── kusakabe.txt
│   └── clients/
│       └── interfaces-alpinet.txt    dipakai 8 client, isinya dhcp
└── screenshot/
    ├── soal01-deskripsi.png          bukti soal 1
    ├── ...
    ├── soal13-deskripsi.png          bukti soal 13
    ├── soal14-maki-nginx.png         bukti soal 14
    ├── soal14-gojo-maki.png
    ├── soal14-gojo-panda.png
    ├── soal14-itadori-panda-403.png
    ├── soal14-geto-lynx.png
    ├── soal14-geto-curl.png
    ├── soal14-yaga-tabel.png
    ├── soal14-maki-interfaces.png
    ├── soal14-todo-interfaces.png
    ├── soal15-geto-config.png        bukti soal 15
    ├── soal15-maki-rasio.png
    ├── soal15-maki-urutan.png
    ├── soal15-yaga-rasio.png
    ├── soal15-geto-interfaces.png
    ├── soal16-gojo-config.png        bukti soal 16
    ├── soal16-dig-itadori.png
    ├── soal16-dig-ino.png
    ├── soal16-web-itadori.png
    ├── soal16-web-ino.png
    ├── soal16-api-client.png
    ├── soal16-forbidden-ino.png
    ├── soal16-forbidden-ino-api.png
    ├── soal16-gojo-interfaces.png
    ├── soal17-geto-config.png        bukti soal 17
    ├── soal17-itadori-normal.png
    ├── soal17-ino-normal.png
    ├── soal17-header-palsu.png
    ├── soal17-database.png
    ├── soal18-kirara-cek.png         bukti soal 18
    ├── soal18-geto-upstream.png
    ├── soal18-normal.png
    ├── soal18-nanami-mati.png
    ├── soal18-todo-mati.png
    ├── soal18-failover.png
    ├── soal18-pulih.png
    ├── soal19-nginx-conf.png         bukti soal 19
    ├── soal19-gojo-config.png
    ├── soal19-cache.png
    ├── soal19-ratelimit.png
    ├── soal20-ab-install.png         bukti soal 20
    ├── soal20-hosts.png
    ├── soal20-baseline-1.png
    ├── soal20-baseline-2.png
    ├── soal20-ratelimit-1.png
    ├── soal20-ratelimit-2.png
    └── soal20-access-log.png
```

### Urutan Menjalankan dari Keadaan Kosong

Apabila seluruh node baru dinyalakan dan belum ada autostart terpasang, urutannya seperti berikut.

| Urutan | Node | Perintah |
|---|---|---|
| 1 | jichi | `bash /root/nat.sh` |
| 2 | semua host infrastruktur | `bash /root/dns.sh` |
| 3 | tengen | `bash /root/setup-dhcp.sh` |
| 4 | jichi | `bash /root/setup-relay.sh` |
| 5 | utahime | `bash /root/setup-dns.sh` |
| 6 | shoko | `bash /root/setup-dns.sh` |
| 7 | yaga | `bash /root/setup-db.sh` |
| 8 | inumaki | `bash /root/setup-db.sh` |
| 9 | 8 client | `udhcpc -i eth0 -n` |
| 10 | maki, panda | `bash /root/setup-web.sh` |
| 11 | nanami, todo, kirara | `bash /root/setup-api.sh` |
| 12 | gojo | `bash /root/setup-gojo.sh` |
| 13 | geto | `bash /root/setup-geto.sh` |
| 14 | kusakabe | `bash /root/setup-ab.sh` |

Urutan langkah 1 sampai 9 harus dijalankan lebih dulu, karena worker dan proxy pada soal 14 sampai 20 bergantung pada layanan yang dibangun pada soal 1 sampai 13:

- **DNS** dari utahime dan shoko dipakai untuk resolusi domain `jujutsu.K68.com`.
- **Database** dari yaga dan inumaki dipakai oleh worker API untuk mencatat log request.
- **DHCP** dari tengen memastikan client Network 2 dan Network 3 memperoleh alamat dan DNS yang benar sebelum melakukan request.

Setelah langkah 1 sampai 9 selesai, barulah langkah 10 sampai 14 dijalankan untuk membangun lapisan aplikasi:

- Langkah 10 menyiapkan worker frontend (maki, panda) yang akan melayani path `/` lewat gojo.
- Langkah 11 menyiapkan worker API (nanami, todo, kirara) yang akan melayani path `/api` lewat geto.
- Langkah 12 menyiapkan gojo sebagai public reverse proxy yang menerima request dari client.
- Langkah 13 menyiapkan geto sebagai internal load balancer antara gojo dan worker API.
- Langkah 14 menyiapkan Apache Benchmark pada kusakabe untuk keperluan audit.

Dengan autostart yang sudah terpasang pada `jichi`, `tengen`, `utahime`, `shoko`, `yaga`, `inumaki`, `gojo`, `geto`, `maki`, `panda`, `nanami`, `todo`, `kirara`, dan `kusakabe`, seluruh langkah 1 sampai 14 berjalan sendiri. Setelah node dinyalakan, cukup tunggu dua sampai tiga menit sampai proses install selesai, lalu client diminta mengambil alamat.
