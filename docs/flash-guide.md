# Panduan flash Droidian ke Oppo A38 (CPH2579, `joan`)

> **Penting**: semua data di `userdata` hilang. Backup dulu. Pastikan vendor
> stock (super) masih Android 14 Oppo (`oplus/ossi:14`) — port ini butuh
> vendor/api34; JANGAN flash jika super masih firmware lain.
> Bootloader harus sudah ter-unlock (Oppo deep testing).

## Prasyarat

1. Bootloader unlock (deep testing app Oppo).
2. Backup firmware stock lengkap (Anda sudah punya di folder scatter backup).
3. PC dengan `fastboot` + `adb`.
4. File hasil CI:
   * `boot.img` + `vbmeta.img` — dari [DroidianKernel release `latest-kernel`](https://github.com/giel-arch/DroidianKernel/releases)
   * `droidian-oppo-joan-*.zip` — dari [DroidianLinux release `latest-image`](https://github.com/giel-arch/DroidianLinux/releases)
     (berisi `data/userdata.img`, `flash_all.sh`, dst.)

## Langkah flash

```bash
# 0. reboot ke fastboot
adb reboot bootloader

# 1. (sekali) matikan verifikasi AVB + flash boot image ke KEDUA slot
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot flash boot_a boot.img
fastboot flash boot_b boot.img

# 2. JANGAN sentuh: dtbo_a/b, super, vendor, system, product, odm, init_boot,
#    vendor_boot, modem, tee, lk, preloader — semuanya tetap stock.

# 3. flash rootfs Droidian ke userdata (image LVM ext4, first boot auto-resize)
fastboot flash userdata userdata.img

# 4. reboot
fastboot reboot
```

Alternatif: jalankan `flash_all.sh` dari dalam zip image (melakukan langkah 1+3).

> `userdata.img` ~3 GB (sparse); flash memakan waktu beberapa menit di eMMC.

## First boot

1. Initramfs halium menemukan `userdata`, memasang rootfs, menarik
   `vendor`/`vendor_dlkm` dari `super` via dm-linear, lalu menyalakan LXC
   `android` (Halium GSI 14).
2. Sistem membesarkan LV `droidian-rootfs` otomatis (stamp
   `/var/lib/halium/requires-lvm-resize`).
3. Jika layar menyala dengan logo lalu hang: lihat **Debugging** di bawah.

## Debugging

### Telnet over USB (initramfs)

Boot dengan parameter break untuk berhenti di tahap tertentu:

```
fastboot boot boot.img -c "break=premount"
telnet 192.168.2.15        # butuh USB RNDIS aktif di initramfs
```

### Log setelah boot

```bash
adb shell                     # adbd dari container android
journalctl -b -u lxc@android
journalctl -b -u phosh
```

### Kernel upgrade on-device

Paket `linux-bootimage-…` memakai `flash-bootimage`: upgrade deb otomatis
flash ke slot aktif (match `manufacturer=oplus` + `model=ossi` dari
`ro.product.vendor.*`).

## Kembali ke stock

Flash ulang backup: `boot_a/b`, `vbmeta_a/b` dari folder backup scatter
(SP Flash Tool / fastboot per partisi), lalu factory reset.

## Status yang diketahui

| Komponen | Status | Catatan |
|---|---|---|
| Kernel (4.19.191 + fragment halium) | ✅ CI GREEN | defconfig dari boot_a (IKCONFIG); boot.img + vbmeta + 6 deb di release `latest-kernel` |
| Boot image v2 + initramfs halium | ✅ CI GREEN | init_boot/vendor_boot tidak dipakai (stock kosong); dtb ≈ stock (139 KB) |
| Image GSI Droidian api34 | ✅ CI GREEN | `droidian-UNOFFICIAL-phosh-phone-oppo_joan-api34-arm64-102_*.zip` (1,6 GB) di release `latest-image` |
| Adaptasi (metapackage + configs) | ✅ CI GREEN | apt repo + release `latest-adaptation` |
| Display (hwcomposer.mt6768, HWC2/fbdev) | perlu uji on-device | phoc backend hwcomposer, scale 2 |
| Audio (HIDL 6.0/7.0) | perlu uji on-device | pulseaudio-modules-droid-hidl |
| Sensors/camera/lights/GNSS/BT | perlu uji on-device | lihat docs/vendor-hal-inventory.md |

> Catatan infrastruktur: mirror snapshot `next` Droidian mati (404 upstream);
> workflow image memakai snapshot rolling **102** (`releases.droidian.org/snapshots/102`)
> yang masih hidup dan memuat `android-system-gsi-34` (Halium 14.0 GSI, built 2026-07).
