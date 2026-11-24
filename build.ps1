#requires -version 3.0

<#
.SYNOPSIS
    Build script for NovaOS on Windows (replaces the Linux Makefile)

.DESCRIPTION
    Compiles the NovaOS kernel, bootloader, and userspace components
    into a bootable disk image (bin/os.bin) using native Windows tools.

    Required tools (install on Windows):
      - nasm       (assembler)       : winget install nasm
      - i686-elf-gcc (cross-compiler): follow OSDev cross-compiler guide
      - i686-elf-ld  (cross-linker)  : part of the cross-compiler toolchain
      - QEMU       (emulator)        : winget install qemu

.NOTES
    Does NOT mount/copy usrspc into disk image (requires Linux sudo mount).
    Copy usrspc files manually or use mtools for Windows.
#>


param(
    [switch]$CleanBuild,
    [switch]$SkipUserspace
)

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BIN_DIR = Join-Path $ROOT "bin"
$BUILD_DIR = Join-Path $ROOT "build"
$TOOL_PREFIX = "i686-elf-"

$CFLAGS = "-g", "-ffreestanding", "-falign-jumps", "-falign-functions", "-falign-labels", `
          "-falign-loops", "-fstrength-reduce", "-fomit-frame-pointer", "-finline-functions", `
          "-Wno-unused-function", "-fno-builtin", "-Werror", "-Wno-unused-label", "-Wno-cpp", `
          "-Wno-unused-parameter", "-Wno-unused-variable", "-Wno-unused-value", "-nostdlib", `
          "-nostartfiles", "-nodefaultlibs", "-Wall", "-O0", "-Iinc"

function Run-Cmd {
    param([string]$exe, [string[]]$args)
    Write-Host "`t$exe $args" -ForegroundColor Cyan
    & $exe @args
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $exe $args (exit code $LASTEXITCODE)"
    }
}

