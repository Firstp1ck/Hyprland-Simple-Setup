# Bootable installer ISO implementation plan

Status: planned, not implemented.

Planning date: 2026-09-19.

Decision record: [completed Grill Me interview](bootable-installer-iso-grill.md), 40 answers across four questionnaire rounds.

## 1. Goal and completion boundary

Produce a downloadable, bootable USB installer for Hyprland Simple Setup. Booting the ISO opens a guided terminal installer automatically. The installer installs vanilla Arch Linux and this project's configured Hyprland desktop onto a selected disk, including a fully offline default installation.

The ISO is an additional distribution artifact. It does not replace the existing AUR package or the existing setup-on-installed-Arch workflow.

This document is the requested planning deliverable. It does not authorize disk operations, implementation, package publication, infrastructure purchases, or releases. Keep both planning documents under `plans/planned/` until implementation and its acceptance gates are complete; then archive them under the already ignored `plans/archive/` directory.

### What a successful v1 does

1. A newcomer downloads and verifies the ISO, writes it to USB, and boots a UEFI x86_64 computer with Secure Boot disabled.
2. An English/German terminal wizard opens without requiring a graphical session or an internet connection.
3. The user chooses localization, an account, a disk operation, and optional encryption. The installer displays the exact storage changes before requesting destructive-action confirmation.
4. The default Arch/Hyprland system installs entirely from the USB. Optional online applications can be selected inside the installer when internet is available.
5. Rebooting without the USB reaches the installed login screen and then a working, configured Hyprland session.
6. On supported coexistence layouts, the installed GRUB menu includes the preserved Windows/Linux EFI boot targets.
7. The USB can also enter guided snapshot recovery and boot repair without starting an installation.
8. Existing AUR users retain their current command, choices, and configuration-preservation behavior.

### Explicit non-goals

- A live Hyprland demo desktop or persistent portable USB workstation.
- ARM64, legacy BIOS, Secure Boot enablement, partition resizing, or arbitrary partition editing.
- Repairing unknown/broken foreign bootloaders as part of installation.
- A guarantee for every NVIDIA generation, every VM product, or untested physical hardware.
- Hibernation, TPM auto-unlock, unattended destructive installation, or automatic login to the installed desktop.
- Bootable snapshot menu entries. Recovery from the ISO is the required path.
- An Omarchy fork, a new independent Linux distribution package ecosystem, or a custom distro-wide update service.
- Changing the default application choices for the existing AUR setup path.

## 2. Agreed product contract

| Area | Decision |
|---|---|
| Base | Vanilla Arch Linux, x86_64, UEFI, Secure Boot disabled |
| USB startup | Automatically launch the guided Rust TUI, not a live desktop |
| Audience | Newcomer-oriented public release, with explicit support limits |
| Languages | English and German UI; selectable keyboard, timezone, system locale |
| Disk modes | Erase one selected disk, or use existing unallocated space; never resize |
| Coexistence | Intact, discoverable Windows/Linux EFI loaders on GPT/UEFI layouts; unified boot menu |
| Filesystem | Btrfs with system snapshots and guided ISO recovery |
| Encryption | Optional LUKS2, off by default |
| Base connectivity | Default installation and first desktop session work offline |
| Optional applications | Select inside the installer when online; failure offers explicit Retry or Skip |
| Coding agents | Not bundled or required; available later through existing optional tooling |
| Existing users | Preserve AUR distribution, command, package choices, and user configuration |
| Updates | Normal Arch/AUR updates; explicit non-destructive setup/configuration updates |
| Required VM | QEMU/KVM, UEFI, with a genuinely working installed graphical session |
| Other systems | Physical GPUs, VirtualBox/VMware, and actual Windows/BitLocker boot initially unverified |
| Build infrastructure | GitHub-hosted runners initially; prove feasibility before scaling implementation |
| Publication | Stable tags automatically publish after automated gates pass |
| Distribution | Split GitHub Release assets when needed, plus a full ISO on S3-compatible HTTPS storage |
| Mirror failure | Verified GitHub assets may publish; mirror status must remain accurate |
| Verification | SHA-256 checksums only for v1 release artifacts |
| Size | No product size cap; measure the real image and enforce hosting constraints |

A stable version label must not be described as physical-hardware certification. The release page, installer, support matrix, and download guide must use the same support vocabulary: targeted, tested, or unverified.

## 3. Verified starting point

These observations come from the working tree and external references inspected during planning. Recheck them against the implementation baseline; concurrent project work can move line numbers or change interfaces.

