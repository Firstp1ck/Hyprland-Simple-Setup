# Grill Me Results

Generated: 2026-09-19T23:26:05.235Z

## Plan

i want to do something ambitious. I want to have a ISO of this setup, so the setup should start directly when booted from the iso over for example an usb. get inspiration of omarchy https://github.com/omacom/omarchy the goal for now is a detailed plan.

## Shared Understanding

Completed four questionnaire rounds with 40 explicit answers. Plan only, no ISO implementation or publication authorized. Build a vanilla Arch Linux x86_64 UEFI installer ISO that starts the existing Rust TUI in a new guided ISO mode, installs a curated Hyprland desktop offline, and preserves the existing AUR package and current existing-system setup workflow. Publish stable tagged releases automatically after required QEMU and safety tests, explicitly labeling physical GPUs, VirtualBox/VMware, and actual Windows/BitLocker boot unverified. The detailed implementation plan is plans/planned/bootable-installer-iso.md. Product decisions are resolved; feasibility spikes and infrastructure provisioning remain implementation prerequisites, not completed work.

## Questions and Answers

### 1. What should appear when someone boots the USB?

**Recommended answer:** The configured Hyprland live desktop with an explicit Install launcher, so users can try the setup without touching their disks.

**User answer:** Start the setup/installation wizard directly; no full live desktop

**Status:** resolved

**Notes:** User selected installer-first rather than a live desktop. ISO session is an installation environment; configured Hyprland is the installed outcome.

### 2. Who must the first release serve?

**Recommended answer:** A public experimental release for technical users, with a narrow tested hardware matrix rather than a general-purpose distro promise.

**User answer:** Public release for newcomers with a polished supported installation

**Status:** resolved

**Notes:** Requires stronger onboarding, safety, support documentation, hardware validation, and release gates than the recommended technical preview.

### 3. Which base should the ISO use?

**Recommended answer:** Vanilla Arch Linux with archiso; the existing pacman/AUR package model fits it without inheriting another distro's custom repositories.

**User answer:** Vanilla Arch Linux

**Status:** resolved

### 4. Which hardware must v1 explicitly support and test?

**Recommended answer:** x86_64 Intel/AMD graphics plus a QEMU/KVM test target; treat NVIDIA as experimental unless it is essential to your machines.

**User answer:** x86_64 PCs with Intel or AMD graphics; x86_64 PCs with NVIDIA graphics; Laptops with hybrid Intel/AMD plus NVIDIA graphics; QEMU/KVM virtual machines; VirtualBox or VMware virtual machines

**Status:** resolved

**Notes:** Broad release matrix selected. Define NVIDIA generations and the actual hardware/VM release evidence in a dependent round. ARM64 not selected.

### 5. What firmware compatibility is required?

**Recommended answer:** UEFI with Secure Boot disabled for v1; legacy BIOS and Secure Boot signing add separate implementation and testing work.

**User answer:** UEFI only; Secure Boot disabled

**Status:** resolved

### 6. What must work without internet?

**Recommended answer:** The default desktop and default disk installation, if included, work offline; optional applications can require internet. This makes USB boot independent of mirrors and AUR availability.

**User answer:** Offline default desktop/install; optional extras online

**Status:** resolved

**Notes:** Applied to selected installer-only boot: ISO boots installer offline and installs a usable default desktop offline.

### 7. How much of today's selectable setup should ship on the ISO?

**Recommended answer:** One curated default profile generated from packages.json, preserving other choices for installation or later configuration rather than bundling everything.

**User answer:** One representative default profile; keep optional choices available separately

**Status:** resolved

### 8. Should changes made while running from USB survive reboot?

**Recommended answer:** A disposable live session in v1; persistent USB storage is a separate feature with filesystem and privacy implications.

**User answer:** No persistence; every USB boot starts clean

**Status:** resolved

### 9. Which Omarchy ideas should guide this project?

**Recommended answer:** Borrow installer structure, prebuilt package delivery, and release testing, while keeping this project's appearance and application choices.

**User answer:** Prebuilt packages and offline installation; Polished onboarding and cohesive defaults

**Status:** resolved

**Notes:** Omarchy is inspiration for these selected aspects, not authorization to fork it or adopt its appearance/update system.

### 10. What should happen to the current setup-on-existing-Arch workflow?

**Recommended answer:** Preserve it and share package/configuration logic with the ISO rather than replacing it.

