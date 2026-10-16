# Inventaris HAL Android (vendor_a) untuk libhybris — Oppo A38 `joan`

> Sumber: `vendor_a` (376,3 MB, **erofs**, lz4) diekstrak dari `super.img`
> (metadata liblp v10.2; `target_data` extent dalam sektor 512B) lalu di-unpack
> dengan `fsck.erofs --extract`. Semua path di bawah relatif terhadap root vendor.

## Profil vendor

* Platform: `ro.board.platform=mt6768` (nama HAL: `*.mt6768.so`)
* SDK vendor: `ro.vendor.build.version.sdk=31` (**Android 12 BSP**), `ro.vndk.version=31`
* Fingerprint: `oplus/ossi/ossi:12/SP1A.210812.016`
* Tanggal build: 2024-12-03
* Identitas: `ro.product.vendor.manufacturer=oplus`, `ro.product.vendor.model=ossi`,
  `ro.product.vendor.device=ossi` (dipakai oleh `flash-bootimage`)
* ABIs: arm64-v8a + armeabi-v7a (lib 64-bit **dan** 32-bit tersedia)

## HAL utama yang dibaca libhybris

| Fungsi | Library | Catatan |
|---|---|---|
| **Composer/HWC** | `lib64/hw/hwcomposer.mt6768.so` | HWC2 via HIDL `android.hardware.graphics.composer@2.3-service` (manifest 2.1+); dipakai backend `hwcomposer` wlroots (phoc). Stack fbdev: `CONFIG_MTK_FB` (tanpa DRM) |
| **Gralloc/allocator** | `lib64/hw/gralloc.default.so`, `android.hardware.graphics.allocator@4.0-impl-mediatek.so`, `android.hardware.graphics.mapper@4.0-impl-mediatek.so` | ION: kernel `CONFIG_ION`+`CONFIG_MTK_ION`; helper vendor `libion_mtk.so`, `libgralloc_extra.so`, `libgralloc_metadata.so`, `libgralloctypes_mtk.so`, `libion_ulit.so` (di `lib64/`) |
| **Audio** | `audio.primary.mt6768.so`, `android.hardware.audio@6.0/7.0-impl-mediatek.so` | HIDL audio 6.0/7.0 → `pulseaudio-modules-droid-hidl` + `audiosystem-passthrough` |
| **Sensors** | `sensors.mt6768.so`, `android.hardware.sensors@2.X-subhal-mediatek.so`, `sensors.dynamic_sensor_hal.so` | multihal 2.0 (`sensors@2.0-service.multihal-mediatek`) → sensorfw hybris |
| **Camera** | `android.hardware.camera.provider@2.6-impl-mediatek.so` + MTK `isphal/lomoeffect/bgservice` | akses via **droidmedia/gst-droid** (`droidian-camera`) |
| **Lights** | `lights.mt6768.so` | `lights-mtk-default.rc` |
| **Vibrator** | `vibrator.mt6768.so` + `vibrator.default.so` | |
| **GNSS/GPS** | `gps.default.so`, `android.hardware.gnss@2.1-impl-mediatek.so`, `android.hardware.gnss-impl-mediatek.so` | `gnss-service.mediatek` |
| **Bluetooth** | `android.hardware.bluetooth@1.1-impl-mediatek.so` + audio BT 2.0/2.1/2.2 | `bluebinder` (vhci over binder); WMT combo via `ttyMT*` |
| **RIL/modem** | (daemon) `mtkrild.rc`, `gsm0710muxd.rc`, `volte_*` | ofono: `ofono-binder-plugin` + `ofono2mm` |
| **Gatekeeper/Keymaster** | `gatekeeper.trustonic.so`, `kmsetkey.trustonic.so` | Trustonic TEE (tee_a) |
| **Thermal/health/memtrack/power** | impl + service masing-masing | |

## Layanan init penting (`etc/init/`)

`android.hardware.graphics.composer@2.3-service.rc`,
`android.hardware.graphics.allocator@4.0-service-mediatek.rc`,
`android.hardware.sensors@2.0-service.multihal-mediatek.rc`,
`camerahalserver.rc`, `mtkrild.rc`, `gsm0710muxd.rc`,
`android.hardware.gnss-service.mediatek.rc`,
`lights-mtk-default.rc`, `vibrator-mtk-default.rc`,
`android.hardware.boot@1.2-service.rc`, `vndservicemanager.rc`, dll.

## Konfigurasi libhybris untuk device ini

1. **Android side** = Halium GSI 14 (api34) di container LXC (`/var/lib/lxc/android`),
   dikonfigurasi `adaptation-hybris-api34-phone` + `droidian-quirks` quirks-34
   (gbinder `ApiLevel=34`, overlay `vndservicemanager.rc` dengan `libselinux_stubs`).
2. **Vendor path**: quirks-34 men-set
   `HYBRIS_LD_LIBRARY_PATH=/system/lib64:/apex/com.android.vndk.v34/lib64:/vendor/lib64/hw`.
   Karena vendor MTK v31 ini **self-contained** (tidak memakai VNDK APEX snapshot —
   helper `libion_mtk`, `libgralloc_extra`, dst. ada langsung di `lib64/` vendor),
   paket `adaptation-oppo-joan-configs` menambah
   `etc/profile.d/zz-joan-hybris-ld.sh` yang mem-prepend `/vendor/lib64:/vendor/lib`.
3. **Modul kernel**: touchscreen ILITEK/HXCHIPSET **built-in** (=y) — tidak perlu
   vendor ramdisk modul. Modul `.ko` milik vendor (`bt_drv_connac1x.ko`,
   `gps_drv.ko`, `connfem.ko`, `fpsgo.ko`, `fmradio_drv_mt6631.ko`, `met.ko`)
   ada di `vendor/lib/modules` dan dimuat dari sisi Android container.
4. **Node device** yang perlu permission udev: `/dev/ion`, `/dev/mtksync`,
   `/dev/sync`, `/dev/memtrack`, `fb0` — sudah dicover `70-joan.rules`.

## Metode ekstraksi (reproduksi)

```bash
# 1. parse metadata liblp super.img (header v10.2 + SHA256 di 0x3000)
#    partisi vendor_a: extent index 29..31, target_data dalam SEKTOR 512B
# 2. dd segmen extent → vendor_a.img
# 3. fsck.erofs --extract=vendor_root vendor_a.img
# 4. inspeksi: build.prop, lib64/hw, etc/init, etc/vintf/manifest.xml
```