| Existing file or source | What it establishes | Planning consequence |
|---|---|---|
| `Cargo.toml` | Rust application using Ratatui/Crossterm, serde, and serde_json | Extend the current TUI; do not add a graphical installer dependency |
| `src/main.rs` | Existing TUI orchestrates `setup.sh` and reads the package registry | Keep existing mode intact; introduce explicit ISO/recovery routes |
| `src/packages.rs`, `packages.json` | Package sources, role options, defaults, and required dependencies | Reuse the registry; add an explicit ISO selection profile rather than a second application catalog |
| `install.sh` | Clones/updates a repository and launches the installed TUI or `setup.sh` | Do not run this internet bootstrap during ISO installation |
| `setup.sh` | Mixes package updates, AUR builds, online assets, user configuration, services, and snapshots | Separate target-root provisioning from existing-system orchestration |
| `scripts/lib/setup-reliability.sh` | Existing reliability/state helpers | Reuse only after checking their assumptions about live root, HOME, sudo, and rollback |
| `scripts/lib/agent-installers.sh` | Remote coding-agent installation support | Keep out of the offline base path |
| `dotfiles/`, `system_files/`, `Wallpaper/` | Existing configuration and visual assets | Package repository-owned files; audit downloads, licenses, private data, and generated state |
| `tests/run.sh`, `tests/shell/`, `.github/workflows/ci.yml` | Existing Rust, JSON, shell, and guarded scenario checks | Preserve them and add ISO-specific tests separately |
| `.github/workflows/release.yml` | Existing release workflow publishes source-only releases from tags/release events | Add gated artifact publication without competing or recursive release jobs |
| AUR RPC for `hyprland-simple-setup-git` | Existing package is maintained and builds from this repository | Preserve its packaging contract; its PKGBUILD was not found in this working tree |
| Local ArchWiki `Archiso.html` | Custom profiles, local package repositories, and QEMU testing are supported | Use archiso rather than inventing image construction |
| Omarchy ISO README | Bundled package mirror, base installation, target setup, and user setup are distinct steps | Borrow that separation and offline delivery, not its full product policy |

### Important evidence limitations

- No ISO configuration was found in the inspected repository. The native explorer's expanded run failed on a stale indexed plan path; targeted reads supplied the necessary facts.
- Current `setup.sh` is not a bare-metal OS installer. Passing a new root path to it would not make all its commands target-safe.
- Upstream archinstall exposes `--offline` as disabling online services such as package lookups and keyring auto-update. That flag does not supply package files, their dependencies, or prove offline installation.
- Herdr is an AUR binary package in the current registry. Observed AUR metadata names `AGPL-3.0-or-later`, while current upstream LICENSE metadata identifies `Apache-2.0`. The exact bundled release's license and source obligations must be established independently.
- No build, installation, recovery, desktop, or firmware test was executed for this plan.

## 4. Architecture

Use one repository and one shared application/configuration model, with separate execution paths:

```text
Existing AUR/setup command
    -> existing-system mode
    -> existing choices and preservation behavior

Versioned source + ISO profile + dependency lock
    -> isolated Arch build environment
    -> prebuilt packages + configuration/assets
    -> archiso image

USB boot
    -> ISO-mode Rust wizard
    -> validated installation plan + explicit confirmation
    -> pinned archinstall adapter
    -> target-system provisioning
    -> target-user provisioning
    -> optional online application phase
    -> validation and reboot instructions

USB recovery entry
    -> target/snapshot selection + explicit confirmation
    -> system snapshot restore
    -> matching boot-artifact repair
    -> validation
```

### Ownership boundaries

1. **Package/configuration model:** `packages.json` remains authoritative for available roles and dependencies. A small ISO profile selects role values and identifies the system-only additions. A generated lock records the exact resolved package closure. Do not hand-maintain a duplicate application list inside the image profile.
2. **Wizard:** collects choices, performs read-only discovery, renders the storage preview, gathers local secrets securely, and displays structured progress. Existing-system mode never gains disk-erasure behavior by default.
3. **Storage executor:** accepts a versioned, validated installation plan. It invokes the pinned archinstall adapter and narrowly scoped target actions, not arbitrary command strings from the UI.
4. **System provisioning:** writes to an explicit mounted target root; configures fstab, initramfs, bootloader, networking, locale, users, and services without acting on the live build host.
5. **User provisioning:** deploys configuration to the explicitly selected target UID/GID and home. It must not inherit the builder's or live root user's HOME.
6. **Recovery:** owns snapshot validation, restoration, and boot repair. It shares target discovery and safety checks but does not reuse destructive installation transitions.
7. **Release orchestration:** publishes already tested bytes. It must not rebuild an image between validation, splitting, and mirror upload.

The local console installer can hold root privileges for installation. Treat this as a privileged application: validate every destructive operation independently of UI state, avoid shell interpolation, reject unknown serialized fields where appropriate, and do not expose a network control service. Hyprland itself must only run as the installed non-root user.