function Ensure-Dir {
    param([string]$path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Clean {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    if (Test-Path $BIN_DIR) { Remove-Item -Recurse -Force $BIN_DIR -ErrorAction SilentlyContinue }
    if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Build bootloader
# ---------------------------------------------------------------------------
function Build-Bootloader {
    Write-Host "Building bootloader..." -ForegroundColor Green
    Ensure-Dir $BIN_DIR
    Run-Cmd -exe "nasm" -args @("-f", "bin", "$ROOT\boot\boot.s", "-o", "$BIN_DIR\boot.bin")
}

# ---------------------------------------------------------------------------
# Build kernel objects
# ---------------------------------------------------------------------------
function Build-KernelObjects {
    Write-Host "Building kernel objects..." -ForegroundColor Green
    Ensure-Dir $BUILD_DIR

    $objects = @()
    $asmObjects = @{
        "$BUILD_DIR\kernel.s.o"   = "$ROOT\kernel\kernel.s"
        "$BUILD_DIR\idt\idt.S.o"  = "$ROOT\kernel\idt\idt.S"
        "$BUILD_DIR\io\io.s.o"    = "$ROOT\io\io.s"
        "$BUILD_DIR\mm\paging\paging.s.o" = "$ROOT\mm\paging\paging.s"
        "$BUILD_DIR\gdt\gdt.s.o"  = "$ROOT\kernel\gdt\gdt.s"
        "$BUILD_DIR\task\tss\tss.s.o" = "$ROOT\kernel\task\tss\tss.s"
        "$BUILD_DIR\task\task.s.o"    = "$ROOT\kernel\task\task.s"
    }

    $cObjects = @{
        "$BUILD_DIR\kernel\kernel.o"       = "$ROOT\kernel\kernel.c"
        "$BUILD_DIR\idt\idt.o"             = "$ROOT\kernel\idt\idt.c"
        "$BUILD_DIR\mm\memory.o"           = "$ROOT\mm\memory.c"
        "$BUILD_DIR\mm\heap\heap.o"        = "$ROOT\mm\heap\heap.c"
        "$BUILD_DIR\mm\heap\kheap.o"       = "$ROOT\mm\heap\kheap.c"
        "$BUILD_DIR\mm\paging\paging.o"    = "$ROOT\mm\paging\paging.c"
        "$BUILD_DIR\drivers\disk\disk.o"   = "$ROOT\drivers\disk\disk.c"
        "$BUILD_DIR\drivers\display\vga\vga.o" = "$ROOT\drivers\display\vga\vga.c"
        "$BUILD_DIR\fs\parser\parser.o"    = "$ROOT\fs\parser\parser.c"
        "$BUILD_DIR\fs\vfs\vfs.o"          = "$ROOT\fs\vfs\vfs.c"
        "$BUILD_DIR\fs\fat16\fat16.o"      = "$ROOT\fs\fat16\fat16.c"
        "$BUILD_DIR\fs\file.o"             = "$ROOT\fs\file.c"
        "$BUILD_DIR\string\string.o"       = "$ROOT\string\string.c"
        "$BUILD_DIR\kernel\gdt\gdt.o"      = "$ROOT\kernel\gdt\gdt.c"
        "$BUILD_DIR\kernel\task\task.o"    = "$ROOT\kernel\task\task.c"
        "$BUILD_DIR\kernel\task\process\process.o" = "$ROOT\kernel\task\process\process.c"
        "$BUILD_DIR\idt\__0x80\__0x80.o"   = "$ROOT\kernel\idt\__0x80\__0x80.c"
        "$BUILD_DIR\idt\__0x80\io\io.o"    = "$ROOT\kernel\idt\__0x80\io\io.c"
        "$BUILD_DIR\drivers\keyboard\keyboard.o" = "$ROOT\drivers\keyboard\keyboard.c"
        "$BUILD_DIR\drivers\keyboard\ps2\ps2.o"  = "$ROOT\drivers\keyboard\ps2\ps2.c"
        "$BUILD_DIR\g-loader\elf\elf.o"    = "$ROOT\g-loader\elf\elf.c"
        "$BUILD_DIR\g-loader\g-loader.o"   = "$ROOT\g-loader\g-loader.c"
        "$BUILD_DIR\idt\__0x80\mm\heap\heap.o" = "$ROOT\kernel\idt\__0x80\mm\heap\heap.c"
        "$BUILD_DIR\idt\__0x80\process\process.o" = "$ROOT\kernel\idt\__0x80\process\process.c"
    }

    foreach ($objPath in $asmObjects.Keys) {
        $srcPath = $asmObjects[$objPath]
        $objDir = Split-Path -Parent $objPath
        Ensure-Dir $objDir
        Run-Cmd -exe "nasm" -args @("-f", "elf", "-g", $srcPath, "-o", $objPath)
        $objects += $objPath
    }

    foreach ($objPath in $cObjects.Keys) {
        $srcPath = $cObjects[$objPath]
        $objDir = Split-Path -Parent $objPath
        Ensure-Dir $objDir
        $srcDir = Split-Path -Parent $srcPath
        $incFlags = @("-I$ROOT\kernel", "-I$srcDir")
        $allArgs = @($incFlags, $CFLAGS, "-std=gnu99", "-c", $srcPath, "-o", $objPath)
        Run-Cmd -exe "${TOOL_PREFIX}gcc" -args $allArgs
        $objects += $objPath
    }

    return $objects
}

# ---------------------------------------------------------------------------
# Link kernel
# ---------------------------------------------------------------------------
function Link-Kernel {
    param([string[]]$objects)

    Write-Host "Linking kernel..." -ForegroundColor Green
    Ensure-Dir $BIN_DIR

    $fullObj = Join-Path $BUILD_DIR "kernelfull.o"
    Run-Cmd -exe "${TOOL_PREFIX}ld" -args @("-g", "-relocatable") + $objects + @("-o", $fullObj)

    Run-Cmd -exe "${TOOL_PREFIX}gcc" -args @(
        "-T", "$ROOT\kernel\linker.ld",
        "-o", "$BIN_DIR\kernel.bin",
        "-ffreestanding", "-O0", "-nostdlib",
        $fullObj
    )
}

# ---------------------------------------------------------------------------
# Build disk image
# ---------------------------------------------------------------------------
function Build-DiskImage {
    Write-Host "Building disk image..." -ForegroundColor Green
    Ensure-Dir $BIN_DIR

    $osBin = Join-Path $BIN_DIR "os.bin"

    if (Test-Path $osBin) { Remove-Item $osBin -Force }

    $bootBin = Join-Path $BIN_DIR "boot.bin"
    $kernelBin = Join-Path $BIN_DIR "kernel.bin"

    Copy-Item $bootBin $osBin

    $kernelBytes = [System.IO.File]::ReadAllBytes($kernelBin)
    $stream = [System.IO.File]::OpenWrite($osBin)
    $stream.Seek(0, [System.IO.SeekOrigin]::End)
    $stream.Write($kernelBytes, 0, $kernelBytes.Length)
    $stream.Close()

    $zeros = New-Object byte[] (16 * 1024 * 1024)
    $stream = [System.IO.File]::OpenWrite($osBin)
    $stream.Seek(0, [System.IO.SeekOrigin]::End)
    $stream.Write($zeros, 0, $zeros.Length)
    $stream.Close()

    Write-Host "Disk image created: $osBin" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Build userspace (gshell + lib)
# ---------------------------------------------------------------------------
function Build-Userspace {
    Write-Host "Building userspace components..." -ForegroundColor Green

    Write-Host "  Building usrspc/lib..." -ForegroundColor Green
    Push-Location "$ROOT\usrspc\lib"
    try {
        $libBuildDir = "$ROOT\usrspc\lib\build"
        Ensure-Dir $libBuildDir

        $libAsm = @{
            "$libBuildDir\_start.s.o"  = "$ROOT\usrspc\lib\_start\_start.s"
            "$libBuildDir\_exit.s.o"   = "$ROOT\usrspc\lib\_exit\_exit.s"
            "$libBuildDir\stdio.s.o"   = "$ROOT\usrspc\lib\stdio\stdio.s"
            "$libBuildDir\stdlib.s.o"  = "$ROOT\usrspc\lib\stdlib\stdlib.s"
            "$libBuildDir\unistd.s.o"  = "$ROOT\usrspc\lib\unistd\unistd.s"
        }

        $libC = @{
            "$libBuildDir\stdio.o"     = "$ROOT\usrspc\lib\stdio\stdio.c"
            "$libBuildDir\stdlib.o"    = "$ROOT\usrspc\lib\stdlib\stdlib.c"
            "$libBuildDir\string.o"    = "$ROOT\usrspc\lib\string\string.c"
        }

        $libObjects = @()
        foreach ($objPath in $libAsm.Keys) {
            $srcPath = $libAsm[$objPath]
            Run-Cmd -exe "nasm" -args @("-f", "elf", $srcPath, "-o", $objPath)
            $libObjects += $objPath
        }
        foreach ($objPath in $libC.Keys) {
            $srcPath = $libC[$objPath]
            Run-Cmd -exe "${TOOL_PREFIX}gcc" -args @(
                "-I$ROOT\usrspc\lib\include", $CFLAGS, "-std=gnu99", "-c", $srcPath, "-o", $objPath
            )
            $libObjects += $objPath
        }

        Run-Cmd -exe "${TOOL_PREFIX}ld" -args @(
            "-m", "elf_i386", "-relocatable"
        ) + $libObjects + @("-o", "$ROOT\usrspc\lib\lib.o")
    }
    finally {
        Pop-Location
    }

    Write-Host "  Building usrspc/gshell..." -ForegroundColor Green
    Push-Location "$ROOT\usrspc\gshell"
    try {
        $gshellBuildDir = "$ROOT\usrspc\gshell\build"
        Ensure-Dir $gshellBuildDir

        Run-Cmd -exe "${TOOL_PREFIX}gcc" -args @(
            "-I$ROOT\usrspc\lib\include", "-I.", $CFLAGS, "-std=gnu99",
            "-c", "$ROOT\usrspc\gshell\main.c", "-o", "$gshellBuildDir\main.o"
        )

        Run-Cmd -exe "${TOOL_PREFIX}gcc" -args @(
            "-g", "-T", "$ROOT\usrspc\linker.ld",
            "-o", "$ROOT\usrspc\gshell\main.o",
            "-ffreestanding", "-O0", "-nostdlib", "-fpic", "-g",
            "$gshellBuildDir\main.o", "$ROOT\usrspc\lib\lib.o"
        )
    }
    finally {
        Pop-Location
    }

    Write-Host "Userspace built successfully." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($CleanBuild) { Clean }

Build-Bootloader
$kernelObjects = Build-KernelObjects
Link-Kernel -objects $kernelObjects
Build-DiskImage

if (-not $SkipUserspace) {
    Build-Userspace
}

Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "  Kernel:      bin\kernel.bin" -ForegroundColor Gray
Write-Host "  Disk image:  bin\os.bin" -ForegroundColor Gray
Write-Host "  Bootloader:  bin\boot.bin" -ForegroundColor Gray
Write-Host ""
Write-Host "To run in QEMU:" -ForegroundColor Yellow
Write-Host "  qemu-system-i386 -hda bin\os.bin" -ForegroundColor Gray