.PHONY: all build clean efi-dirs riscv-efi riscv-vars run-native run-riscv

EDK2_SOURCE ?= /usr/local/src/edk2
GENFW       ?= ${EDK2_SOURCE}/BaseTools/BinWrappers/PosixLike/GenFw

UEFI_BOOT_DIRECTORY      ?= ${UEFI_DIST_DIRECTORY}/esp/EFI/BOOT
UEFI_DIRECTORY           ?= /usr/share/OVMF
UEFI_DIST_DIRECTORY      ?= dist
UEFI_FIRMWARE_X64        ?= ${UEFI_DIRECTORY}/x64/OVMF.4m.fd
UEFI_FIRMWARE_RISCV_CODE ?= ${UEFI_DIRECTORY}/riscv64/RISCV_VIRT_CODE.fd
UEFI_FIRMWARE_RISCV_VARS ?= ${UEFI_DIRECTORY}/riscv64/${RISCV_VARS}

RISCV_VARS      ?= RISCV_VIRT_VARS.fd
RISCV_VARS_PATH ?= ${UEFI_DIST_DIRECTORY}/${RISCV_VARS}

QEMU_X64          ?= qemu-system-x86_64
QEMU_RISCV64      ?= qemu-system-riscv64
QEMU_FLAGS_COMMON ?= -m 256M -serial stdio -display none
QEMU_FLAGS_X64    ?= --bios ${UEFI_FIRMWARE_X64} --machine q35 -drive format=raw,file=fat:rw:${UEFI_DIST_DIRECTORY}/esp
QEMU_FLAGS_RISCV  ?= --machine virt,pflash0=pflash0,pflash1=pflash1 \
	-blockdev node-name=pflash0,driver=file,read-only=on,filename=${UEFI_FIRMWARE_RISCV_CODE} \
	-blockdev node-name=pflash1,driver=file,filename=${RISCV_VARS_PATH} \
	-boot menu=on,splash-time=0 \
	-drive if=none,id=esp,format=raw,file=fat:rw:${UEFI_DIST_DIRECTORY}/esp \
	-device virtio-blk-device,drive=esp
QEMU_FLAGS_NATIVE ?= --enable-kvm -cpu host

ZIG     ?= zig
ZIG_OUT ?= zig-out/bin

all: build

build:
	${ZIG} build

clean:
	rm -rf dist zig-out

${UEFI_BOOT_DIRECTORY}:
	mkdir -p $@

efi-dirs: ${UEFI_BOOT_DIRECTORY}

riscv-efi: build efi-dirs
	${GENFW} -e UEFI_APPLICATION -o ${UEFI_BOOT_DIRECTORY}/BOOTRISCV64.EFI ${ZIG_OUT}/bootriscv64

${RISCV_VARS_PATH}: ${UEFI_FIRMWARE_RISCV_VARS} | ${UEFI_BOOT_DIRECTORY}
	cp $< $@

riscv-vars: ${RISCV_VARS_PATH}

run: run-native

run-native: build efi-dirs
	cp ${ZIG_OUT}/bootx64.efi ${UEFI_BOOT_DIRECTORY}/BOOTX64.EFI
	${QEMU_X64} ${QEMU_FLAGS_COMMON} ${QEMU_FLAGS_X64} ${QEMU_FLAGS_NATIVE}

run-riscv: riscv-efi riscv-vars
	${QEMU_RISCV64} ${QEMU_FLAGS_COMMON} ${QEMU_FLAGS_RISCV}