### Proposed files

These are implementation targets, not files created by this planning task.

| Proposed area | Responsibility |
|---|---|
| `iso/profile/` | archiso profile, UEFI boot entries, live services, immutable installer payload |
| `iso/profiles/default.json` | Chosen role overrides and ISO-only package policy |
| `iso/locks/` | Versioned build input and dependency manifests, with no binary payloads |
| `src/iso/` | Wizard state, validation, storage discovery, confirmation, progress, recovery UI |
| `src/i18n/` | English/German message catalogs and consistency tests |
| `scripts/iso/` | Build preparation, closure generation, VM tests, splitting, verification, publication helpers |
| `scripts/iso/archinstall/` | Version-specific adapter and input-schema fixtures |
| `scripts/lib/target-*.sh` or equivalent cohesive modules | Shared target-root/user configuration actions with explicit interfaces |
| `tests/iso/` | Unit/contract tests, disk fixtures, VM installation and recovery scenarios |
| `docs/iso/` | Download/flash guide, support matrix, installation, recovery, maintenance and release runbook |
| `.github/workflows/iso-*.yml` | Untrusted validation, trusted build/test, gated release publication |

Keep heavy ISO images, package archives, virtual disks, temporary mount roots, and local run logs out of Git. Add scoped ignore rules when implementation starts. Do not ignore `plans/planned/`.

## 5. Offline image and package delivery

### Default application profile

| Role | ISO default |
|---|---|
| Browser | Firefox |
| Shell | Fish |
| Terminal | Kitty |
| Multiplexer | Herdr, using an audited pinned package |
| Terminal editor | Neovim |
| GUI editor | Kate |
| Bar | Waybar |
| Notifications | SwayNC |
| Launcher | Wofi |
| Calendar | Merkuro |
| Bluetooth UI | Bluedevil |
| Network UI | plasma-nm |
| Audio UI | pavucontrol-qt |
| Dock | None |
| Coding agents | None |

Retain the project's Hyprland appearance, wallpaper selection, keybindings, role-aware launchers, and useful desktop tooling. Resolve all their transitive runtime requirements; a visible menu entry pointing to a missing command is a profile bug.

### Build contract

- Pin the source commit, Arch repository snapshot or otherwise retained consistent package set, archiso version, archinstall version, build environment, Rust toolchain, AUR recipe revisions, and downloaded asset revisions.
- Use a clean Arch build environment. Build AUR-derived packages as an unprivileged user in an isolated build root, never as root and never inside the installing user's live session.
- Resolve the full target package closure, including kernel, headers when needed, firmware, microcode variants, GPU candidates, initramfs tools, bootloader, networking, account setup, recovery tools, fonts, portals, audio, and graphical runtime dependencies.
- Separate live-installer requirements from installed-system requirements. Make the generated archiso package list and bundled target repository derive from the same resolved inputs.
- Bundle the selected setup binary, scripts, dotfiles, assets, translations, licenses, source notices, package databases, package files, and relevant upstream package signatures.
- Configure the bundled repository explicitly in both the live installer and target package-installation context. archiso's build-time `pacman.conf` alone does not configure those environments.
- Preserve Arch package signature checking. For project-built/AUR artifacts, record the exact source, recipe, hash, and reviewed trust policy. Checksums-only ISO publication must not become global `TrustAll` package handling.
- Audit all existing network actions. Examples include bootstrap Git operations, AUR helper construction, shell plugin/setup downloads, and the SDDM theme fetch. Replace offline-path downloads with packaged assets or ordinary packages.
- Verify Herdr can launch its intended local workflows without requiring an installed coding agent or network authentication. A packaging/license failure blocks the chosen profile; substitution requires a new decision.
- A repeatable, recorded build is required. Do not claim bit-for-bit reproducibility until two independent clean builds demonstrate it.

### Offline proof

Remove the VM NIC before installation. Install the base system, reboot it, log in, launch the desktop and the selected local applications, and exercise the initial recovery path. Instrument the build/test logs so a hidden network fallback cannot masquerade as offline success.

## 6. Installer and onboarding flow