**User answer:** Other: the github repo is currently also an aur package. this should be kept. iso will be a release artifact on github releases.

**Status:** resolved

**Notes:** Preserve AUR distribution and add ISO as a GitHub Release artifact. Need check current PKGBUILD and resolve compatibility requirements for existing workflows.

### 11. How should v1 be built and distributed?

**Recommended answer:** A documented local build plus manually approved experimental releases; introduce automated publication only after VM and hardware gates work.

**User answer:** Automated CI builds and public releases from the start

**Status:** resolved

**Notes:** Use GitHub Releases per preceding answer. Define publication gates, runner constraints, artifact splitting, and signing policy.

### 12. What image-size constraint should the plan optimize for?

**Recommended answer:** Target an 8 GB USB drive and measure actual ISO/RAM use before declaring hard limits.

**User answer:** No initial size target; prioritize functionality

**Status:** resolved

**Notes:** GitHub Release per-asset limits still constrain distribution and require evidence-backed handling.

### 13. If the offline ISO exceeds GitHub's under-2-GiB per-asset limit, how should we distribute it?

**Recommended answer:** Preserve offline functionality and use split GitHub assets with a documented verified reassembly helper; users must reassemble them before flashing.

**User answer:** Other: both 1. and 2.

**Status:** resolved

**Notes:** Refers to split GitHub Release assets with reassembly/verification tools AND a full externally hosted ISO linked from GitHub Releases. External hosting choice/availability remains to resolve.

### 14. What should the automatically launched installer look like?

**Recommended answer:** Extend the existing Rust TUI with a guided ISO mode; it works without a graphics driver and preserves the project's current interface.

**User answer:** Guided text/terminal installer based on the existing Rust TUI

**Status:** resolved

### 15. Which disk-installation modes must v1 offer?

**Recommended answer:** Erase one explicitly selected whole disk only, with a clear destructive-action summary and typed confirmation; dual boot and partition resizing multiply the risk.

**User answer:** Erase disk or install into existing unallocated space; never resize

**Status:** resolved

**Notes:** Requires existing-partition/ESP preservation, free-space validation, boot entry policy, multi-disk guardrails, and negative tests.

### 16. Which installed filesystem/recovery policy should v1 use?

**Recommended answer:** One fixed Btrfs layout with snapshots and a tested recovery path, building on the project's existing Timeshift/grub-btrfs integration rather than exposing many layouts.

**User answer:** Btrfs with snapshots and a tested recovery path

**Status:** resolved

### 17. What encryption policy should the installer offer?

**Recommended answer:** LUKS2 encryption enabled by default with an explicit opt-out and clear passphrase/recovery guidance; do not collect any actual passphrase here.

**User answer:** Encryption optional and off by default

**Status:** resolved

### 18. How should ISO defaults relate to packages.json?

**Recommended answer:** An explicit ISO profile with the same desktop identity, using redistributable prebuilt packages and audited substitutions where needed; keep AUR-install defaults unchanged.

**User answer:** Allow an explicit ISO-specific default profile; preserve existing AUR defaults

**Status:** resolved

### 19. When should users choose and install optional online applications?

**Recommended answer:** After the first successful desktop boot, keeping network/AUR failures out of the base OS installation.

**User answer:** Inside the USB installer when internet is available

**Status:** resolved

**Notes:** Keep offline base installation independent of optional online selections; clarify behavior if downloads fail.

### 20. How should optional coding agents appear in the ISO experience?

**Recommended answer:** Do not bundle agent binaries or run remote installers during base installation; offer them later through the existing optional agent selector with manual authentication.

**User answer:** Offer coding agents later; no agent required for offline installation

**Status:** resolved

### 21. What implementation direction should the plan take for partitioning and base Arch installation?

**Recommended answer:** Evaluate a pinned archinstall backend behind the Rust wizard, with an early offline/encryption proof before committing; avoid inventing a partitioning engine.

**User answer:** Use pinned archinstall if an early integration proof passes

**Status:** resolved

**Notes:** Spike must include install into unallocated space, ESP preservation, selected Btrfs recovery scheme, and optional LUKS2. Failure triggers an explicit new architecture decision, not silent fallback.

### 22. Beyond keeping the AUR package, what compatibility must the plan preserve?

**Recommended answer:** Keep the current command, existing-system setup, package choices, and config-preservation behavior; add a distinct ISO mode.

