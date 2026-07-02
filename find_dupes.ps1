$css = Get-Content "c:\Users\Oppty\Documents\GitHub\Opptytechhub\CSS\index.css" -Raw
$lines = $css -split "`n"

$selectorMap = @{}   # selector -> list of line numbers
$depth = 0           # current brace depth
$inKeyframes = $false
$inMediaQuery = $false
$keyframeDepth = 0
$mediaDepth = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    $lineNum = $i + 1

    $opens  = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count

    # Detect start of @keyframes block
    if ($trimmed -match '^@keyframes\s') {
        $inKeyframes = $true
        $keyframeDepth = $depth
        $depth += ($opens - $closes)
        continue
    }

    # Detect start of @media block
    if ($trimmed -match '^@media\s') {
        $inMediaQuery = $true
        $mediaDepth = $depth
        $depth += ($opens - $closes)
        continue
    }

    # If we're inside keyframes, track depth and skip
    if ($inKeyframes) {
        $depth += ($opens - $closes)
        if ($depth -le $keyframeDepth) {
            $inKeyframes = $false
        }
        continue
    }

    # If we're inside a media query, track depth and skip
    if ($inMediaQuery) {
        $depth += ($opens - $closes)
        if ($depth -le $mediaDepth) {
            $inMediaQuery = $false
        }
        continue
    }

    # We are at top level (depth == 0) - look for selector lines
    if ($depth -eq 0 -and $opens -gt 0) {
        # Skip at-rules
        if ($trimmed -notmatch '^@') {
            # Extract selector (everything before first {)
            if ($trimmed -match '^([^{]+)\{') {
                $selector = $Matches[1].Trim()
                # Skip empty, comment-only lines
                if ($selector.Length -gt 0 -and $selector -notmatch '^/\*') {
                    if ($selectorMap.ContainsKey($selector)) {
                        $selectorMap[$selector] = $selectorMap[$selector] + $lineNum
                    } else {
                        $selectorMap[$selector] = @($lineNum)
                    }
                }
            }
        }
    }

    $depth += ($opens - $closes)
    if ($depth -lt 0) { $depth = 0 }
}

$dupes = $selectorMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object { $_.Value[0] }
Write-Host "TRUE TOP-LEVEL DUPLICATES: $($dupes.Count)"
foreach ($d in $dupes) {
    Write-Host "  '$($d.Key)' => lines: $($d.Value -join ', ')"
}
