
# Point to a path with images that have been resized - I used ImageMagick
$ipath = "D:\it\pictures\ad photos\output\optimized"

$images = gci -Path $ipath

$jpgBytes = $null

foreach ($image in $images) {
    $jpgBytes = $null

    $jpgBytes = [byte[]]$jpg = Get-Content ($image.fullName) -encoding byte

    set-aduser -id $image.BaseName -replace @{thumbnailPhoto = $jpgBytes}
}