# Jarkom Modul 3 - Curtain Protocol: Shibuya Incident - K-68

Repo laporan: Jarkom-Modul-3-2026-K-68
Controller: Group C -> http://10.4.89.250/ (wajib jaringan/VPN ITS)
Domain: jujutsu.K68.com  |  domain-search: K68.com

## Data pasti
- PREFIX IP = 192.245 (sama dengan Modul 2)
- Deadline demo: Kamis, 15 Oktober 2026
- Pembagian: Ryan soal 1-12, Made Gde Krisna Wangsa soal 13-20 (berurutan, bukan paralel)

## Topologi (sesuai gambar docs)
10 switch, 4 di antaranya nyambung langsung ke jichi.
Switch anak-anaknya cascade -> tetap SATU subnet per network (layer 2).

NAT1 --- jichi eth0
jichi eth1 --- Switch1 ................. utahime, shoko, gojo          [Net 1 / DMZ]
jichi eth2 --- Switch2 --+-- Switch3 --- itadori, fushiguro            [Net 2 / Divisi A]
                         +-- Switch9 --- zenin, okkotsu
jichi eth3 --- Switch4 --+-- Switch5 --- ino, kusakabe                 [Net 3 / Divisi B]
                         +-- Switch8 --- kugisaki, miwa
jichi eth4 --- Switch6 --+-- Switch7 --- geto, maki, panda,            [Net 4 / Data Center]
                         |               nanami, todo, kirara
                         +-- Switch10 -- tengen, yaga, inumaki

Total: 21 node + 10 switch + 1 NAT.
jichi butuh eth0-eth4 = 5 interface -> set Adapters = 8 (per node, bukan template global).

## Tabel IP statis
USULAN saya, bukan dari Master Sheet. Yang ditandai (SOAL) sudah pasti dari teks soal.
Kalau docs punya tabel resmi dengan angka lain, pakai angka docs.

| Node | IP | Gateway | Ket |
|---|---|---|---|
| jichi eth0 | DHCP dari NAT | - | WAN |
| jichi eth1 | 192.245.1.1 | - | gateway Net 1 (SOAL) |
| jichi eth2 | 192.245.2.1 | - | gateway Net 2 (SOAL) |
| jichi eth3 | 192.245.3.1 | - | gateway Net 3 (SOAL) |
| jichi eth4 | 192.245.4.1 | - | gateway Net 4 (SOAL) |
| utahime | 192.245.1.2 | 192.245.1.1 | DNS master (SOAL: DNS = .1.2) |
| shoko | 192.245.1.3 | 192.245.1.1 | DNS slave (SOAL: DNS = .1.3) |
| gojo | 192.245.1.4 | 192.245.1.1 | public reverse proxy |
| geto | 192.245.4.2 | 192.245.4.1 | internal LB |
| maki | 192.245.4.3 | 192.245.4.1 | worker frontend |
| panda | 192.245.4.4 | 192.245.4.1 | worker frontend |
| nanami | 192.245.4.5 | 192.245.4.1 | worker API utama |
| todo | 192.245.4.6 | 192.245.4.1 | worker API utama |
| kirara | 192.245.4.7 | 192.245.4.1 | worker API cadangan |
| yaga | 192.245.4.8 | 192.245.4.1 | DB master |
| inumaki | 192.245.4.9 | 192.245.4.1 | DB slave |
| tengen | 192.245.4.10 | 192.245.4.1 | DHCP server (SOAL) |

Seluruh client Net 2 dan Net 3 TIDAK statis - dapat IP dari DHCP.

## Pembagian jaringan
| Network | Isi | Node |
|---|---|---|
| Net 1 (192.245.1.0/24) | DMZ | utahime (DNS master), shoko (DNS slave), gojo (public reverse proxy) |
| Net 2 (192.245.2.0/24) | Divisi A (DHCP) | itadori, fushiguro (Pool 1) ; zenin, okkotsu (Pool 2) |
| Net 3 (192.245.3.0/24) | Divisi B (DHCP) | ino, kusakabe (short lease) ; miwa (long lease) ; kugisaki (fixed) |
| Net 4 (192.245.4.0/24) | Data Center | tengen, geto (LB), maki, panda (frontend), nanami, todo (API), kirara (API backup), yaga (DB master), inumaki (DB slave) |

Total 21 node + NAT + switch.

