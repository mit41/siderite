# siderite

A ublue-os based image with [System76 cosmic desktop](https://github.com/pop-os/cosmic-epoch) installed. I'm a fan of the DE and the container based OS's built by the [universal blue](https://universal-blue.org/) project, so I tried putting all this awesome stuff into this image.

[Siderites](https://en.wikipedia.org/wiki/Iron_meteorite), also called iron or ferrous meteorites, are a type of meteorite consisting mostly of an iron-nickel alloy. Since iron can rust and meteorites are cosmic i thought it would be a fitting name for this image.

## Usage

[!WARNING]
Use this image on your own risk. This image works for me and my usecase. It might not work for yours.

I'm daily driving this image on my laptop and it works for me. If you want to try it yourself you can switch to this image by running:

```bash
sudo bootc switch ghcr.io/mit41/siderite:stable
sudo systemctl reboot
```

You could also clone this repo and create an iso to install on your system.

## Detailed Guides

- [Homebrew/Brewfiles](custom/brew/README.md) - Runtime package management
- [Flatpak Preinstall](custom/flatpaks/README.md) - GUI application setup
- [ujust Commands](custom/ujust/README.md) - User convenience commands
- [Build Scripts](build/README.md) - Build-time customization

### OCI Container Resources

The template imports files from these OCI containers at build time:

```dockerfile
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

Your build scripts can access these files at:
- `/ctx/oci/base/` - Base system configuration
- `/ctx/oci/common/` - Shared desktop configuration
- `/ctx/oci/branding/` - Branding assets
- `/ctx/oci/artwork/` - Artwork files
- `/ctx/oci/brew/` - Homebrew integration files

**Note**: Renovate automatically updates `:latest` tags to SHA digests for reproducible builds.

## Local Testing

Test your changes before pushing:

```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Community

- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion](https://github.com/bootc-dev/bootc/discussions)

## Learn More

- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Video Tutorial by TesterTech](https://www.youtube.com/watch?v=IxBl11Zmq5wE)
