# Deployment & Packaging Documentation

The SYNC-AI-FULL-STACK-APP-BUILDER targets modern Windows environments using the Windows App SDK (WinUI 3). 

## MSIX Packaging

All generated applications and the Builder itself are packaged using the **MSIX** format.

### Benefits of MSIX:
- **Clean Installation**: Guaranteed uninstall without registry rot.
- **Updates**: Built-in support for differential updates via `.appinstaller` files.
- **Resource Management**: Efficient disk usage via block-level deduplication.
- **Security**: Mandatory code signing ensures integrity.

## Deployment Strategy

### Local Desktop App (V1)
1. **Building**: Execute `Publish` target via Embedded MSBuild (Release configuration).
2. **Packaging**: Generate MSIX package using Windows Application Packaging Project APIs.
3. **Distribution**: Direct sideloading or Windows Store.

### Requirements
- **Target OS**: Windows 10 Version 1809 (10.0; Build 17763) or later.
- **Dependencies**: Windows App Runtime (automatically installed with MSIX).

## Codesigning
All packages must be signed with a valid Authenticode certificate. For local development, a self-signed certificate can be used.

### Commands
```powershell
# Sign the package
SignTool sign /f MyCert.pfx /p Password /fd SHA256 /t http://timestamp.digicert.com MyApp.msix
```