## Image docker
- debinet : jichi, tengen, utahime, shoko, gojo, geto, semua worker, semua database
- alpinet : SEMUA client (itadori, fushiguro, zenin, okkotsu, ino, kusakabe, miwa, kugisaki)

CATATAN: alpinet pakai apk (bukan apt) dan cara restart service beda.
Modul 2 semua debinet, jadi ini hal baru.

## Alokasi DHCP (dari soal)
| Apa | Rentang / nilai |
|---|---|
| Net 2 Pool 1 | 192.245.2.10 - 192.245.2.35 (itadori, fushiguro) |
| Net 2 TIDAK dialokasikan | 192.245.2.36 - 192.245.2.69 |
| Net 2 Pool 2 | 192.245.2.70 - 192.245.2.95 (zenin, okkotsu) |
| Net 3 short lease | 192.245.3.10 - 192.245.3.89, lease 1800 detik (ino, kusakabe) |
| Net 3 long lease | 192.245.3.100 - 192.245.3.199, lease 43200 detik (miwa) |
| Net 3 fixed | 192.245.3.99 (kugisaki) - di luar semua pool |
| Net 4 | subnet dideklarasikan TANPA pool dinamis |

## Progress
- [x] **Soal 1 - jichi: WAN, gateway Net1-4, ip_forward, SNAT, IP statis host**
  - jichi: eth0 DHCP dari NAT (dapat 192.168.122.101/24), eth1-eth4 statis gateway tiap network
  - Adapter jichi dinaikkan jadi 8 PER NODE (klik kanan > Configure > Network), BUKAN lewat
    Edit > Preferences, karena controller lab dipakai bareng semua kelompok.
    eth5-eth7 nganggur tanpa IP, tidak masalah.
  - eth1-eth4 TIDAK diberi baris gateway. Satu host cuma boleh punya satu default gateway,
    dan jalan keluar jichi adalah eth0 yang sudah dapat default route dari DHCP NAT.
  - /root/nat.sh: sysctl ip_forward=1 + iptables MASQUERADE out eth0
    Pakai pola "iptables -C ... || iptables -A" supaya rule tidak menumpuk tiap restart
    (pelajaran dari Modul 2: -A polos bikin rule bertambah satu setiap boot).
  - MASQUERADE dipilih, bukan SNAT, karena alamat eth0 dari DHCP dan bisa berubah.
  - 12 host infra statis + /root/dns.sh (nameserver 192.168.122.1) dipanggil lewat
    "up bash /root/dns.sh" di interfaces. Resolver awal ini wajib supaya apt-get jalan
    saat install BIND/nginx/mariadb di soal-soal berikutnya.
  - Karakter '>' disembunyikan di dalam dns.sh karena editor network config GNS3
    membuang baris yang mengandung '>'.
  - 8 client alpinet SENGAJA tidak diberi IP - itu isi soal 2-7 (dapat dari DHCP).
  - Uji lolos:
      jichi ip a -> eth0 192.168.122.101, eth1-4 192.245.1.1 / 2.1 / 3.1 / 4.1
      iptables -t nat -L POSTROUTING -n -v -> MASQUERADE out eth0 terpasang
      utahime -> gateway 192.245.1.1 ttl 64 ; 8.8.8.8 ttl 111 (akses eksternal OK)
      tengen  -> gateway 192.245.4.1 ttl 64 ; utahime 192.245.1.2 ttl 63 (lintas subnet OK)
    ttl 64 = sesubnet tidak lewat router. ttl 63 = lewat tepat satu router (jichi).
  - Backup config: config/jichi/ dan config/interfaces/
  - SS: soal01-jichi-ip.png, soal01-nat-masquerade.png, soal01-ping-utahime.png, soal01-ping-tengen.png
