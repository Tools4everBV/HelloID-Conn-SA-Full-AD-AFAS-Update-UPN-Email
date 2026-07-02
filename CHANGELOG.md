# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-03-10

### Added

- Added Active Directory uniqueness validation for UPN and email, including checks against `ProxyAddresses`.
- Added delegated form options to independently update Email and/or User Principal Name.
- Added AFAS User update logic (`KnUser`) for `EmAd` and `Upn`.

### Changed

- Changed AD lookup filtering:
  - Search by `Name`, `DisplayName`, `UserPrincipalName`, and `mail`
  - Use semicolon-separated OU values in `ADusersSearchOU`
- Changed delegated form task to use `$form.gridUsers` object values directly and update AD by `ObjectGuid`.
- Changed AFAS update flow to:
  - Update AFAS Employee (`KnEmployee`) for `EmAd`
  - Update AFAS User (`KnUser`) for `EmAd` and `Upn`
- Changed AD email update behavior to normalize and replace primary `SMTP:` proxy address.
- Updated datasource naming to the current standardized pattern.
- Updated README to align with current connector behavior and setup requirements.

### Removed

- Removed legacy assumptions for single-field update behavior by introducing toggle-based updates for UPN and Email.

## [1.0.0] - 02-10-2023

Initial release