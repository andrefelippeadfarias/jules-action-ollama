# test-security-ollama.ps1 — Security scan using local Ollama
# This script is called by the GitHub Actions workflow

$ErrorActionPreference = "Stop"

Write-Output "=== Step 1: Check Ollama ==="
try {
    $resp = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10
    Write-Output "Ollama running. Models: $($resp.models.name -join ', ')"
} catch {
    Write-Output "ERROR: Ollama not running on localhost:11434"
    Write-Output $_.Exception.Message
    exit 1
}

Write-Output ""
Write-Output "=== Step 2: Collect Context ==="
$promptLines = @()
$promptLines += "You are a security agent. Analyze this repository for vulnerabilities."
$promptLines += ""
$promptLines += "Check for:"
$promptLines += "1. Hardcoded secrets, API keys, passwords"
$promptLines += "2. SQL injection, XSS, CSRF"
$promptLines += "3. Missing authentication"
$promptLines += "4. Insecure configurations"
$promptLines += "5. Dependency vulnerabilities"
$promptLines += ""
$promptLines += "Generate a security score (0-100) and list all findings."
$promptLines += ""
$promptLines += "## Repository Structure"

$files = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*node_modules*" } | Select-Object -First 50
foreach ($f in $files) {
    $promptLines += $f.FullName.Replace($PWD.Path, ".")
}

$promptLines += ""
$promptLines += "## Source Code"

$sourceFiles = Get-ChildItem -Recurse -File | Where-Object { $_.Extension -match "\.(yaml|yml|md|sh|ps1|json)$" -and $_.FullName -notlike "*\.git\*" } | Select-Object -First 20
foreach ($f in $sourceFiles) {
    $relPath = $f.FullName.Replace($PWD.Path, ".")
    $promptLines += ""
    $promptLines += "### $relPath"
    $promptLines += "```"
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) { $promptLines += $content }
    $promptLines += "```"
}

$prompt = $promptLines -join "`n"
$prompt | Out-File -FilePath "prompt.txt" -Encoding UTF8
Write-Output "Prompt created: $(($promptLines | Measure-Object).Count) lines"

Write-Output ""
Write-Output "=== Step 3: Invoke Ollama ==="
$body = @{
    model = "glm-5.1:cloud"
    prompt = $prompt
    stream = $false
    options = @{
        temperature = 0.3
        num_predict = 2048
    }
} | ConvertTo-Json -Depth 5

Write-Output "Calling Ollama (this may take 1-3 minutes)..."
$resp = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600

$resp.response | Out-File -FilePath "ollama_response.md" -Encoding UTF8
Write-Output "Response received! Tokens: $($resp.eval_count)"

Write-Output ""
Write-Output "=== SECURITY SCAN RESULTS ==="
Get-Content ollama_response.md