- [x] **Soal 2 - tengen: isc-dhcp-server, subnet Net4 tanpa pool, scope Net2 & Net3**
  - /root/setup-dhcp.sh menulis /etc/default/isc-dhcp-server + /etc/dhcp/dhcpd.conf, lalu restart.
    Ditulis lewat script karena /etc/dhcp dan /etc/default hilang tiap node restart.
  - INTERFACESv4="eth0" -> interface yang didengarkan dhcpd
  - KUNCI SOAL: subnet 192.245.4.0/24 dideklarasikan TANPA range. Wajib, karena dhcpd menolak
    start kalau interface yang didengarkan (eth0 tengen, ada di Net 4) tidak punya deklarasi
    subnet -> itu persis error "No subnet declaration for eth0" yang soal suruh hindari.
  - Scope Net 2: range .2.10-.2.35 ; Scope Net 3: range .3.10-.3.89
    (nanti dipecah jadi pool berkelas di soal 4 dan 5)
  - touch /var/lib/dhcp/dhcpd.leases supaya dhcpd punya file lease saat start pertama
  - Uji lolos: dhcpd -t -cf tanpa error ; service status -> "dhcpd is running"
  - Backup: config/tengen/setup-dhcp.sh
  - SS: soal02-dhcpd-conf.png, soal02-validasi.png
- [x] **Soal 3 - jichi: DHCP relay ke tengen (eth2, eth3)**
  - /root/setup-relay.sh: install isc-dhcp-relay, tulis /etc/default/isc-dhcp-relay, restart
  - SERVERS="192.245.4.10" (tengen)
  - INTERFACES="eth2 eth3 eth4"
    eth2 = Net 2, eth3 = Net 3 (yang direlay, sesuai soal).
    eth4 ikut didaftarkan karena itu jalur balasan dari tengen di Net 4.
  - Client alpinet pakai udhcpc (BUKAN dhclient seperti di debinet):
      udhcpc -i eth0
  - Uji lolos:
      itadori -> 192.245.2.12, "server 192.245.4.10", default via 192.245.2.1
      ino     -> 192.245.3.13, "server 192.245.4.10", default via 192.245.3.1
      dhcpd.leases di tengen terisi
    Baris "server 192.245.4.10" di output udhcpc membuktikan jawaban datang dari tengen
    di Network 4, bukan dari jichi -> relay bekerja.
  - CATATAN: "service isc-dhcp-relay status" di container ini tidak mengeluarkan output apa pun.
    Bukti relay hidup pakai: pgrep -a dhcrelay
  - Backup: config/jichi/setup-relay.sh
  - SS: soal03-relay-config.png, soal03-client-net2.png, soal03-client-net3.png, soal03-leases.png
- [x] **Soal 4 - Net2: 2 pool + DHCP class by MAC**
  - class "pool1" = itadori + fushiguro, class "pool2" = zenin + okkotsu
    Pencocokan: match if (substring(hardware,1,6) = <MAC>)
    hardware itu 7 byte (1 byte htype + 6 byte MAC), jadi diambil mulai offset 1 sepanjang 6.
  - Dua blok pool di dalam subnet 192.245.2.0, masing-masing "allow members of" kelasnya.
  - Rentang .2.36 - .2.69 TIDAK ditulis di mana pun -> otomatis tidak pernah dialokasikan.
  - WAJIB hapus lease lama sebelum uji, kalau tidak client dikasih alamat lamanya lagi:
      service isc-dhcp-server stop ; echo -n > /var/lib/dhcp/dhcpd.leases ; service isc-dhcp-server start
  - Uji lolos (bukti paling kuat: zenin & okkotsu LONCAT keluar rentang lama):
      itadori   .2.12  (Pool 1)
      fushiguro .2.10  (Pool 1)
      zenin     .2.11 -> .2.71  (Pool 2)
      okkotsu   .2.13 -> .2.70  (Pool 2)
  - SS: soal04-dhcpd-class.png, soal04-pool1.png, soal04-pool2.png, soal04-mac-net3.png
- [x] **Soal 5 - Net3: short/long lease + options DNS + domain-search**
  - class "shortlease" = ino + kusakabe, class "longlease" = miwa
  - Dua pool di subnet 192.245.3.0, lease time diatur DI DALAM blok pool (bukan global):
      short : range .3.10-.3.89   default-lease-time 1800  max-lease-time 1800
      long  : range .3.100-.3.199 default-lease-time 43200 max-lease-time 43200
    max dibuat sama dengan default supaya nilai yang diterima client pasti persis, mudah dibuktikan.
  - option domain-name-servers 192.245.1.2, 192.245.1.3 dan option domain-search "K68.com"
    dipasang global DAN diulang di subnet Net 3.
  - Uji lolos:
      ino      .3.13  lease time 1800
      kusakabe .3.14  lease time 1800
      miwa     .3.12 -> .3.100  lease time 43200   (loncat ke pool long, bukti kelas bekerja)
      resolv.conf client berisi nameserver 192.245.1.2 dan 192.245.1.3
  - CATATAN PENTING: kugisaki TIDAK dapat IP setelah soal 5. Normal, bukan error -
    dia tidak masuk kelas mana pun sedangkan kedua pool pakai "allow members of".
    Alamatnya baru muncul di soal 6 lewat host declaration (fixed-address).
  - TEMUAN: resolv.conf di client TIDAK menampilkan baris "search K68.com".
    Sebabnya udhcpc (BusyBox) tidak memproses option 119 (domain-search), dia hanya
    menulis baris search dari option 15 (domain-name).
    Perbaikan: tambahkan juga  option domain-name "K68.com";  supaya terbukti di sisi client.
    option domain-search tetap dipertahankan karena itu yang diminta soal 5.
  - SS: soal05-dhcpd-class.png, soal05-dhcpd-net3.png, soal05-short-lease.png, soal05-long-lease.png
