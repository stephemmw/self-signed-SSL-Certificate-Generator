# Define paths
$CertDir = "C:\path\to\your\certificate"
$KeyPath = Join-Path $CertDir "private.key"
$CertPath = Join-Path $CertDir "server.crt"
$ConfigPath = "C:\path\to\your\openssl.cnf"
$PassphraseFile = Join-Path $CertDir "passphrase.txt"

# Function to run OpenSSL commands
function Invoke-OpenSSL {
    param (
        [string]$Arguments
    )
    $openSSLPath = "openssl"  # Assumes OpenSSL is in PATH, adjust if necessary
    $process = Start-Process -FilePath $openSSLPath -ArgumentList $Arguments -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        throw "OpenSSL command failed with exit code $($process.ExitCode)"
    }
}

# Function to generate a random passphrase
function Get-RandomPassphrase {
    $length = 32
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?'
    return -join ((1..$length) | ForEach-Object { $characters | Get-Random })
}

# Check if the certificate directory exists, if not create it
if (-not (Test-Path $CertDir)) {
    Write-Host "Creating certificate directory: $CertDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $CertDir | Out-Null
}

# Check if the configuration file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

try {
    # Generate and save the passphrase
    $passphrase = Get-RandomPassphrase
    $passphrase | Out-File -FilePath $PassphraseFile -NoNewline
    Write-Host "Generated passphrase and saved to: $PassphraseFile" -ForegroundColor Green

    # Generate the private key without password
    Write-Host "Generating private key..."
    Invoke-OpenSSL "genpkey -algorithm RSA -out `"$KeyPath`""

    # Encrypt the private key with passphrase
    Write-Host "Encrypting private key..."
    Invoke-OpenSSL "pkcs8 -topk8 -in `"$KeyPath`" -out `"$KeyPath.enc`" -passout file:`"$PassphraseFile`""

    # Replace the unencrypted key with the encrypted one
    Move-Item -Path "$KeyPath.enc" -Destination $KeyPath -Force

    # Generate the self-signed certificate
    Write-Host "Generating self-signed certificate..."
    Invoke-OpenSSL "req -new -x509 -key `"$KeyPath`" -out `"$CertPath`" -config `"$ConfigPath`" -extensions req_ext -passin file:`"$PassphraseFile`""

    Write-Host "Private key and certificate have been generated successfully." -ForegroundColor Green
    Write-Host "Private key: $KeyPath"
    Write-Host "Certificate: $CertPath"
    Write-Host "Passphrase file: $PassphraseFile"
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    exit 1
}
