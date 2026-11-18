# Package the approved symbol for each platform without redesigning the artwork.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$app = Split-Path -Parent $PSScriptRoot
$symbol = [Drawing.Bitmap]::new((Join-Path $app 'assets/logos/attendance-symbol.png'))
$colorFile = Join-Path $app 'android/app/src/main/res/values/ic_launcher_background.xml'
$tileHex = (Select-Xml -LiteralPath $colorFile -XPath '/resources/color[@name="ic_launcher_background"]').Node.InnerText
$tileColor = [Drawing.ColorTranslator]::FromHtml($tileHex)
$brush = [Drawing.SolidBrush]::new($tileColor)

try {
  $left = $symbol.Width
  $top = $symbol.Height
  $right = -1
  $bottom = -1
  for ($y = 0; $y -lt $symbol.Height; $y += 4) {
    for ($x = 0; $x -lt $symbol.Width; $x += 4) {
      if ($symbol.GetPixel($x, $y).A -lt 64) { continue }
      $left = [Math]::Min($left, $x)
      $right = [Math]::Max($right, $x)
      $top = [Math]::Min($top, $y)
      $bottom = [Math]::Max($bottom, $y)
    }
  }
  if ($right -lt $left) { throw 'The Attendance symbol is empty.' }
  $left = [Math]::Max(0, $left - 4)
  $right = [Math]::Min($symbol.Width - 1, $right + 4)
  $top = [Math]::Max(0, $top - 4)
  $bottom = [Math]::Min($symbol.Height - 1, $bottom + 4)
  $source = [Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)
  if ($source.Width -eq $symbol.Width -and $source.Height -eq $symbol.Height) {
    throw 'Use the transparent symbol, not the opaque launcher tile.'
  }

  function Export-Icon {
    param([string]$File, [int]$Canvas, [int]$Mark, [string]$Tile = 'square', [int]$TileSize = $Canvas)
    $format = if ($Tile -eq 'square') {
      [Drawing.Imaging.PixelFormat]::Format24bppRgb
    } else {
      [Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    $bitmap = [Drawing.Bitmap]::new($Canvas, $Canvas, $format)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.Clear([Drawing.Color]::Transparent)
      if ($Tile -eq 'square') {
        $graphics.Clear($tileColor)
      } elseif ($Tile -eq 'circle') {
        $graphics.FillEllipse($brush, 0, 0, $Canvas, $Canvas)
      } elseif ($Tile -eq 'rounded') {
        $start = [single](($Canvas - $TileSize) / 2)
        $end = [single]($start + $TileSize)
        $arc = [single]($TileSize * .44)
        $path = [Drawing.Drawing2D.GraphicsPath]::new()
        try {
          $path.AddArc($start, $start, $arc, $arc, 180, 90)
          $path.AddArc($end - $arc, $start, $arc, $arc, 270, 90)
          $path.AddArc($end - $arc, $end - $arc, $arc, $arc, 0, 90)
          $path.AddArc($start, $end - $arc, $arc, $arc, 90, 90)
          $path.CloseFigure()
          $graphics.FillPath($brush, $path)
        } finally {
          $path.Dispose()
        }
      }
      $scale = $Mark / [Math]::Max($source.Width, $source.Height)
      $width = [int][Math]::Round($source.Width * $scale)
      $height = [int][Math]::Round($source.Height * $scale)
      $destination = [Drawing.Rectangle]::new(
        [int](($Canvas - $width) / 2), [int](($Canvas - $height) / 2), $width, $height
      )
      $graphics.DrawImage($symbol, $destination, $source, [Drawing.GraphicsUnit]::Pixel)
      $bitmap.Save((Join-Path $app $File), [Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  }

  Export-Icon 'assets/logos/attendance-app-icon.png' 1024 740
  Export-Icon 'assets/splash/splash.png' 400 278 'rounded' 384
  Export-Icon 'assets/splash/android-12.png' 960 278 'rounded' 384

  $densities = @{ ldpi = @(36, 81); mdpi = @(48, 108); hdpi = @(72, 162); xhdpi = @(96, 216); xxhdpi = @(144, 324); xxxhdpi = @(192, 432) }
  foreach ($density in $densities.Keys) {
    $legacy, $adaptive = $densities[$density]
    $folder = "android/app/src/main/res/mipmap-$density"
    Export-Icon "$folder/ic_launcher.png" $legacy ([int]($legacy * .72))
    Export-Icon "$folder/ic_launcher_round.png" $legacy ([int]($legacy * .67)) 'circle'
    Export-Icon "$folder/ic_launcher_foreground.png" $adaptive ([int]($adaptive * 50 / 108)) 'transparent'
  }

  $ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
  $catalog = Get-Content (Join-Path $app "$ios/Contents.json") -Raw | ConvertFrom-Json
  foreach ($entry in ($catalog.images | Sort-Object filename -Unique)) {
    $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
    $pixels = [int]($points * [int]$entry.scale.TrimEnd('x'))
    Export-Icon "$ios/$($entry.filename)" $pixels ([int]($pixels * .72))
  }
} finally {
  $brush.Dispose()
  $symbol.Dispose()
}
