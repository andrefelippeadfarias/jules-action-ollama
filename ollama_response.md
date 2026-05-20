# 🔒 Security Audit Report

## Security Score: **52/100**

The repository demonstrates meaningful security awareness—`action.yaml` uses safe patterns (environment variables for Python, `--body-file` for PRs, proper title sanitization, `auto_commit` defaulting to `false`). However, critical vulnerabilities remain in standalone scripts and example workflows that undermine the overall security posture.

---

## Findings

### 🔴 CRITICAL

#### 1. Python Code Injection in `invoke-ollama.sh`

**File:** `scripts/invoke-ollama.sh` (lines ~70-85)

Shell variables are interpolated directly into a Python code string inside `python3 -c`:

```python
payload = {
    'model': '$MODEL',              # ← shell-expanded into Python source
    'prompt': prompt,
    'stream': False,
    'options': {
        'temperature': $TEMPERATURE,  # ← bare Python expression
        'num_predict': $MAX_TOKENS     # ← bare Python expression
    }
}
```

An attacker controlling `--model`, `--temperature`, or `--max-tokens` can inject arbitrary Python code:

```bash
# Model name breaks out of string literal:
./invoke-ollama.sh --model "'; import os; os.system('id'); '"

# Temperature executes as bare Python expression:
./invoke-ollama.sh --temperature "__import__('os').system('id')"
```

The same pattern affects `$CONTEXT_FILE`, `$RESPONSE_FILE`, and `$OUTPUT_FILE` in the response-parsing Python block.

**Contrast with `action.yaml`**, which correctly uses `os.environ.get()` to avoid interpolation entirely.

**Impact:** Arbitrary code execution on the runner when script arguments are attacker-controlled.

---

#### 2. Prompt Injection via Unsanitized GitHub Actions Expressions

**Files:** `examples/bug-fixer.yml`, `examples/ci-failure-fix.yml`

```yaml
# bug-fixer.yml
prompt: |
  Please diagnose and