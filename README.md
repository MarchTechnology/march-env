# march-env

CLI untuk mengelola **Environment Variables aplikasi Node.js di cPanel/CloudLinux Node.js Selector melalui SSH** dengan fokus pada keamanan secret dan perubahan yang terverifikasi.

`march-env` dibuat untuk workflow server MarchTech, tetapi dapat digunakan pada server lain yang memakai CloudLinux Node.js Selector.

## Fitur

- Membaca daftar nama environment variable tanpa mencetak nilainya.
- Mengecek apakah sebuah variable tersedia.
- Menambah atau mengubah satu variable melalui hidden prompt atau value langsung pada command.
- Menambah atau mengubah beberapa variable sekaligus.
- Menghapus satu atau beberapa variable.
- Menyalin satu atau beberapa variable antar aplikasi tanpa menampilkan nilainya.
- Restart aplikasi secara eksplisit.
- Opsi `--restart` dan `--no-restart`.
- Batch update dilakukan dengan **satu kali write** ke CloudLinux Selector.
- Verifikasi bahwa variable lain tidak berubah setelah update.
- Input secret menggunakan hidden prompt.
- Tidak mencetak raw output Selector yang berpotensi mengandung secret.
- Kompatibel dengan CageFS tanpa bergantung pada `/dev/fd`.

## Requirements

Server harus memiliki:

- Bash 4+.
- Node.js.
- CloudLinux Node.js Selector:
  - `/usr/sbin/cloudlinux-selector`
- cPanel/CloudLinux dengan aplikasi Node.js yang sudah terdaftar di Node.js Selector.

Jika tersedia, `march-env` otomatis menggunakan:

```text
/bin/cagefs_enter.proxied
```

untuk menjalankan `cloudlinux-selector` di environment CageFS.

Implementasi saat ini telah digunakan dengan Node.js 24 pada CloudLinux/Passenger.

## Instalasi

Repository ini bersifat public. Instalasi tidak membutuhkan GitHub SSH key atau deploy key.

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/MarchTechnology/march-env/main/install.sh | bash
```

Installer akan:

- mengunduh `march-env` dari repository public,
- memvalidasi Bash syntax sebelum instalasi,
- memasang binary ke `~/.local/bin/march-env`,
- menggunakan permission `700`,
- melakukan replace secara atomik,
- memberi petunjuk PATH jika `~/.local/bin` belum ada di `PATH`.

Validasi:

```bash
march-env --help
```

Jika `~/.local/bin` belum ada di `PATH`:

```bash
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"
hash -r
```

### Review installer sebelum menjalankan

Untuk environment yang tidak mengizinkan `curl | bash`:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/MarchTechnology/march-env/main/install.sh \
  -o /tmp/march-env-install.sh

less /tmp/march-env-install.sh
bash /tmp/march-env-install.sh
```

### Instalasi via Git

Repository dapat di-clone langsung melalui HTTPS:

```bash
git clone https://github.com/MarchTechnology/march-env.git
cd march-env

mkdir -p "$HOME/.local/bin"
install -m 700 ./march-env "$HOME/.local/bin/march-env"
```

Tidak perlu:

```text
git@github.com
SSH deploy key
repository-specific SSH alias
```

untuk instalasi public.

### Update

Jalankan kembali installer yang sama:

```bash
curl -fsSL https://raw.githubusercontent.com/MarchTechnology/march-env/main/install.sh | bash
```

Atau jika menggunakan clone Git:

```bash
git pull --ff-only
install -m 700 ./march-env "$HOME/.local/bin/march-env"
```

### Pin ke commit atau tag

Installer mendukung `MARCH_ENV_REF`:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/MarchTechnology/march-env/main/install.sh |
  MARCH_ENV_REF=<commit-or-tag> bash
```

Custom install directory juga didukung:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/MarchTechnology/march-env/main/install.sh |
  MARCH_ENV_INSTALL_DIR="$HOME/bin" bash
```

Default:

```text
MARCH_ENV_REPO=MarchTechnology/march-env
MARCH_ENV_REF=main
MARCH_ENV_INSTALL_DIR=$HOME/.local/bin
```

## Penggunaan

### Melihat environment variable

```bash
march-env list payments
```

Contoh output:

```text
APP=payments
DOMAIN=payments.example.com
NODE=24.21.0
STATUS=started
ENV_COUNT=4
ENV_KEYS:
  DB_HOST
  DB_PASSWORD
  NODE_ENV
  SERVICE_TOKEN
```

Nilai variable tidak pernah ditampilkan oleh command ini.

### Mengecek variable

```bash
march-env has payments SERVICE_TOKEN
```

Jika tersedia:

```text
payments:SERVICE_TOKEN=SET
```

Exit code:

```text
0
```

Jika tidak tersedia:

```text
payments:SERVICE_TOKEN=MISSING
```

Exit code:

```text
3
```

### Menambah atau mengubah satu variable

Default-nya aplikasi akan direstart setelah perubahan berhasil dan terverifikasi:

```bash
march-env set payments SERVICE_TOKEN
```

Prompt:

```text
Value for payments:SERVICE_TOKEN:
Confirm value:
```

Input value tidak ditampilkan di terminal.

Value juga dapat diberikan langsung sebagai argument:

```bash
march-env set taksira-staging TAKSIRA_AUTH_ENABLED true --no-restart
```

Untuk value yang mengandung spasi, gunakan quote:

```bash
march-env set app MESSAGE "hello world" --no-restart
```

Mode positional value tidak meminta konfirmasi dan cocok untuk boolean, angka, identifier, serta nilai non-secret yang digunakan pada workflow deployment.

> **Keamanan:** value yang ditulis langsung pada command line dapat tersimpan di shell history dan terlihat sebagai argument proses. Untuk password, token, private key, atau secret lainnya, gunakan bentuk tanpa `VALUE` agar `march-env` meminta input melalui hidden prompt.

### Menambah atau mengubah variable tanpa restart eksplisit

```bash
march-env set payments SERVICE_TOKEN --no-restart
```

`--no-restart` berarti `march-env` tidak menjalankan operasi `cloudlinux-selector restart` setelah update.

> Catatan: perilaku internal CloudLinux saat menjalankan `set --env-vars` tetap ditentukan oleh versi dan konfigurasi CloudLinux yang digunakan. Opsi ini hanya menjamin bahwa `march-env` tidak melakukan restart eksplisit.

### Batch set

```bash
march-env set-many \
  payments-staging \
  KEY_ONE \
  KEY_TWO \
  KEY_THREE
```

Semua value diminta terlebih dahulu, kemudian perubahan digabung dan ditulis dalam satu operasi Selector.

Contoh output:

```text
OK: payments-staging batch set; added=3 updated=0 unchanged=0; verified; application restarted.
```

Tanpa restart eksplisit:

```bash
march-env set-many \
  payments-staging \
  KEY_ONE \
  KEY_TWO \
  KEY_THREE \
  --no-restart
```

### Menghapus satu variable

```bash
march-env unset payments OLD_KEY
```

Tanpa restart eksplisit:

```bash
march-env unset payments OLD_KEY --no-restart
```

### Batch unset

```bash
march-env unset-many \
  payments-staging \
  OLD_KEY_ONE \
  OLD_KEY_TWO
```

Tanpa restart eksplisit:

```bash
march-env unset-many \
  payments-staging \
  OLD_KEY_ONE \
  OLD_KEY_TWO \
  --no-restart
```

### Copy antar aplikasi

Menyalin satu variable dari aplikasi sumber ke aplikasi target tanpa menampilkan nilainya:

```bash
march-env copy api payments CLOUDFLARE_API_TOKEN
```

Urutan argument adalah:

```text
source-app -> target-app -> KEY
```

Default-nya aplikasi target direstart setelah perubahan berhasil dan terverifikasi.

Tanpa restart eksplisit:

```bash
march-env copy \
  api \
  payments \
  CLOUDFLARE_API_TOKEN \
  --no-restart
```

Jika key tidak tersedia pada aplikasi sumber, operasi gagal sebelum write dan aplikasi target tidak diubah.

### Batch copy

Beberapa variable dapat disalin dalam satu write:

```bash
march-env copy-many \
  api \
  payments \
  CLOUDFLARE_API_TOKEN \
  CLOUDFLARE_ZONE_ID
```

Tanpa restart eksplisit:

```bash
march-env copy-many \
  api \
  payments \
  CLOUDFLARE_API_TOKEN \
  CLOUDFLARE_ZONE_ID \
  --no-restart
```

`copy-many` memvalidasi seluruh key pada source sebelum melakukan write. Jika salah satu key hilang, target tidak diubah.

Nilai variable tidak pernah ditampilkan. Source tidak diubah; hanya environment target yang ditulis dan diverifikasi.

### Restart aplikasi

```bash
march-env restart payments
```

Workflow yang direkomendasikan untuk beberapa perubahan:

```bash
march-env set-many \
  payments-staging \
  VAR_A \
  VAR_B \
  VAR_C \
  --no-restart

march-env unset \
  payments-staging \
  OLD_VAR \
  --no-restart

march-env restart payments-staging
```

Dengan pola ini, beberapa perubahan dapat dilakukan terlebih dahulu dan restart eksplisit dilakukan satu kali di akhir.