1. Boot into the text installer. Offer Install, Recover, Help, and Exit; never begin disk writes merely because USB boot occurred.
2. Select English or German, then keyboard layout with a typing test. Keep recovery prompts and error paths localized too.
3. Explain the selected support policy and check x86_64, UEFI, Secure Boot state, usable RAM, boot-medium readability, and available target storage.
4. Offer networking as optional. A missing connection must not prevent the default path. Never enable SSH or remote access by default.
5. Discover disks, their model/serial/size, mounted filesystems, partitions, existing EFI targets, and free extents. Exclude the entire boot-medium device, including related partitions or mapped layers.
6. Select erase-disk or unallocated-space mode. Collect encryption choice, hostname, timezone, system locale, username, and local passwords. Do not embed defaults containing credentials in the ISO.
7. Show application defaults and optional online choices. Agents are excluded from this install-time selection and remain a later action.
8. Present the exact partition/format/mount/EFI/boot-order plan, preserved objects, selected applications, and warnings. Require an affirmative typed confirmation tied to the selected disk's displayed identity.
9. Execute the offline base and target configuration. Display bounded phase progress with detailed logs available separately.
10. Validate a bootable base before online extras. If online work fails, show Retry or Skip. Apply role overrides only for successfully installed applications; retain working offline defaults otherwise.
11. Show a truthful completion summary, recovery instructions, support limitations, and reboot action. Prompt the user to remove the USB. Never reboot after a hard base-system failure.
12. First installed boot uses SDDM and normal user login. Open a local getting-started guide with keybindings, networking, updates, recovery, and optional agent setup. Missing optional internet features must not flood startup diagnostics with false failures.

### Localization and accessibility checks

Externalize strings rather than duplicating workflow logic. Test keyboard-only navigation, narrow terminals, long German labels, error wrapping, progress visibility, password masking, locale generation, and selected layout continuity at encrypted boot/login. Do not silently retain the existing Swiss-German Fish default in the ISO path.

## 7. Storage, coexistence, and encryption safety

### Hard invariants

- Discovery and preview are read-only. Writes require explicit confirmation of an immutable plan.
- Identify devices with stable metadata and current kernel identity, not only a mutable `/dev/sdX` name. Revalidate identity, size, partition table, free extents, and mount state immediately before writes.
- A changed device/layout invalidates confirmation. Re-discover and ask again; never continue using stale geometry.
- Refuse the installer medium and any device containing it. Refuse ambiguous multi-device/LVM/RAID layouts in v1 unless the supported adapter proves a safe interpretation.
- Never automatically shrink, move, format, or delete an existing partition in unallocated-space mode.
- Keep all new data partitions inside the selected verified free extent. Test sector alignment and both common logical-sector sizes.
- Preserve foreign partition boundaries, identifiers, filesystem contents, EFI loader files, and existing firmware entries. Boot-order changes must be displayed explicitly.
- Do not overwrite `EFI/BOOT/BOOTX64.EFI` or another OS namespace as a convenience fallback in coexistence mode.
- Refuse unsupported or ambiguous layouts before writes. Do not silently downgrade to erase-disk mode.

### Proposed target layout

Use GPT with an EFI system partition, a dedicated unencrypted `/boot` partition, and a Btrfs root partition or LUKS2 container containing Btrfs. This keeps the encrypted-root path from depending on GRUB decrypting root and makes the boot artifact boundary explicit.

For a whole-disk installation, create a project-owned ESP. For unallocated-space installation, prefer a new project ESP when the validated backend/firmware path supports it; otherwise reuse an explicitly selected suitable existing ESP without formatting it and write only the project's own namespace. The feasibility workstream must settle one deterministic supported policy and record it before storage implementation. It must not expand the authorized disk modes.

Use Timeshift-compatible `@` and `@home` subvolumes, with explicit exclusions for package caches, logs, and other non-system history where appropriate. Preserve package database consistency with the restored root. Derive minimum disk/free-space requirements from the resolved installed size, boot space, snapshot reserve, and measured headroom; publish the resulting requirements rather than guessing a permanent number now.

Use zram or another deliberately scoped non-hibernation swap policy after measuring memory needs. Hibernation is not an acceptance requirement.

### Encryption

LUKS2 is optional and off by default. Use supported cryptsetup defaults for the pinned environment; do not weaken the KDF solely to accommodate GRUB. Explain that the ESP and `/boot` are not encrypted and that disabling Secure Boot plus unsigned boot files does not provide tamper-proof boot.

Collect secrets only locally during installation. Keep temporary credential files in root-only tmpfs with restrictive permissions; do not place secrets in command lines, manifests, logs, screenshots, release artifacts, or persistent resume state. Clear them on success, cancellation, and error. Do not unlock or handle a foreign Windows volume's recovery key.

### Unified boot menu

Use GRUB entries that chainload confirmed existing EFI loaders, resolved by stable partition identifiers. Preserve those loaders in place. Validate paths and escape menu labels; do not interpolate filesystem labels into executable GRUB syntax.

Require intact discoverable GPT/UEFI boot targets. Before confirmation, show the foreign entries that will be retained and included. If the unified-menu contract cannot be satisfied safely, refuse that coexistence layout rather than hiding it behind a firmware-only fallback.

Warn that BitLocker can request its recovery key after firmware/security/boot-order changes. Synthetic tests cannot establish real Windows boot behavior, and release text must say so.