**User answer:** Preserve current command and existing-system setup behavior

**Status:** resolved

### 23. How should v1 define NVIDIA support?

**Recommended answer:** Support explicitly tested GPUs supported by current Arch drivers, including hybrid laptops; detect unsupported/legacy GPUs early instead of promising all NVIDIA generations.

**User answer:** Current-driver-supported, explicitly tested NVIDIA and hybrid hardware

**Status:** resolved

**Notes:** Potential conflict with later VM-only release gate; must reconcile tested hardware scope versus candidate support.

### 24. How should public support claims be verified?

**Recommended answer:** Automated VM gates plus recorded physical Intel/AMD, NVIDIA, and hybrid-laptop checks before a stable release; missing evidence blocks that support claim.

**User answer:** Release after VM tests; label physical-hardware support unverified

**Status:** resolved

**Notes:** Requires reconciliation with newcomer-facing supported release and explicitly tested NVIDIA selection. VM tests cannot establish physical GPU behavior.

### 25. What build infrastructure can the plan rely on?

**Recommended answer:** Start with GitHub-hosted runners and a pinned Arch build environment, measure resource limits, and make a dedicated runner a documented escalation rather than an assumption.

**User answer:** GitHub-hosted runners only initially; assess limits in a build spike

**Status:** resolved

### 26. When should automation publish an ISO?

**Recommended answer:** Tag-triggered builds with automatic prerelease publication after tests; stable promotion requires the selected hardware evidence, not publication on every commit.

**User answer:** Tags publish stable releases automatically after automated tests

**Status:** resolved

### 27. What authenticity guarantees should releases provide?

**Recommended answer:** SHA-256 checksums, a signed checksum manifest, and build provenance; checksums alone detect corruption but do not authenticate the publisher.

**User answer:** Checksums only for v1

**Status:** resolved

**Notes:** Record authenticity limitation; checksums detect corruption but are not publisher authentication.

### 28. How should installed machines receive updates?

**Recommended answer:** Normal Arch/AUR package updates plus explicit setup/config updates that preserve user edits; do not add a custom distro update service in v1.

**User answer:** Normal Arch/AUR updates; explicit non-destructive setup/config updates

**Status:** resolved

### 29. What localization must v1 provide?

**Recommended answer:** English installer text with explicit keyboard, timezone, and system-locale selection; remove hardcoded Swiss-German defaults from the ISO path.

**User answer:** English and German UI; selectable system localization

**Status:** resolved

### 30. How should we reconcile broad NVIDIA/hybrid support with VM-only release gates?

**Recommended answer:** Implement support for current drivers, publish stable tags after VM gates as requested, but label all physical GPU compatibility unverified until device-specific evidence exists.

**User answer:** Target current physical GPUs, but explicitly label them unverified at release

**Status:** resolved

**Notes:** Supersedes the explicitly-tested physical-hardware boundary from turn 23. Public newcomer-oriented stable releases are VM-validated, not physically hardware-certified.

### 31. Which virtual machines must be release-tested automatically?

**Recommended answer:** QEMU/KVM with UEFI and working 3D acceleration is mandatory; document VirtualBox/VMware as unverified until separately tested, since desktop graphics behavior differs.

**User answer:** QEMU/KVM required; VirtualBox and VMware documented but unverified

**Status:** resolved

### 32. What external-hosting contract should the plan use for the full ISO?

**Recommended answer:** User-provisioned S3-compatible object storage with a public HTTPS download URL and automated CI uploads; keep provider/bucket/credentials as deployment configuration, not source code or interview answers.

**User answer:** Plan S3-compatible object storage and public HTTPS downloads

**Status:** resolved

**Notes:** Provider-neutral S3 deployment contract. Provisioning endpoint/bucket/CI credentials is a future infrastructure prerequisite, not authorization to create paid infrastructure now.

### 33. If one required distribution destination fails, what should release automation do?

**Recommended answer:** Keep the GitHub release draft until GitHub parts and the full mirror ISO are uploaded and verified; retry uploads without rebuilding different bytes.

**User answer:** Publish verified GitHub assets even if the mirror is temporarily unavailable

**Status:** resolved

**Notes:** Mirror failure is non-blocking. Mark mirror unavailable, omit invalid URLs, retry publishing the exact same verified bytes.

### 34. If an optional application cannot download or install, what should happen?

