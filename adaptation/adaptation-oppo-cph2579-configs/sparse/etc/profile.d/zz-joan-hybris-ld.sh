# Oppo A38 (cph2579): the stock vendor is an Android-12 (ro.vndk.version=31)
# self-contained MTK BSP - unlike modern vendors it does not rely on a VNDK
# APEX snapshot; its helper libraries (libion_mtk, libgralloc_extra,
# libgralloc_metadata, libgralloctypes_mtk, libion_ulit, ...) live directly
# in /vendor/lib64. Prepend them so the libhybris bionic linker can resolve
# vendor HAL dependencies (this file runs after quirks' zz-hybris-ld.sh).
export HYBRIS_LD_LIBRARY_PATH="/vendor/lib64:/vendor/lib:${HYBRIS_LD_LIBRARY_PATH:-}"
