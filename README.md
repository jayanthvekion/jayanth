# NovaOS

NovaOS is a lightweight multithreaded kernel built for x86 (32-bit) computers.

> **Note:** Replace the image below with your own screenshot after booting NovaOS in QEMU.

## Features

- NovaOS bootloader
- VGA Display Support
- Disk Drivers
- PS-2 Keyboard Support
- FAT16 Filesystem Support
- nLoader — ELF Loader built exclusively for NovaOS
- nShell — a super lightweight shell

## Dependencies

To build NovaOS you will need:

- build-essential
- bison
- flex
- libgmp3-dev
- libmpfr-dev
- texinfo
- libcloog-isl-dev
- libisl-dev
- QEMU (required for running)
- i686-elf-gcc
- nasm

Refer to [GCC Cross-Compiler](https://wiki.osdev.org/GCC_Cross-Compiler) if you need help setting up the cross-compiler on your machine.

> Only QEMU is required to run NovaOS. The rest are needed for building the kernel.

## Getting Started

Build the OS image:

```
bash
make
```

Run NovaOS in QEMU:

```
bash
qemu-system-i386 -hda nova.bin
```

This will boot up the kernel and drop you into the nShell prompt:

```

nova> _
```

Type hello to see the built-in welcome message, or run other executables from the shell.

## License

NovaOS is released under the MIT License. See LICENSE.md for details.