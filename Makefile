.PHONY: all build clean efi-dirs run

EMULATOR=qemu-system-x86_64
EMULATOR_FLAGS=--machine q35 -m 256M --enable-kvm -cpu host -bios ${UEFI_FIRMWARE} -drive format=raw,file=fat:rw:dist/esp -serial stdio -display none
UEFI_BOOT_DIRECTORY=dist/esp/EFI/BOOT
UEFI_FIRMWARE=/usr/share/OVMF/x64/OVMF.4m.fd

all: build

build:
	zig build

clean:
	rm -rf dist zig-out

efi-dirs:
	mkdir -p ${UEFI_BOOT_DIRECTORY}

run: build efi-dirs
	cp zig-out/bin/bootx64.efi ${UEFI_BOOT_DIRECTORY}/BOOTX64.EFI
	${EMULATOR} ${EMULATOR_FLAGS}
