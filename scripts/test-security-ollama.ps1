# test-security-ollama.ps1 — Security scan using local Ollama
# SECURITY: Uses proper JSON serialization, excludes sensitive files, cleans up artifacts
$ErrorActionPreference = "Stop"

Write-Output "=== Step 1: Check Ollama ==="
try {
    $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10
    Write-Output "Ollama running. Models: $($resp.models.name -join ', ')"
} catch {
    Write-Output "ERROR: Ollama not running on localhost:11434"
    exit 1
}

Write-Output ""
Write-Output "=== Step 2: Collect Context ==="
$codeBlock = [string][char]96 + [string][char]96 + [string][char]96

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("You are a security agent. Analyze this repository for vulnerabilities.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Check for:")
[void]$sb.AppendLine("1. Hardcoded secrets, API keys, passwords")
[void]$sb.AppendLine("2. SQL injection, XSS, CSRF")
[void]$sb.AppendLine("3. Missing authentication")
[void]$sb.AppendLine("4. Insecure configurations")
[void]$sb.AppendLine("5. Dependency vulnerabilities")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generate a security score (0-100) and list all findings.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Repository Structure")

# SECURITY: Exclude sensitive files
$files = Get-ChildItem -Recurse -File | Where-Object {
    $_.FullName -notlike "*\.git\*" -and
    $_.FullName -notlike "*node_modules*" -and
    $_.Name -ne ".env" -and
    $_.Name -notlike ".env.*" -and
    $_.Extension -ne ".key" -and
    $_.Extension -ne ".pem" -and
    $_.Extension -ne ".p12" -and
    $_.Name -notlike "*secret*" -and
    $_.Name -notlike "*credential*" -and
    $_.Name -notlike "*token*" -and
    $_.Name -notlike "*password*"
} | Select-Object -First 50

foreach ($f in $files) {
    [void]$sb.AppendLine($f.FullName.Replace($PWD.Path, "."))
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Source Code")

# SECURITY: Exclude sensitive files from source code inclusion
$sourceFiles = Get-ChildItem -Recurse -File | Where-Object {
    $_.Extension -match "\.(yaml|yml|md|sh|ps1|json)$" -and
    $_.FullName -notlike "*\.git\*" -and
    $_.Name -ne ".env" -and
    $_.Name -notlike ".env.*" -and
    $_.Extension -ne ".key" -and
    $_.Extension -ne ".pem" -and
    $_.Name -notlike "*secret*" -and
    $_.Name -notlike "*credential*"
} | Select-Object -First 20

foreach ($f in $sourceFiles) {
    $relPath = $f.FullName.Replace($PWD.Path, ".")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("### $relPath")
    [void]$sb.AppendLine($codeBlock)
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) { [void]$sb.AppendLine($content) }
    [void]$sb.AppendLine($codeBlock)
}

$prompt = $sb.ToString()
[System.IO.File]::WriteAllText("$PWD\prompt.txt", $prompt, [System.Text.Encoding]::UTF8)
Write-Output "Prompt created: $($prompt.Length) chars"

Write-Output ""
Write-Output "=== Step 3: Invoke Ollama ==="
# SECURITY: Use proper JSON serialization instead of string interpolation
$promptJson = $prompt | ConvertTo-Json -Depth 1 -Compress
$jsonBody = '{"model":"glm-5.1:cloud","prompt":' + $promptJson + ',"stream":false,"options":{"temperature":0.3,"num_predict":8192}}'
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

Write-Output "Calling Ollama (1-3 min)... [$($bodyBytes.Length) bytes]"

# Save raw response to file for proper parsing
$tempFile = "$env:TEMP\ollama_result.json"
$null = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyBytes -TimeoutSec 600 -OutFile $tempFile

# Parse response - handle both 'response' and 'thinking' fields (GLM mode)
$rawJson = [System.IO.File]::ReadAllText($tempFile, [System.Text.Encoding]::UTF8)
$result = $rawJson | ConvertFrom-Json

$output = ""
if ($result.response -and $result.response.Trim().Length -gt 0) {
    $output = $result.response
} elseif ($result.thinking -and $result.thinking.Trim().Length -gt 0) {
    $output = $result.thinking
} else {
    $output = $rawJson
}

[System.IO.File]::WriteAllText("$PWD\ollama_response.md", $output, [System.Text.Encoding]::UTF8)
Write-Output "Response received! Tokens: $($result.eval_count), Length: $($output.Length) chars"

# SECURITY: Clean up temporary files
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Remove-Item "$PWD\prompt.txt" -Force -ErrorAction SilentlyContinue
Write-Output "Cleaned up temporary files"

Write-Output ""
Write-Output "=== SECURITY SCAN RESULTS ==="
Get-Content ollama_response.md