- [x] **Soal 6 - kugisaki: fixed address .3.99**
  - Dibuat dengan host declaration DI LUAR blok subnet:
      host kugisaki { hardware ethernet 02:42:60:61:67:00; fixed-address 192.245.3.99; }
  - .3.99 ada di celah .3.90-.3.99, di luar pool short (.10-.89) dan pool long (.100-.199),
    sesuai perintah soal "di luar seluruh pool dinamis".
  - Fixed address TETAP lewat DHCP, bukan IP statis di client. Yang membedakan:
      IP statis       -> diatur di client, /etc/network/interfaces
      fixed-address   -> diatur di SERVER, dicocokkan dari MAC client
  - Sekalian diperbaiki di sini: ditambah  option domain-name "K68.com";
    supaya baris "search K68.com" muncul di resolv.conf client (udhcpc tidak memproses
    option 119 domain-search, hanya option 15 domain-name). option domain-search tetap ada.
  - Uji lolos:
      kugisaki -> 192.245.3.99, diuji 3x berturut-turut tetap sama
      resolv.conf kugisaki & ino sudah memuat "search K68.com"
  - TEMUAN: grep .3.99 di /var/lib/dhcp/dhcpd.leases hasilnya KOSONG, dan itu BENAR.
    dhcpd.leases hanya mencatat lease dinamis dari pool. Reservasi host/fixed-address adalah
    konfigurasi, bukan lease, jadi tidak pernah dicatat di situ.
    Penting untuk soal 7: kugisaki memang tidak muncul di dhcpd.leases.
  - Lease time kugisaki = 600 (default global), bukan 1800/43200, karena dia di luar kedua pool.
  - SS: soal06-host-declaration.png, soal06-kugisaki-fixed.png, soal06-resolv-search.png
- [x] **Soal 7 - verifikasi semua client + cek dhcpd.leases**
  - Tidak ada konfigurasi baru, murni verifikasi.
  - Perintah ringkas di tiap client:
      echo "=== $(hostname) ==="; ip -4 addr show eth0 | grep inet; ip route | grep default; cat /etc/resolv.conf
  - Perintah ringkas daftar lease aktif di tengen (jauh lebih enak dibaca daripada cat utuh):
      awk '/^lease/{ip=$2} /binding state active/{print ip}' /var/lib/dhcp/dhcpd.leases | sort -u
  - Hasil akhir, 8 alamat semuanya berbeda dan sesuai kebijakan:
      itadori   192.245.2.12   Pool 1 (.10-.35)
      fushiguro 192.245.2.10   Pool 1
      zenin     192.245.2.71   Pool 2 (.70-.95)
      okkotsu   192.245.2.70   Pool 2
      ino       192.245.3.13   short (.10-.89)
      kusakabe  192.245.3.14   short
      miwa      192.245.3.100  long (.100-.199)
      kugisaki  192.245.3.99   fixed
    Tidak ada satu pun di rentang terlarang .2.36-.2.69. Semua client punya gateway,
    broadcast .255, dua nameserver, dan "search K68.com".
  - dhcpd.leases berisi 7 lease aktif (8 client dikurangi kugisaki yang fixed-address).
  - TEMUAN: ada entri "binding state abandoned" untuk .3.10/.3.11/.3.12, sisa lease lama
    sebelum kebijakan pool diterapkan. dhcpd menawarkan alamat itu, cek dengan ping,
    ternyata masih terpakai client lama yang belum melepas -> ditandai abandoned.
    Tidak mengganggu: filter "binding state active" sudah menyaringnya, dan tidak ada
    alamat aktif yang bertabrakan.
  - SS: soal07-client-net2.png, soal07-client-net3.png, soal07-leases-aktif.png
