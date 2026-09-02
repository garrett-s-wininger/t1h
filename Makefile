.PHONY: all build clean efi-dirs run

EMULATOR=qemu-system-x86_64
EMULATOR_FLAGS=--machine q35 -m 256M -cpu max -bios ${UEFI_FIRMWARE} -drive format=raw,file=fat:rw:dist/esp -vnc ${VNC_ADDR}
UEFI_BOOT_DIRECTORY=dist/esp/EFI/BOOT
UEFI_FIRMWARE=/usr/share/OVMF/x64/OVMF.4m.fd
VNC_ADDR=0.0.0.0:0

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
