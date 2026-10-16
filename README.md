# DroidianLinux — Oppo A38 (CPH2579, `cph2579`)

Port **Droidian GSI (Halium 14 / base Android 14)** untuk **Oppo A38 CPH2579**

> Porting oleh **Zhantwo**. Firmware ini tidak punya codename internal —
> identitasnya generik `ossi` (lihat docs), device dikenali via model CPH2579.
(codename `cph2579`, MediaTek MT6768, kernel 4.19.191, A/B slot, dynamic partitions).

Repo ini berisi **paket adaptasi**, **build image GSI**, dan **dokumentasi port**.
Kompilasi kernel dipisah di repo kembar:

| Repo | Isi |
|---|---|
| **[giel-arch/DroidianKernel](https://github.com/giel-arch/DroidianKernel)** | packaging kernel (defconfig hasil ekstraksi boot_a, fragment Halium, parameter boot.img) + CI build `boot.img`/`vbmeta.img` |
| **giel-arch/DroidianLinux** (repo ini) | `adaptation-oppo-cph2579` (+configs), CI build image GSI api34, docs analisis firmware & HAL |

## Cara kerja (arsitektur port)

```
┌──────────────────────────────────────────────────────────────────┐
│ userdata  →  rootfs Droidian (Debian + phosh, LVM droidian-rootfs)│
│ super      →  vendor_a (BSP MTK A12, STOCK)  ← di-mount read-only │
│ boot_a/b   →  kernel 4.19 + dtb + initramfs halium (Droidian)     │
│ LXC android→  Halium GSI 14 (android-system-gsi-34-bin)           │
│               + libhybris → HAL .so dari vendor stock             │
└──────────────────────────────────────────────────────────────────┘
```

* Kernel di-build oleh CI DroidianKernel dari source resmi
  [`oppo-source/android_kernel_oppo_mt6769` branch `oppo/mt6769_u_14.0_a38_a18`](https://github.com/oppo-source/android_kernel_oppo_mt6769/tree/oppo/mt6769_u_14.0_a38_a18).
* Defconfig = **config asli yang diekstrak dari kernel `boot_a.img` (slot A)**
  dengan `extract-ikconfig` (kernel stock punya `CONFIG_IKCONFIG=y`), plus
  fragment Halium (namespace/cgroups/AppArmor/devtmpfs/VT/binder/RNDIS/BT).
* Boot image memakai **header v2 stock** (initramfs halium dari
  `initramfs-tools-halium` — ini adalah *halium-boot untuk base Android 14*
  versi packaging Droidian); `init_boot` & `vendor_boot` di device ini 100%
  kosong dan tidak dipakai.
* Image GSI di-build dengan pipeline resmi
  [`droidian-images/droidian`](https://github.com/droidian-images/droidian)
  (`community_devices.yml` + apt repo hasil CI kedua repo), apilevel **34**,
  produksi zip flashable `userdata.img` + `flash_all.sh`.

## CI

| Workflow | Trigger | Hasil |
|---|---|---|
| `adaptation` | push ke `adaptation/**` | `adaptation-oppo-cph2579*.deb` → release `latest-adaptation` + apt repo (gh-pages) |
| `droidian-image` | manual (`workflow_dispatch`) | zip image GSI Droidian api34 → release `latest-image` |

Apt repo (unsigned, `trusted=yes`):
```
deb [trusted=yes] https://giel-arch.github.io/DroidianKernel current main
deb [trusted=yes] https://giel-arch.github.io/DroidianLinux  current main
```

Urutan build pertama kali: **kernel** (DroidianKernel) → **adaptation** (repo ini)
→ **image** (manual).

## Dokumentasi

* [docs/firmware-analysis.md](docs/firmware-analysis.md) — struktur firmware
  Oppo ("mainline ossi": **system Android 14 `oplus/ossi:14` di atas vendor BSP
  MTK Android 12/SDK31**, boot v2 dengan ramdisk penuh, init_boot & vendor_boot
  zero-fill, layout super 10 GiB, erofs)
* [docs/vendor-hal-inventory.md](docs/vendor-hal-inventory.md) — semua HAL .so
  yang dibaca libhybris (hwcomposer.mt6768 HWC2, gralloc ION, sensors multihal,
  camera provider 2.6, dll.) + konfigurasi `HYBRIS_LD_LIBRARY_PATH`
* [docs/flash-guide.md](docs/flash-guide.md) — cara flash + debugging + status

## Status

Ini adalah **scaffolding port lengkap yang siap CI**: kernel + boot image +
adaptasi + image GSI semuanya buildable otomatis. Bring-up on-device
(display/audio/sensor/camera) adalah tahap berikutnya — catatan per komponen
ada di flash-guide.

## Kredit

* [Droidian](https://droidian.org) + porting guide & `linux-packaging-snippets`
* [Halium](https://halium.org) (`halium-14.0`, initramfs-tools-halium, check-kernel-config)
* Template & trik: `note10lite-droidian/linux-android-samsung-r7`,
  `droidian-devices/adaptation-droidian-angelica` (MTK MT6768), `droidian-vayu`
* Kernel source: [oppo-source](https://github.com/oppo-source) (Oppo open source)
