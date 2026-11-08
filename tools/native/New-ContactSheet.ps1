<#
.SYNOPSIS
    Builds a labelled contact sheet from harness frames (evidence\frames\<name>.png) using System.Drawing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Evidence,
    [Parameter(Mandatory = $true)][string] $Output,
    [Parameter(Mandatory = $true)][string[]] $Frames,
    [int] $ThumbWidth = 480,
    [int] $Columns = 3
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$images = foreach ($name in $Frames) { [Drawing.Image]::FromFile((Join-Path $Evidence "frames\$name.png")) }
try {
    $thumbHeight = [int]($images[0].Height * $ThumbWidth / $images[0].Width)
    $rows = [Math]::Ceiling($images.Count / $Columns)
    $sheet = New-Object Drawing.Bitmap ($Columns * $ThumbWidth), ($rows * $thumbHeight)
    $graphics = [Drawing.Graphics]::FromImage($sheet)
    $font = New-Object Drawing.Font 'Consolas', 11
    try {
        $graphics.Clear([Drawing.Color]::FromArgb(40, 40, 40))
        for ($index = 0; $index -lt $images.Count; $index++) {
            $x = ($index % $Columns) * $ThumbWidth
            $y = [Math]::Floor($index / $Columns) * $thumbHeight
            $graphics.DrawImage($images[$index], $x, $y, $ThumbWidth, $thumbHeight)
            $graphics.FillRectangle([Drawing.Brushes]::Black, $x, $y, $ThumbWidth, 20)
            $graphics.DrawString($Frames[$index], $font, [Drawing.Brushes]::Yellow, $x + 4, $y + 2)
        }
        $sheet.Save($Output, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $font.Dispose(); $graphics.Dispose(); $sheet.Dispose() }
}
finally { $images | ForEach-Object { $_.Dispose() } }