- [x] **Soal 8 - tcpdump DORA + giaddr**
  - Dua jendela: tengen capture, client minta lease.
      di tengen : apt-get install -y tcpdump ; tcpdump -i eth0 -nv port 67 or port 68
      di client : udhcpc -i eth0 -n
  - DORA lengkap terekam: Discover -> Offer -> Request -> ACK
  - Nilai yang diminta soal, dari client ino (Net 3):
      Server-ID (opt 54) : 192.245.4.10
      Your-IP            : 192.245.3.13
      Lease-Time (opt 51): 1695
      Gateway-IP (giaddr): 192.245.3.1
  - Dari client itadori (Net 2): giaddr 192.245.2.1, Your-IP 192.245.2.12, Lease-Time 529
  - INTI SOAL: giaddr berubah mengikuti interface jichi yang MENERIMA permintaan.
    tengen tidak terhubung langsung ke Net 2/Net 3, jadi dia membaca giaddr untuk memutuskan
    subnet mana yang dipakai menjawab. giaddr .3.1 -> jawab dari pool Net 3, .2.1 -> pool Net 2.
    Paket juga terlihat datang dari IP jichi, bukan IP client - konsekuensi relay.
  - Lease-Time 1695 (bukan 1800) karena client sudah punya lease sebelumnya, dhcpd memberikan
    SISA waktu lease yang ada, bukan menghitung ulang dari nol.
  - TIDAK DIPAKAI: capture kugisaki. Itu renew UNICAST langsung ke 192.245.4.10 (client sudah
    punya IP, tidak lewat relay), bukan DORA. Di situ muncul Gateway-IP 192.245.4.1 (eth4 jichi)
    karena dhcrelay juga mendengarkan eth4 - membingungkan, jadi tidak dilampirkan.
  - SS: soal08-dora-net3.png, soal08-dora-net2.png
- [x] **Soal 9 - matikan relay, amati gejala, pulihkan**
  - Tahap 1 (jichi): service isc-dhcp-relay stop
  - Tahap 2 (ino)  : ip addr flush dev eth0 ; udhcpc -i eth0 -n -t 4 -T 2
      GEJALA: "broadcasting discover" 4x berturut-turut, tidak ada satu pun select/lease,
      berakhir "udhcpc failed to get a DHCP lease" / "no lease, failing",
      dan ip a setelahnya TIDAK punya alamat IPv4 sama sekali.
      -t 4 -T 2 dipakai supaya udhcpc menyerah cepat, tidak menunggu lama.
  - Tahap 3 (jichi): service isc-dhcp-relay start -> pgrep muncul lagi
  - Tahap 4 (ino)  : udhcpc -i eth0 -n -> 192.245.3.13 (pool short .10-.89),
      default via 192.245.3.1 - gateway kembali seperti semula
  - SEBAB gejalanya: permintaan DHCP itu BROADCAST, dan broadcast tidak menyeberangi router.
    Tanpa relay, paket ino berhenti di jichi dan tidak pernah sampai ke tengen di Network 4.
  - CATATAN: setelah service stop, "pgrep -a dhcrelay" masih menampilkan "201 [dhcrelay]".
    Tanda kurung siku = proses sudah mati tapi belum dibersihkan dari tabel proses (defunct),
    BUKAN berarti masih jalan. Buktinya setelah start PID berubah 201 -> 244.
    Bukti sebenarnya ada di gejala client yang gagal total.
  - SS: soal09-relay-mati.png, soal09-client-gagal.png, soal09-relay-hidup.png, soal09-client-pulih.png