## 8. Snapshots and recovery

Use system snapshots without including `@home` in a system rollback. Create the initial baseline after successful provisioning, then configure a bounded retention policy and low-space handling. A snapshot on the same disk is not a backup.

Because `/boot` is outside the root snapshot, every restorable system snapshot needs a matching boot bundle or an equivalent proven reconstruction path. Record a snapshot identity, root/subvolume identity, package/kernel versions, required initramfs inputs, project boot configuration, boot-file hashes, and available space. Capture these records consistently, before declaring the snapshot recoverable.

The recovery flow must:

1. Discover a supported installed target and unlock only its LUKS container when applicable.
2. List only validated snapshot/boot-bundle pairs and explain what will and will not be restored.
3. Require explicit confirmation and save a pre-recovery reference where space permits.
4. Restore the system root without overwriting home data or unrelated subvolumes.
5. Restore or regenerate compatible boot artifacts and the project GRUB configuration from matching packages, then revalidate foreign EFI targets and menu entries.
6. Refuse an incomplete/mismatched recovery pair instead of applying a partial restore.
7. Validate mounts, initramfs, package database, boot paths, and user accounts before offering reboot.

Test a kernel-changing update followed by rollback, not merely a text-file restoration. Test encryption, low disk space, interrupted recovery, missing boot bundles, and preserved foreign EFI content. Supporting snapshot-menu booting is unnecessary for v1.

## 9. Optional online work and installed updates

The offline base is the recovery point. Optional online downloads/builds cannot silently replace a verified bootable base with a partially upgraded system.

- Keep optional application resolution separate from the frozen offline package transaction.
- Never use a package-database refresh followed by selected upgrades that create an unsupported partial Arch upgrade.
- Prefer a coherent package snapshot for installer-time extras. If current repositories require a full upgrade, make that a distinct validated transaction with a usable recovery point and boot-bundle handling.
- Stage downloads and package builds before applying changes where practical. Build AUR packages unprivileged; promote only validated package artifacts for privileged installation.
- A Retry must be idempotent. A Skip keeps the base/default role functional and records the unresolved optional choice.
- Network credentials are target data only with explicit user intent. Do not export them into diagnostic bundles or build inputs.
- Keep source/recipe metadata for the bundled Herdr package so normal AUR updates have a documented path.
- Existing setup/configuration updates must preserve user changes. Do not replace user configuration wholesale merely because the machine originated from the ISO.

## 10. CI and release design

### Separate trust levels

**Pull requests:** formatting, unit tests, shell/JSON checks, profile/schema validation, and safe mocked planning tests. No publication credentials, no execution of untrusted PR code on persistent privileged infrastructure.

**Trusted build:** a pinned Arch environment on the chosen GitHub-hosted runner. Builds may need privileged container/VM operations for archiso; scope these to ephemeral trusted runners. Never expose publication credentials to AUR build scripts.

**VM acceptance:** boot the built ISO with OVMF and QEMU, run installation scenarios on disposable image files, reboot the installed target, prove graphical functionality, and run recovery/coexistence scenarios.

**Publication:** minimum write permissions, protected tag policy, validated tag/source identity, and upload only the artifacts and manifests accepted by the preceding jobs.

### Resource proof comes first

The first feasibility gate must measure runner disk space, RAM, CPU time, nested virtualization access, display/3D rendering, artifact handoff limits, and build duration. Require observable successful Hyprland rendering and input/application interaction; a process list or console-only boot is insufficient.

If the selected runner cannot run the required desktop test, stop and request an infrastructure or support-contract decision. Do not silently remove the graphical gate or replace KVM coverage with an untested claim. Software-rendering experiments may inform the decision but must be labeled accurately.

### Release pipeline

1. Validate a trusted version tag and run existing checks.
2. Resolve/pin inputs, audit the build manifest, and build one candidate image.
3. Run the required automated matrix on that candidate.
4. Freeze its hash, package/input manifest, test results, license/source materials, support matrix, and release notes.
5. Split large images into conservatively sized pieces, such as 1,900,000,000 bytes each, below GitHub's under-2-GiB limit. Generate a manifest containing part order, names, sizes, part hashes, whole-image size, and whole-image hash.
6. Verify reassembly is byte-identical to the tested ISO. Provide Windows PowerShell and Linux/macOS instructions/helpers that validate before writing the assembled image. Helpers must not flash a disk automatically.
7. Upload verified GitHub assets to a draft release, verify availability, then publish the stable release automatically.
8. Upload the exact full image to S3-compatible storage under a versioned/content-addressed key. Verify server-side content by a trustworthy checksum or read-back, not by assuming a multipart ETag is SHA-256.
9. If mirror upload fails, publish the verified GitHub release anyway, clearly mark the mirror unavailable, and retry the upload without rebuilding. Add the mirror URL only when verified.