**Recommended answer:** Preserve the completed offline base, show the failure clearly, and let the user retry or explicitly skip it; never report that application as installed.

**User answer:** Keep the base installed; offer explicit Retry or Skip with a final summary

**Status:** resolved

### 35. What should 'install into unallocated space' guarantee?

**Recommended answer:** Support existing Windows or Linux on GPT disks, never resize/format their partitions, preserve their EFI files/entries, and let firmware select the OS; a unified cross-OS GRUB menu is not required in v1.

**User answer:** Preserve Windows/Linux and require a unified boot menu

**Status:** resolved

**Notes:** Requires GRUB integration plus reliable identification and preservation of foreign boot targets. Unsupported layouts must be refused before writes; clarify supported foreign-OS boundary if needed.

### 36. What must the tested Btrfs recovery path provide?

**Recommended answer:** Initial/system snapshots plus a guided recovery mode on the ISO that restores the system and repairs matching boot files; leave personal files untouched and do not call snapshots a backup.

**User answer:** Guided ISO-based snapshot restore and boot repair; no snapshot boot-menu requirement

**Status:** resolved

### 37. Which baseline should the plan specify?

**Recommended answer:** Firefox, Fish, Kitty, Zellij, Neovim, Kate, Waybar, SwayNC, Wofi, Merkuro, Bluedevil, plasma-nm, and pavucontrol-qt; retain this project's Hyprland theme and keybindings, omit agents and a dock, and audit all bundled assets.

**User answer:** Other: packages as recommended in 1. but instead of zejllji, use herdr.

**Status:** resolved

**Notes:** Final profile uses Herdr instead of Zellij. Current package registry identifies herdr-bin as AUR. Audit redistribution, runtime dependencies, offline launch, and update path; do not silently substitute another multiplexer.

### 38. Must v1 support hibernation to disk?

**Recommended answer:** Normal shutdown and suspend only, with suspend explicitly hardware-dependent; defer hibernation because swap/resume setup interacts with encryption and Btrfs recovery.

**User answer:** No hibernation guarantee in v1; shutdown and suspend only

**Status:** resolved

### 39. Which existing installations should the unified-menu promise cover?

**Recommended answer:** GPT/UEFI Windows and Linux with discoverable, intact EFI loaders; reject unsupported or ambiguous layouts before writes, never resize partitions, and warn BitLocker users that boot changes can trigger recovery.

**User answer:** Discoverable intact GPT/UEFI loaders only; refuse unsupported layouts before writes

**Status:** resolved

### 40. What Windows-specific evidence should block release?

**Recommended answer:** Require synthetic Windows-style partition/EFI preservation tests and real Linux dual-boot VM tests, but label actual Windows/BitLocker boot unverified until a licensed test image is supplied. A fake EFI fixture must not be reported as a Windows boot test.

**User answer:** Fixtures and Linux dual-boot gate releases; actual Windows/BitLocker boot remains explicitly unverified

**Status:** resolved

**Notes:** Final user-facing release notes and installer warnings must distinguish implemented detection/chainloading from unverified actual Windows/BitLocker boot.

## Agreed Decisions