- [x] **Soal 10 - autostart DHCP server + relay, restart node**
  - tengen /etc/network/interfaces, blok eth0 ditambah:
      up bash /root/dns.sh
      up bash /root/setup-dhcp.sh
    Urutan penting: dns.sh dulu (pasang resolver), baru setup-dhcp.sh (butuh DNS untuk apt-get).
  - jichi /etc/network/interfaces, blok eth4 ditambah:
      up bash /root/setup-relay.sh
    Ditaruh di eth4 (bukan eth0) supaya saat script jalan eth2/eth3/eth4 semuanya sudah hidup.
  - CATATAN: saat node restart, PAKET yang di-install ikut hilang, bukan cuma file config.
    Makanya setup-dhcp.sh dan setup-relay.sh harus memuat apt-get install di dalamnya.
    Setelah restart perlu tunggu 2-3 menit sampai install selesai.
  - Uji lolos TANPA menjalankan script manual apa pun setelah restart:
      jichi : dhcrelay hidup sendiri (PID 468), MASQUERADE terpasang (12 paket lewat), eth4 .4.1
      tengen: dhcpd running, /etc/dhcp/dhcpd.conf lengkap termasuk class
      Pool 1  itadori .2.11 / fushiguro .2.12
      Pool 2  zenin .2.71 / okkotsu .2.72
      short   ino .3.10  lease 1800
      long    miwa .3.100 lease 43200
      fixed   kugisaki .3.99
    Kelima kebijakan tetap berlaku.
  - CATATAN: alamat Net 2 bergeser dari sebelumnya (itadori .2.12->.2.11, okkotsu .2.70->.2.72)
    karena /var/lib/dhcp/dhcpd.leases ikut hilang saat restart, jadi server membagi ulang bebas
    DI DALAM pool masing-masing. Yang dinilai kebijakannya, bukan angka persisnya.
  - SS: soal10-jichi-autostart.png, soal10-tengen-autostart.png, soal10-kebijakan-net2.png, soal10-kebijakan-net3.png
- [x] **Soal 11 - BIND9 master/slave utahime-shoko**
  - Domain: jujutsu.K68.com | utahime .1.2 (master) | shoko .1.3 (slave)
  - Semua config ditulis lewat /root/setup-dns.sh karena /etc/bind hilang tiap node restart.
  - utahime named.conf.local: type master, notify yes, also-notify 192.245.1.3,
    allow-transfer 192.245.1.3
  - shoko named.conf.local: type slave, masters 192.245.1.2
    WAJIB chown -R bind:bind /etc/bind/jarkom - file hasil transfer ditulis proses named
    yang berjalan sebagai user bind.
  - Zona: SOA -> utahime.jujutsu.K68.com, NS utahime + shoko, A record kedua nameserver.
  - Uji lolos:
      dig @192.245.1.2 dan @192.245.1.3 jujutsu.K68.com NS -> keduanya flag "aa", ANSWER: 2
      Serial sebelum : utahime 2026101501 | shoko 2026101501
      Naikkan serial di utahime jadi 2026101502, jalankan ulang script
      Serial sesudah : utahime 2026101502 | shoko 2026101502
    Shoko ikut naik TANPA disentuh sama sekali -> bukti zone transfer otomatis bekerja.
  - CATATAN: jangan cat file zona di SLAVE, formatnya biner (raw), keluarnya sampah.
    Cukup tunjukkan named.conf.local yang memperlihatkan "type slave".
  - SS: soal11-config-utahime.png, soal11-config-shoko.png, soal11-dig-ns.png,
        soal11-naikkan-serial.png, soal11-serial-sync.png
- [x] **Soal 12 - A record + CNAME www + PTR + forwarder**
  - Semua ditambahkan ke /root/setup-dns.sh di utahime, serial dinaikkan ke 2026101503.
  - A record apex   : @ IN A 192.245.1.4  -> jujutsu.K68.com mengarah ke gojo
  - CNAME           : www IN CNAME jujutsu.K68.com.   (titik di akhir WAJIB)
  - Reverse zone    : zona baru "1.245.192.in-addr.arpa" type master,
                      allow-transfer + also-notify ke shoko seperti zona forward.
                      Isi PTR: 2 -> utahime, 3 -> shoko, 4 -> jujutsu.K68.com.
                      PTR .1.4 diarahkan ke jujutsu.K68.com (bukan gojo.jujutsu.K68.com)
                      karena soal minta "melacak IP gojo kembali ke DOMAIN RESMINYA",
                      dan domain yang memetakan ke IP itu adalah jujutsu.K68.com.
  - Forwarder       : forwarders { 192.168.122.1; } di named.conf.options
  - Record gojo IN A 192.245.1.4 ikut ditambahkan supaya zona lengkap (tidak diminta soal).
  - Uji lolos dari client ino:
      dig jujutsu.K68.com +short      -> 192.245.1.4
      dig www.jujutsu.K68.com         -> CNAME jujutsu.K68.com. lalu A 192.245.1.4, flag "aa"
      dig -x 192.245.1.4 +short       -> jujutsu.K68.com.
      ping -c 3 google.com            -> 3 received, 0% loss (forwarder bekerja)
  - GOTCHA alpinet: BusyBox ping mengharuskan opsi SEBELUM target.
      SALAH : ping google.com -c 3   -> "ping: -c: Name does not resolve"
      BENAR : ping -c 3 google.com
    Di node debinet urutan bebas, di alpinet tidak.
  - SS: soal12-zona-forward.png, soal12-zona-reverse.png, soal12-forwarder.png, soal12-dig-ping.png

