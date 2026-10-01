# march-env

CLI untuk mengelola **Environment Variables aplikasi Node.js di cPanel/CloudLinux Node.js Selector melalui SSH** dengan fokus pada keamanan secret dan perubahan yang terverifikasi.

`march-env` dibuat untuk workflow server MarchTech, tetapi dapat digunakan pada server lain yang memakai CloudLinux Node.js Selector.

## Fitur

- Membaca daftar nama environment variable tanpa mencetak nilainya.
- Mengecek apakah sebuah variable tersedia.
- Menambah atau mengubah satu variable.
- Menambah atau mengubah beberapa variable sekaligus.
- Menghapus satu atau beberapa variable.
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

Clone repository:

```bash
git clone git@github.com:MarchTechnology/march-env.git
cd march-env
```

Pasang ke user-local binary directory:

```bash
mkdir -p "$HOME/.local/bin"
install -m 700 ./march-env "$HOME/.local/bin/march-env"
```

Pastikan `$HOME/.local/bin` tersedia di `PATH`:

```bash
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null ||
  printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

export PATH="$HOME/.local/bin:$PATH"
hash -r
```

Validasi:

```bash
march-env --help
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

- value dimasukkan menggunakan hidden prompt,
- value tidak ditulis ke shell history,
- raw `cloudlinux-selector get --json` tidak pernah dicetak,
- raw stdout/stderr Selector tidak diteruskan pada error,
- temporary environment variable internal dibersihkan setelah proses selesai,
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

march-env set <app> <KEY> [--restart|--no-restart]

march-env set-many <app> <KEY> [KEY ...] [--restart|--no-restart]

march-env unset <app> <KEY> [--restart|--no-restart]

march-env unset-many <app> <KEY> [KEY ...] [--restart|--no-restart]

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

## Verifikasi Aplikasi

Setelah restart, verifikasi endpoint aplikasi jika tersedia:

```bash
curl -sS -o /dev/null -w 'health=%{http_code}\n' \
  https://example.com/health

curl -sS -o /dev/null -w 'ready=%{http_code}\n' \
  https://example.com/ready
```

## License

Internal MarchTech utility. Tambahkan atau ubah lisensi repository sesuai kebijakan distribusi yang berlaku.