Avoid double publication from the existing tag and `release.created` triggers. Make reruns safe and reject replacement of a published version with different bytes. A failed build/test must not publish an installable ISO under a stable tag, even if source archives exist already.

### Integrity and licensing

Publish SHA-256 for the whole ISO, each split piece, and relevant manifests. State plainly that these detect accidental corruption but do not authenticate the publisher. Signed ISO manifests and keyless attestations are not required in v1.

This policy does not remove package-signature verification or redistribution obligations. Audit all bundled software, fonts, wallpaper, themes, and third-party source requirements. Make exact corresponding source/materials available when required. An upstream license at HEAD is not sufficient evidence for an older binary.

External object storage is a future deployment prerequisite. The plan uses an S3-compatible API and public HTTPS URL rather than choosing or purchasing a provider. Credentials belong in protected CI configuration, never in this repository or the interview record.

## 11. Acceptance matrix

| Area | Required automated evidence |
|---|---|
| Existing workflow | Existing Rust, shell, package-registry, role, and lifecycle tests remain green; old command does not expose destructive ISO flow by default |
| Source packaging | Existing AUR build/install layout still resolves binary, scripts, registry, and dotfiles; installed command can be smoke-tested without ISO assets |
| Build inputs | Complete manifest, pinned sources, license checks, package hashes, correct architecture, no private state or credentials |
| Boot | UEFI ISO boot launches the TUI; recovery/help/exit work; legacy/Secure Boot limitations are clear |
| Offline install | NIC removed, whole-disk unencrypted and LUKS2 installs complete and reboot successfully |
| Account/session | SDDM login and non-root Hyprland; no default credentials or installed autologin |
| Desktop | Actual rendered frame and interaction, default application launches, portals/session health, audio service health, wallpaper, bar, launcher, role commands |
| Safety | Boot medium blocked, stale plan rejected, hotplug identity changes rejected, cancellation before writes leaves disks unchanged |
| Unallocated space | Unencrypted/encrypted variants allocate only inside approved extents; existing partition identities and data hashes preserved |
| Foreign boot data | Existing EFI files and entries preserved; no overwrite of foreign/fallback paths; unified menu contains validated targets |
| Linux coexistence | A real second Linux system in QEMU boots through its retained menu path after installation and after recovery |
| Windows fixtures | Synthetic Windows-style partitions and EFI fixtures preserved; fixture result never labeled a real Windows boot result |
| Recovery | System snapshot plus matching boot restore, including a kernel-version change, encryption, home preservation, and foreign-boot preservation |
| Failure handling | Corrupt/missing offline package, storage exhaustion, installer interruption, bad encryption passphrase, missing boot bundle, and optional-download failures are reported accurately |
| Localization | EN/DE catalogs complete; long labels fit; keyboard and locale choices propagate to target and unlock prompts |
| Optional apps | Offline base survives failure; explicit Retry/Skip; role overrides only applied after successful app installation |
| Release files | Part checksums, order/size checks, reconstructed ISO hash, test-to-published byte identity, mirror-failure behavior |
| Release gates | Negative tests show failed builds/tests cannot publish; reruns cannot replace a version with different bytes |

Test matrix scope can be optimized for runtime only after coverage is mapped. Do not drop either disk mode, encryption mode, or the real installed-desktop check merely to fit CI time.

Not automatically certified by v1: physical Intel/AMD/NVIDIA/hybrid behavior, laptop suspend, real Wi-Fi/Bluetooth hardware, VirtualBox, VMware, actual Windows boot, and BitLocker behavior. VM service checks are not proof of those devices working.

## 12. Workstreams and dependency order

Do not parallelize shared installer mutations without explicit ownership. These are work packages, not authorization to launch agents.

### WS-0: freeze the baseline and prove the difficult assumptions

Dependencies: approved implementation scope.

Deliver:

- Record the implementation commit and reconcile concurrent repository changes.
- Inspect the external AUR PKGBUILD/install wrapper and preserve its actual file-layout contract.
- Pin candidate archiso/archinstall/build inputs.
- Build a minimal installer ISO on the selected GitHub-hosted runner.
- Prove offline base installation, LUKS2, unallocated-space preservation, and target reboot through the chosen archinstall integration.
- Prove a Hyprland graphical test can run in the required hosted QEMU environment.
- Settle and document the exact ESP, `/boot`, Btrfs, and recovery compatibility policy through experiments.
- Audit a pinned Herdr binary/source/recipe and prove offline launch.
- Measure image size, installed size, RAM, build disk/time, and test runtime.

Exit gate: every required contract has a working proof or a clearly blocking failure. Do not begin broad UI/refactoring work while a blocker remains. A different backend, runner class, profile substitution, or reduced support promise requires a new decision.