- [x] **Soal 13 - MariaDB master/slave yaga-inumaki, db_shibuya_K68**
  - yaga = master (192.245.4.8), inumaki = slave (192.245.4.9)
  - /root/setup-db.sh di masing-masing node. Config ditulis ke
    /etc/mysql/mariadb.conf.d/99-master.cnf dan 99-slave.cnf.
    Diberi prefix 99- supaya dibaca SETELAH 50-server.cnf bawaan Debian dan
    menimpa bind-address 127.0.0.1 -> 0.0.0.0. Tanpa ini slave tidak bisa connect.
  - master: server-id=1, log-bin=mysql-bin, binlog_format=ROW
  - slave : server-id=2
  - Hak akses remote seluruh Network 4 (soal minta ini):
      'replica'@'192.245.4.%'  -> GRANT REPLICATION SLAVE   (untuk replikasi)
      'shibuya'@'192.245.4.%'  -> GRANT ALL ON db_shibuya_K68.*  (untuk aplikasi soal 14/17)
  - Sambungan slave: SHOW MASTER STATUS di yaga -> File mysql-bin.000001, Position 1179
    lalu CHANGE MASTER TO + START SLAVE di inumaki dengan angka itu.
  - URUTAN PENTING: replikasi dinyalakan DULU, baru CREATE DATABASE + CREATE TABLE di master.
    Dengan urutan ini DDL ikut tereplikasi, jadi struktur tabel muncul sendiri di slave.
    Kalau dibuat sebelum START SLAVE, slave mulai dari posisi setelahnya dan tabel
    tidak akan pernah ada di sana.
  - Tabel request_logs sengaja dibuat lengkap sejak awal:
      id, endpoint, client_ip, worker, created_at
    client_ip untuk soal 17, worker untuk bukti pembagian beban soal 15 & 18.
    Jadi Made tidak perlu ALTER TABLE belakangan.
  - Uji lolos:
      Slave_IO_Running: Yes, Slave_SQL_Running: Yes, Master_Host 192.245.4.8
      INSERT 1 baris di yaga -> database, tabel, DAN barisnya muncul di inumaki
      tanpa apa pun dibuat manual di slave. Bukti replikasi DDL + DML.
  - GOTCHA: "Slave_IO_Running: Connecting" sesaat setelah START SLAVE itu NORMAL -
    koneksi masih dibangun. Tunggu beberapa detik lalu cek lagi, bukan langsung didebug.
  - Backup: config/yaga/setup-db.sh, config/inumaki/setup-db.sh
  - SS: soal13-master-config.png, soal13-slave-status.png, soal13-tabel.png,
        soal13-insert-master.png, soal13-replikasi-slave.png

---

## STATUS: SOAL 1-13 (BAGIAN RYAN) SELESAI SEMUA

### Yang perlu diserahkan ke Made (soal 14-20)

**Alamat yang sudah siap dipakai**
| Node | IP | Peran |
|---|---|---|
| yaga | 192.245.4.8 | DB master - SUDAH JADI, tinggal dipakai |
| inumaki | 192.245.4.9 | DB slave - SUDAH JADI |
| maki | 192.245.4.3 | worker frontend (soal 14) |
| panda | 192.245.4.4 | worker frontend (soal 14) |
| nanami | 192.245.4.5 | worker API utama (soal 14, 15, 18) |
| todo | 192.245.4.6 | worker API utama (soal 14, 15, 18) |
| kirara | 192.245.4.7 | worker API cadangan (soal 18) |
| geto | 192.245.4.2 | internal load balancer (soal 15, 17) |
| gojo | 192.245.1.4 | public reverse proxy (soal 16, 17, 19) |

