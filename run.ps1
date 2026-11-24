<#
.SYNOPSIS
    Run NovaOS in QEMU on Windows

.DESCRIPTION
    Launches the built NovaOS disk image in QEMU emulator.

.PARAMETER Image
    Path to the disk image (default: bin\os.bin)

.PARAMETER Memory
    Memory size in MB (default: 32)
#>

param(
    [string]$Image = "bin\os.bin",
    [int]$Memory = 32
)

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$imagePath = Join-Path $ROOT $Image

if (-not (Test-Path $imagePath)) {
    Write-Host "Disk image not found: $imagePath" -ForegroundColor Red
    Write-Host "Build NovaOS first: .\build.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting NovaOS in QEMU..." -ForegroundColor Green
Write-Host "Image: $imagePath" -ForegroundColor Gray
Write-Host "Memory: $Memory MB" -ForegroundColor Gray
Write-Host "Press Ctrl+Alt or Ctrl+Alt+G to release mouse/keyboard from QEMU" -ForegroundColor Yellow
Write-Host ""

qemu-system-i386 -hda $imagePath -m $Memory