### WS-1: separate reusable setup operations

Dependencies: WS-0 feasibility passed.

Deliver:

- Explicit target-root, target-user, package-input, and offline policy interfaces.
- Shared configuration rendering with no accidental writes to the host/live user.
- Existing-system entrypoint retained with unchanged user-facing behavior.
- ISO profile resolution from `packages.json`, with no change to AUR defaults.
- Regression tests for existing config preservation and role behavior.

Exit gate: existing checks pass; target provisioning is tested against temporary roots; offline path contains no uncontrolled network operations.

### WS-2: build the real offline image

Dependencies: WS-1 package/provisioning contracts.

Deliver:

- archiso profile, live TUI launch/recovery entries, local repository, complete default payload.
- Prebuilt Herdr and all other required artifacts, licenses, manifests, retained source obligations.
- Hardware/driver selection data pinned to matching kernel packages.
- Rebuild and checksum tooling with scoped output/cleanup directories.

Exit gate: production-profile default install succeeds with NIC removed; first desktop session and Herdr launch pass.

### WS-3: implement the guarded wizard and storage adapter

Dependencies: WS-0 layout proof, WS-1 interfaces; integrate against WS-2 payload.

Deliver:

- ISO-mode state machine and EN/DE UI.
- Read-only discovery, immutable plan preview, device-bound confirmation, and typed backend adapter.
- Whole-disk and unallocated-space flows, optional LUKS2, accounts/localization, and explicit privilege boundaries.
- Foreign-loader discovery and unified GRUB entries with preservation checks.
- Structured progress, secret-safe logs, safe cancellation, and error states.

Exit gate: all storage safety and coexistence scenarios pass; existing command behavior is unchanged.

### WS-4: complete recovery and optional-online behavior

Dependencies: WS-3 functional installation and WS-2 offline payload.

Deliver:

- Consistent system snapshot/boot-bundle pairs and bounded retention.
- Guided ISO recovery that preserves home/foreign loaders.
- Installer-time optional selections, coherent package transactions, Retry/Skip, and role fallback rules.
- Local installed getting-started guide and later agent setup entry.

Exit gate: kernel-changing recovery succeeds; optional failures do not invalidate the base; encrypted and coexistence variants pass.

### WS-5: automate release and distribution

Dependencies: WS-2 image artifacts; full stable publication depends on WS-3/WS-4 tests.

Deliver:

- Trusted hosted build/test jobs and isolated publication permissions.
- Single tag-driven stable release path with no recursive/duplicate uploader.
- Split/reassemble/verify helpers and Windows/Linux/macOS documentation.
- S3-compatible upload adapter, hash validation, accurate mirror status, and byte-identical retries.
- License/source bundle, release support matrix, checksums, and maintenance runbook.

Exit gate: a disposable test release rehearsal proves both successful publication and blocked publication on failure; no public production release without separate release authorization.

### WS-6: final integration and release readiness

Dependencies: WS-0 through WS-5.

Deliver:

- Full acceptance matrix against the exact candidate ISO.
- Independent review of destructive storage handling, credentials/logging, recovery consistency, and legacy compatibility when implementation review is authorized.
- User-facing documentation that matches tested support, including checksums-only and unverified-platform limitations.
- Final artifact manifest, validation report, and unresolved-risk disposition.

Exit gate: no unresolved release blocker, all required evidence attached, and no claim exceeds its test coverage. Only after implementation completion is verified should this plan be archived.

## 13. Failure and rollback rules

- Before the destructive boundary, cancel without disk changes.
- After partition writes, never claim that the operation can be fully rolled back. Stop safely, retain non-secret diagnostics, and offer supported recovery/restart actions.
- A rerun must rediscover disks and request new confirmation. Do not persist an automatic destructive-resume token.
- Track completed phases for diagnosis, not as permission to skip safety validation on a new boot.
- Snapshot/boot restoration is a separate confirmed operation. Preserve failed state when practical, but do not restore unrelated data or foreign boot entries from stale backups.
- On driver incompatibility, retain a console recovery path; do not report the desktop healthy solely because login succeeded.
- On repository/backend schema drift, stop at validation rather than generating best-effort destructive commands.
- On CI or distribution failure, keep the tested artifact and evidence. Retry only the failed upload stage when safe, not the entire build with mutable dependencies.

## 14. Risks and implementation decision triggers