## Perilaku Batch

Untuk:

```bash
march-env set-many app VAR_A VAR_B VAR_C
```

`march-env` menjalankan alur berikut:

```text
read environment saat ini
        ↓
prompt value VAR_A
prompt value VAR_B
prompt value VAR_C
        ↓
merge seluruh perubahan di memory
        ↓
1× cloudlinux-selector set
        ↓
read-back verification
        ↓
verifikasi variable target
        ↓
verifikasi variable lain tetap identik
        ↓
0× atau 1× restart
```

Batch tidak melakukan restart per variable.

## No-op Detection

Jika nilai yang diberikan sama dengan nilai yang sudah tersimpan, `march-env` tidak melakukan write yang tidak diperlukan.

Contoh:

```text
OK: payments-staging no changes; unchanged=3; no write; no restart.
```

Begitu juga pada `unset-many` jika semua key sudah tidak tersedia.

## Keamanan

`march-env` dirancang agar secret tidak tercetak ke terminal selama penggunaan normal.

Proteksi yang diterapkan:

- pada mode prompt, value dimasukkan menggunakan hidden prompt,
- pada mode prompt, value tidak ditulis ke shell history,
- mode direct positional value tersedia untuk automation/non-secret, tetapi nilai tersebut dapat masuk shell history,
- raw `cloudlinux-selector get --json` tidak pernah dicetak,
- raw stdout/stderr Selector tidak diteruskan pada error,
- temporary environment variable internal dibersihkan setelah proses selesai,
- `copy` / `copy-many` memindahkan nilai langsung di memory tanpa menampilkannya,
- variable lain diverifikasi tetap identik setelah perubahan.

### Batasan keamanan

CloudLinux Selector menerima environment melalui:

```text
--env-vars <JSON>
```

Karena itu, saat operasi write berlangsung, payload environment dapat sementara menjadi argument proses `cloudlinux-selector`.

`march-env` mencegah payload tersebut masuk ke shell history atau output terminal, tetapi administrator/root server secara inheren tetap dapat menginspeksi proses dan konfigurasi aplikasi.

Jangan anggap tool ini sebagai boundary terhadap administrator sistem.

## Exit Codes

| Code | Arti |
|---:|---|
| `0` | Operasi berhasil / key tersedia |
| `1` | Operasi gagal |
| `2` | Invalid usage / argument |
| `3` | `has`: key tidak tersedia |

## Command Reference

```text
march-env list <app>

march-env has <app> <KEY>

march-env set <app> <KEY> [VALUE] [--restart|--no-restart]

march-env set-many <app> <KEY> [KEY ...] [--restart|--no-restart]

march-env unset <app> <KEY> [--restart|--no-restart]

march-env unset-many <app> <KEY> [KEY ...] [--restart|--no-restart]

march-env copy <source-app> <target-app> <KEY> [--restart|--no-restart]

march-env copy-many <source-app> <target-app> <KEY> [KEY ...] [--restart|--no-restart]

march-env restart <app>
```

Default restart policy untuk operasi write adalah:

```text
--restart
```

## Contoh MarchTech

Production:

```bash
march-env list payments

march-env set \
  payments \
  PAYMENTS_PROVIDER_TRAFFIC_ENABLED

march-env restart payments

# Copy shared Cloudflare credentials without revealing values
march-env copy-many \
  api \
  payments \
  CLOUDFLARE_API_TOKEN \
  CLOUDFLARE_ZONE_ID
```

Staging:

```bash
march-env set-many \
  payments-staging \
  RECONCILIATION_INTERVAL_SECONDS \
  RECONCILIATION_BATCH_SIZE \
  RECONCILIATION_MAX_ATTEMPTS \
  --no-restart

march-env restart payments-staging
```

Contoh direct set:

```bash
march-env set \
  taksira-staging \
  TAKSIRA_AUTH_ENABLED \
  true \
  --no-restart
```

## Verifikasi Aplikasi

Setelah restart, verifikasi endpoint aplikasi jika tersedia:

```bash
curl -sS -o /dev/null -w 'health=%{http_code}\n' \
  https://example.com/health

curl -sS -o /dev/null -w 'ready=%{http_code}\n' \
  https://example.com/ready
```

## Distribusi

Repository dan installer tersedia secara public melalui GitHub. Tidak ada credential MarchTech yang diperlukan untuk mengunduh atau memasang `march-env`.

## License

Repository saat ini belum menetapkan lisensi open-source eksplisit. Akses public ke source code tidak otomatis memberikan hak redistribusi atau modifikasi di luar ketentuan yang ditetapkan pemilik repository.
