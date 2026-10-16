# Analisis struktur firmware Oppo A38 (CPH2579, `joan`)

> Sumber: backup scatter SP Flash Tool 2025-05-18 (read-only) — boot_a.img,
> init_boot_a.img, vendor_boot_a.img, dtbo_a.img, super.img + MT6768_Android_scatter.txt.
> Semua pengujian dilakukan pada salinan di work directory; folder backup tidak diubah.

## TL;DR — firmware ini "GSI-like" (temuan kunci)

Firmware stock Oppo A38 memakai arsitektur **mainline "ossi"** milik Oppo:

| Sisi | Isi | Bukti |
|---|---|---|
| **system** (+product/system_ext/my_*) | **Android 14 (SDK 34)**, generik seperti GSI, fingerprint `oplus/ossi/ossi:14/UKQ1.230924.001`, ColorOS mainline train `2024-07-01S+` (code `341919004`), security patch 2024-12-05 | `system_a` → `system/build.prop` |
| **vendor** | **BSP MTK Android 12 (SDK 31, `ro.vndk.version=31`)**, fingerprint `oplus/ossi/ossi:12/SP1A.210812.016`, dibangun 2024-12-03 | `vendor_a` → `build.prop` |

Artinya: **sistem Android 14 generik berjalan di atas vendor BSP Android 12 yang
lama** — persis pola GSI. Ini justru kabar baik untuk port Halium/Droidian:
mengganti sisi system dengan Halium GSI 14 (api34) secara struktural setara
dengan apa yang sudah dilakukan Oppo sendiri, dan vendor tidak perlu disentuh.

## Boot image (slot A) — header v2 dengan ramdisk penuh

Hasil unpack `boot_a.img` (magiskboot + parsing header manual):

| Field | Nilai |
|---|---|
| Header version | **2** (non-GKI) |
| Page size | 2048 |
| Kernel | Image **gzip** polos, 18.064.392 B (39,7 MB ter-dekompresi, **tanpa dtb appended** — `d00dfeed` tidak ada di blob) |
| Ramdisk | 23.248.723 B — **ramdisk Android first-stage penuh** (740 file, termasuk `init` dan `first_stage_ramdisk/fstab.mt6768`) |
| DTB | 139.279 B, section v2, `dtb_addr = 0x4bc80000` (= tags_addr, konvensi MTK) |
| Base/kernel/ramdisk/tags offset | `0x40000000` / `0x00080000` / `0x07c80000` / `0x0bc80000` |
| OS version / patch level (header) | 12.0.0 / 2024-12 |
| Cmdline | `bootopt=64S3,32N2,64N2 buildvariant=user` |

### init_boot dan vendor_boot: partisi hiasan

`init_boot_a.img` (8 MB) dan `vendor_boot_a.img` (64 MB) **100% zero-filled**
(diverifikasi: 0 byte non-nol). Ini bukan kerusakan backup — struktur firmware
Oppo/MTK memang **tidak memakai** layout GKI Android 13+: seluruh ramdisk
(termasuk `init` first-stage dan fstab) tetap di `boot.img` header v2. Kedua
partisi hanya placeholder. Konsekuensi untuk port: boot image Droidian cukup
mengganti `boot.img` (kernel + initramfs halium + dtb, header v2), dan
`init_boot`/`vendor_boot` **tidak perlu** digenerate atau diflash.

### fstab (`first_stage_ramdisk/fstab.mt6768`)

`system`, `system_ext`, `vendor`, `product`, `odm` semuanya **logical**
(dynamic partition) dengan `first_stage_mount` + AVB, format **erofs atau
ext4**. Tambahan partisi Oppo: `my_product`, `my_engineering`, `my_company`,
`my_carrier`, `my_region`, `my_stock`, `my_heytap`, `my_preload`, `my_bigball`,
`my_manifest`.

## Layout super.img (10 GiB)

Metadata liblp (v10.2, checksum SHA256) diparse manual; catatan penting:
**`target_data` extent di firmware ini tertulis dalam sektor 512B** (interpretasi
byte menghasilkan tiling overlap yang mustahil; interpretasi sektor terverifikasi
dengan magic erofs di offset 1024).

| Partisi | Ukuran | Keterangan |
|---|---|---|
| system_a | 776,7 MB | erofs, Android 14 `ossi` |
| system_ext_a | 1.049,9 MB | |
| **vendor_a** | **376,3 MB** | erofs, BSP MTK A12 (diekstrak & dibedah) |
| product_a | 2,0 MB | (hampir kosong; isi di my_*) |
| my_preload / my_bigball / my_stock / my_heytap | 1,38 / 1,29 / 1,06 / 0,88 GB | aplikasi & resource Oppo |
| odm_a | 260,3 MB | |
| *-cow (system/vendor/…) | ~3,9 GB total | Virtual A/B snapshot |
| (slot b setara) | | A/B |

File lengkap: `super-layout.json` di work directory analisis.

## Kernel — 4.19.191 memang benar

MTK tetap memakai **kernel 4.19** untuk MT6768 sampai base Android 14 (BSP MTK
mendukung kernel lama untuk SoC budget). Source `oppo/mt6769_u_14.0_a38_a18`
adalah tree 4.19.191 yang sama. Verifikasi:

* `extract-ikconfig` pada kernel `boot_a.img` **berhasil** (5841 baris) karena
  `CONFIG_IKCONFIG=y` + `CONFIG_IKCONFIG_PROC=y` (di-select oleh
  `CONFIG_ANDROID_DEFAULT_SETTING`).
* Config hasil ekstraksi cocok dengan `k69v1_64_k419_defconfig` di source tree
  (MTK_FB, ION/MTK_ION, IMGSENSOR keluarga `atom`, GPU Mali Valhall r32p1,
  touch ILITEK/HXCHIPSET built-in).
* Defconfig MTK di source tree memakai direktif preprosesor (`#ifdef
  OPLUS_FEATURE_*`) sehingga **gagal** diproses kconfig standar (`make
  defconfig` error) — config hasil ekstraksi dari boot_a dipakai sebagai
  defconfig base (lihat DroidianKernel).

Device tree: base `mt6768.dts` + board `k69v1_64_k419.dts`; overlay per project
di `oplus6769_*.dts` (18 entry di dtbo.img). Untuk A38: `oplus6769_22368.dts`
(charger 33 W SUPERVOOC, kamera atom ov50d40, touch 720x1612) — tapi **dtbo
stock jangan diganti** (match board-rev by bootloader).

## Implikasi untuk port Halium 14 / Droidian

1. **Vendor tidak disentuh.** Rootfs Droidian flash ke `userdata`; `vendor`
   di-mount read-only dari `super` oleh `mount-android.sh` (dm-linear
   `parse-android-dynparts`).
2. **Boot image**: header v2, kernel Image.gz + dtb section + initramfs halium
   (gzip). `init_boot`/`vendor_boot` dibiarkan stock (kosong).
3. **libhybris**: vendor v31 self-contained → `HYBRIS_LD_LIBRARY_PATH` perlu
   `/vendor/lib64` (lihat [vendor-hal-inventory.md](vendor-hal-inventory.md)).
   Halium GSI 34 menyediakan `com.android.vndk.current.apex` (v34); vendor
   tidak membutuhkan snapshot v31 APEX karena MTK BSP membawa sendiri
   dependensinya.
4. **vbmeta** kosong (flags verifikasi off) diflash untuk boot image yang
   tidak ditandatangani; dtbo **tidak** diflash (tetap stock).