- Installer-first USB boot, no live Hyprland preview and no persistent USB session. Public newcomer-facing UX, English/German UI, selectable keyboard/locale/timezone.
- Vanilla Arch Linux, x86_64, UEFI only, Secure Boot disabled. No ARM, legacy BIOS, partition resizing, or hibernation guarantee in v1.
- Preserve hyprland-simple-setup-git AUR distribution, the current command, application choices, and non-destructive configuration behavior. Add ISO mode alongside the existing workflow.
- Use archiso for the image and evaluate a pinned archinstall backend behind the Rust TUI. Adoption requires an early proof of offline install, unallocated-space preservation, Btrfs, optional encryption, and hosted-runner testing. No silent replacement if that proof fails.
- Support erase-selected-disk and installation into existing unallocated space. Existing GPT/UEFI Windows/Linux loaders must be intact and discoverable. Preserve their partitions and EFI data; provide a unified boot menu; reject unsupported layouts before writes.
- Btrfs system snapshots with guided ISO-based restore and boot repair; personal files preserved. Bootable snapshot menu entries are not required. LUKS2 encryption optional and off by default.
- Offline profile: Firefox, Fish, Kitty, Herdr, Neovim, Kate, Waybar, SwayNC, Wofi, Merkuro, Bluedevil, plasma-nm, pavucontrol-qt, plus required system/desktop dependencies and the project's appearance/keybindings. No default dock or bundled coding agents. Preserve separate AUR workflow defaults.
- Offer optional online applications inside the USB installer. Complete the offline base independently; on an optional-app failure offer explicit Retry or Skip and an honest final summary. Coding agents remain a later optional action with manual authentication.
- Borrow Omarchy's prebuilt/offline package delivery and cohesive onboarding. Do not adopt an Omarchy fork, its full application set, or a custom managed update service.
- Target current-driver-supported Intel/AMD, NVIDIA, and hybrid hardware, but label physical GPU compatibility unverified until device-specific evidence exists. QEMU/KVM with UEFI and functioning desktop graphics is the required automated VM gate; VirtualBox/VMware remain unverified.
- Require synthetic Windows-style partition/EFI preservation tests and real Linux dual-boot VM tests. Actual Windows and BitLocker boot remain explicitly unverified until a licensed-image test is available.
- Use GitHub-hosted runners initially. Stable tags publish automatically only after automated release gates pass. No physical-hardware release gate. Assess hosted-runner CPU/RAM/disk/KVM/graphics feasibility early.
- No product image-size cap. For large ISOs publish split GitHub Release assets below the per-file limit with reassembly and verification tools, plus a full ISO on S3-compatible object storage over public HTTPS.
- GitHub assets are sufficient to publish if the mirror is temporarily unavailable. Mark mirror status accurately and retry uploading exactly the same verified bytes. Provider, endpoint, bucket, and credentials are deployment configuration.
- SHA-256 checksums only for v1 release artifacts. These detect corruption but do not authenticate the publisher. Preserve package-signature validation where applicable; checksum-only ISO release policy is not permission to disable Arch package verification.
- Installed systems use normal Arch/AUR updates and explicit setup/config updates that preserve user changes; no custom distro-wide updater.

## Open Risks

- No ISO was built or booted. Offline archinstall integration, destructive-operation safety, dual-boot behavior, encrypted recovery, and CI feasibility must be proved before implementation is accepted.
- The current setup script mixes live-system mutations, user configuration, online downloads, and package updates. Reusing it unchanged inside a target chroot would be unsafe and would violate the offline contract.
- Herdr is mandatory in the selected ISO profile. The observed AUR metadata lists AGPL-3.0-or-later while current upstream LICENSE metadata identifies Apache-2.0. Audit the exact pinned binary/source and redistribution obligations before bundling; do not infer its license from current upstream HEAD or silently substitute Zellij.
- A complete offline dependency closure must include firmware, graphics-driver/kernel compatibility, assets, themes, fonts, initramfs tooling, setup runtime files, and all packages needed by supported install choices. Remote setup fetches must be eliminated from the offline path.
- GitHub's under-2-GiB asset limit is verified. Splitting/reassembly adds newcomer friction; the full mirror needs externally provisioned storage and upload configuration.
- GitHub-hosted nested virtualization and accelerated Hyprland rendering must be demonstrated on the selected runner. Headless console installation alone does not prove a working installed desktop.
- Release support claims intentionally exclude physical validation, other VM products, and actual Windows/BitLocker boot. Stable version labels must not conceal these limits.
- Partition-table preservation and synthetic EFI tests are not proof that Windows boots. Firmware/NVRAM changes can trigger BitLocker recovery even without touching Windows files.
- Encrypted root with separately stored boot files requires a snapshot/boot-artifact compatibility strategy. Snapshots are not backups, and restoring root must not overwrite personal home data or foreign EFI loaders.
- Rolling repositories and online extras can diverge from the ISO snapshot. Avoid partial upgrades and ensure optional-app failure cannot strand the verified offline system.
- Release checksums alone do not protect against a compromised distribution channel. Package supply-chain integrity, AUR source review, and license/source obligations remain separate build requirements.
- The native repository explorer returned a stale indexed plan path and failed its expanded validation. Targeted reads established the cited source facts; the implementation phase must refresh/recheck the repository baseline.

## Next Decision Needed

No pending product decision. Begin the plan's feasibility workstream only after implementation authorization. Escalate if the pinned archinstall backend, hosted CI graphics, mandatory Herdr packaging, or safe dual-boot/recovery contract cannot pass its proof.