**Nama DNS yang sudah hidup**
- jujutsu.K68.com      -> 192.245.1.4 (gojo)
- www.jujutsu.K68.com  -> CNAME ke jujutsu.K68.com
- utahime/shoko/gojo.jujutsu.K68.com -> A record masing-masing
- Forwarder aktif, client bisa resolve domain internet

**Database sudah siap dipakai (hasil soal 13)**
- Host   : 192.245.4.8 (yaga), direplikasi otomatis ke 192.245.4.9 (inumaki)
- DB     : db_shibuya_K68
- Tabel  : request_logs (id, endpoint, client_ip, worker, created_at)
- User   : shibuya / shibuyapass, berlaku dari seluruh 192.245.4.%
- Kolom client_ip sudah ada untuk soal 17, kolom worker untuk soal 15 & 18.
  TIDAK perlu ALTER TABLE.

**Pola kerja yang WAJIB diikuti**
1. Semua config ditulis lewat script di /root, JANGAN ketik langsung ke /etc.
   /etc dan paket yang di-install HILANG setiap node restart.
2. Autostart dipasang lewat /etc/network/interfaces:  up bash /root/<script>.sh
   (node harus mati saat mengedit; editor GNS3 membuang baris yang mengandung '>')
3. Script harus memuat apt-get install di dalamnya, karena paket ikut hilang saat restart.

**Node yang BELUM dipasangi autostart** (perlu bash manual setelah restart)
- utahime : /root/setup-dns.sh
- shoko   : /root/setup-dns.sh
Disarankan Made menambahkan "up bash /root/setup-dns.sh" di interfaces kedua node itu.

**Catatan alpinet (8 client)**
- apk add, bukan apt-get
- DHCP client: udhcpc -i eth0 -n
- ping: opsi HARUS sebelum target -> ping -c 3 google.com
- kusakabe butuh ApacheBench untuk soal 20: apk add apache2-utils

### Sisa pekerjaan Ryan
- [ ] Susun README repo GitHub Jarkom-Modul-3-2026-K-68 (soal 1-13)
- [ ] Atur jadwal demo dengan asisten (deadline Kamis 15 Oktober 2026)
- [ ] Soal 13 - MariaDB master/slave yaga-inumaki, db_shibuya_K68
- [ ] Soal 14 - Nginx+PHP-FPM worker, vhost, batasi akses langsung
- [ ] Soal 15 - geto: LB weighted round robin 3:1 (nanami:todo)
- [ ] Soal 16 - gojo: path-based routing (/ -> maki+panda, /api -> geto)
- [ ] Soal 17 - X-Real-IP / X-Forwarded-For -> kolom client_ip
- [ ] Soal 18 - kirara backup + max_fails=2 fail_timeout=5s
- [ ] Soal 19 - proxy cache 10 menit + X-Cache-Status + rate limit 10 r/s
- [ ] Soal 20 - ab -n 600 -c 30 dari kusakabe

## Catatan penting dibawa dari Modul 1 & 2
- Hanya /root dan /etc/network/interfaces yang BERTAHAN saat node restart.
  Semua config lain harus ditulis ulang oleh script di /root.
- Editor "Edit network configuration" GNS3 MEMBUANG baris yang mengandung karakter '>'.
  Sembunyikan perintah redirect di dalam file .sh, panggil lewat: up bash /root/xxx.sh
- Jangan ubah template Docker lewat Edit > Preferences (remote controller dipakai bareng
  semua kelompok). Ubah adapter PER NODE: klik kanan > Configure > Network > Adapters.
  jichi butuh eth0-eth4 = 5 interface, set 8 untuk cadangan.
- Kalau DNS mati: cek status service di MASTER dulu. named-checkzone di SLAVE selalu
  error palsu (file zona slave disimpan format raw/biner, bukan teks).

## MAC address client (dikumpulkan di soal 4)
| Client | Network | MAC |
|---|---|---|
| itadori | 2 | 02:42:17:51:a0:00 |
| fushiguro | 2 | 02:42:1f:87:4e:00 |
| zenin | 2 | 02:42:e8:81:d1:00 |
| okkotsu | 2 | 02:42:21:d8:76:00 |
| ino | 3 | 02:42:63:d1:c3:00 |
| kusakabe | 3 | 02:42:07:5d:fd:00 |
| miwa | 3 | 02:42:7a:74:c4:00 |
| kugisaki | 3 | 02:42:60:61:67:00 |