| Risk | Required response |
|---|---|
| Pinned archinstall cannot express safe free-space/encryption/offline flows | Stop WS-0 and request a backend/scope decision; no handwritten partitioner fallback without approval |
| Hosted runner cannot render/test Hyprland or lacks resources | Produce measured failure evidence and request a runner/test-contract decision |
| Herdr source/license/redistribution cannot be established | Block the selected profile; resolve exact release obligations or request a substitution |
| Package/asset closure silently fetches online | Treat disconnected-install failure as a release blocker |
| Shared ESP or foreign loader is ambiguous | Refuse coexistence before disk writes; preserve existing system |
| Root snapshot and boot files disagree | Refuse recovery until a matching pair or verified reconstruction is available |
| Current online repositories diverge from offline image | Use coherent resolution/full transaction boundaries; no partial-upgrade shortcut |
| Stable name is mistaken for hardware certification | Repeat the tested/unverified matrix in download, installer, and release notes |
| Object storage is not provisioned or temporarily fails | GitHub assets remain sufficient; show mirror unavailable and retry identical bytes |
| ISO channel compromised | Acknowledge checksums-only authenticity limit; do not imply signing guarantees |
| Existing AUR packaging relies on current layout | Preserve wrapper/payload locations or update packaging atomically with compatibility tests |

No further product choice is pending at the end of the interview. These are technical proofs and provisioning tasks. If a proof requires changing an agreed contract, reopen only that decision through a questionnaire.

## 15. Planning verification and confidence

Verified for this planning task:

- Inspected existing TUI, installer, registry, helper/test structure, and CI/release workflows.
- Confirmed the existing AUR package through AUR metadata.
- Read the Omarchy and Omarchy ISO READMEs directly after source discovery.
- Confirmed GitHub's per-asset limit in its documentation.
- Checked local ArchWiki/Hyprland guidance for ISO profiles, local package repositories, session startup, NVIDIA, VM graphics, GRUB chainloading, and Timeshift layouts.
- Recorded all 40 explicit user answers and reconciled the physical-support/VM-gate conflict.

Not verified: any ISO build, bare-metal/VM installation, disk safety implementation, graphical CI capability, offline dependency closure, recovery path, package redistribution compliance, upload, or release. Those checks belong to the workstreams above.

Confidence: 95/100 that this plan reflects the interview decisions and inspected architecture. Implementation feasibility remains conditional on WS-0, especially hosted graphical testing, safe coexistence, and snapshot/boot consistency. No tested-ISO claim is made.

## 16. Sources

### Repository evidence

- `Cargo.toml`
- `src/main.rs`
- `src/packages.rs`
- `packages.json`
- `install.sh`
- `setup.sh`
- `scripts/lib/setup-reliability.sh`
- `scripts/lib/agent-installers.sh`
- `tests/run.sh`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `.gitignore`

### Local documentation

- `/usr/share/doc/arch-wiki/html/en/Archiso.html`, sections “Profile structure”, “Selecting packages”, “Custom local repository”, and “Test the ISO in QEMU”.
- `/usr/share/doc/arch-wiki/html/en/Archinstall.html`, “Running the installer”.
- `/usr/share/doc/arch-wiki/html/en/Timeshift.html`, “Configuring btrfs snapshots”.
- `/usr/share/doc/arch-wiki/html/en/GRUB.html`, “Chainloading Windows/Linux installed in UEFI mode”. Its LUKS2 section explicitly carried an out-of-date warning during inspection; do not treat it as an authoritative statement of current Argon2 support.
- `/home/firstpick/.hyprwiki/content/getting-started/master-tutorial.md`, “Launching Hyprland” and “VM?”.
- `/home/firstpick/.hyprwiki/content/nvidia/_index.md`, “Proprietary driver setup”.

### External primary references

Inspected 2026-09-19; pin exact revisions during WS-0 rather than treating these moving URLs as lockfiles.

- [Omarchy](https://github.com/omacom/omarchy), README.
- [Omarchy ISO](https://github.com/omacom/omarchy-iso), README, including bundled packages, installation phases, and VM testing.
- [GitHub release limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases), “Storage and bandwidth quotas”.
- [Archinstall argument implementation](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/args.py), `--offline` help text.
- [Existing project AUR package](https://aur.archlinux.org/packages/hyprland-simple-setup-git) and AUR RPC metadata.
- [Herdr AUR package](https://aur.archlinux.org/packages/herdr-bin), AUR RPC metadata, and [upstream license](https://github.com/herdrdev/herdr/blob/master/LICENSE). Metadata disagreement is an audit trigger, not a legal conclusion.

### Exploration trace

- Initial compact report: `/home/firstpick/.pi/agent/skills/repo-explorer/repo-explorer-effectiveness-2026-09-19T22-54-34-066Z-Hyprland-Simple-Setup-97d1e9e455.md`.
- Expanded exploration failure report: `/home/firstpick/.pi/agent/skills/repo-explorer/repo-explorer-effectiveness-2026-09-19T22-54-44-306Z-Hyprland-Simple-Setup-97d1e9e455.md`.
