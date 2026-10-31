# Cursor Extension Security Check

Unchanged copies of Cursor’s official macOS and Windows remediation scripts, provided here for convenient download. This is an independent mirror, not an official Cursor repository.

## Who is this for?

Developers who installed the malicious Claude Code extension distributed through Cursor’s marketplace on 29 October 2026. Cursor identifies package versions **2.1.312 and 2.1.313**.

If you have never used Cursor IDE, this notice does not apply to you. Using Claude in a browser, Claude Desktop, the standalone Claude Code CLI or the official extension in VS Code alone does not put you in scope.

## Download

Select **Code → Download ZIP** on this repository and extract it. Both scripts are included. No separate download from Cursor is needed.

**These scripts check and remediate in the same run. They can remove files, SSH keys, persistence entries and processes. They are not read only checks.** If compromise is suspected, contact your security team before cleanup so evidence can be preserved.

Close all code editors before running the script for your operating system.

## macOS

Open Terminal in the extracted folder and run as the affected user, **without sudo**:

```bash
bash remediate-macos.sh
```

Run once for each affected user account.

## Windows

Open PowerShell using **Run as Administrator**. Navigate to the extracted folder, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\remediate-windows.ps1
```

The Windows script processes local user profiles.

## Understand the result

| Output | Meaning |
| :--- | :--- |
| `clean: no backdoor found` | The script did not find matching artifacts to remove. This does not prove the machine was never compromised. |
| `done: backdoor removed` | The script removed matching artifacts. Contact your security team immediately to assess the impact. |
| `incomplete: see errors above` or `incomplete: see warnings above` | Cleanup reported a failure. Share the output privately with your security team. |

If any indicators or compromise are identified, **contact your own security team immediately** to assess the impact and coordinate remediation. Credential rotation, session revocation and rebuilding may also be necessary. Do not post credentials, logs or device details in public GitHub issues.

## Source and attribution

Scripts copied unchanged from Cursor on **31 October 2026**. This mirror is a snapshot and does not update automatically.

Official notice: [Cursor security notice](https://cursor.com/blog/claude-code-extension-security-notice).

Original sources:

* [macOS script](https://cursor.com/static/security/claude-code-extension/remediate-macos.sh)
* [Windows script](https://cursor.com/static/security/claude-code-extension/remediate-windows.ps1)

SHA256 checksums of the mirrored files:

```text
c15900de25dd12d92adca3fa75b40253ae11edc96e70fbef0fd44252b292443a  remediate-macos.sh
4189b85194cadee9f3624493ec126b76a69f64b15c515bec7d2dd3d30bca4e7b  remediate-windows.ps1
```

## License

The MIT license in this repository applies to the repository author’s original documentation only. The two remediation scripts are third party material authored and published by Cursor; this repository does not claim ownership of them or grant an MIT license for them. No explicit license notice was present in the downloaded scripts.
