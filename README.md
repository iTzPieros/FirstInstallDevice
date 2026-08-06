### 🔎 Device First Installation Report

Run the PowerShell script directly via **CMD** or **PowerShell** with elevated privileges to generate a report containing the **first installation date** of devices detected by Windows.

The script analyzes the Windows Registry and Plug & Play information to collect installation timestamps and hardware details for connected devices.

---

### ⚙️ How to Run

1. Open **Command Prompt (CMD)** or **PowerShell** as **Administrator**.
2. Copy and execute the following command:

```cmd
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/iTzPieros/FirstInstallDevice/refs/heads/main/Check.ps1)
```
