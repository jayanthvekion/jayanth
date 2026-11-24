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
- nShell — a super lightweight shell with `hello` built-in command

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

## Windows Build Instructions

### Prerequisites

Install the following tools on Windows:

```powershell
winget install nasm
winget install qemu
winget install make
```

You also need the **i686-elf cross-compiler** (gcc + ld). This is not available via winget — follow the [OSDev GCC Cross-Compiler guide](https://wiki.osdev.org/GCC_Cross-Compiler) to build it for Windows.

### Build

Open PowerShell in the project directory:

```powershell
cd C:\path\to\gammaOS-main\gammaOS-main
```

Build NovaOS:

```powershell
.\build.ps1
```

For a clean build:

```powershell
.\build.ps1 -CleanBuild
```

To skip userspace components:

```powershell
.\build.ps1 -SkipUserspace
```

### Run

Launch NovaOS in QEMU:

```powershell
.\run.ps1
```

Or with custom memory:

```powershell
.\run.ps1 -Memory 64
```

Or directly:

```powershell
qemu-system-i386 -hda bin\os.bin
```

This will boot up the kernel and drop you into the nShell prompt:

```
NovaOS v1.0.0
nova> _
```

Type `hello` to see the built-in welcome message, or run other executables from the shell.

## License

NovaOS is released under the MIT License. See LICENSE.md for details.