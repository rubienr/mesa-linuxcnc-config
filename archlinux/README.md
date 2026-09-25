# LinuxCNC on Arch Linux with PREEMPT_RT

This is the working installation and tuning record for a Lenovo ThinkCentre
M75q Gen 2 (type 11JK) with a Ryzen 5 PRO 4650GE and Mesa 7I95T. It deliberately
records the Arch-specific failures encountered during setup.

Validated package and firmware versions at the time of writing:

```text
BIOS               M3CKT3EA / 1.62 (2026-01-15)
kernel             linux-rt 7.2.6.rt3.arch1-1
LinuxCNC           2.9.10-1
Mesa utility       mesaflash-git 3.4.9.r33.g11e6f85-1
Realtek driver     r8168-dkms 8.057.00-2
BLT                2.4z-12 (locally patched)
Tcl/Tk             8.6.16-1
```

## 1. Install the realtime kernel

```bash
sudo pacman -Syu
sudo pacman -S linux-rt linux-rt-headers
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
```

If `grub-mkconfig` produces only firmware and snapshot entries, verify that
GRUB's Linux generator is executable. This permission was wrong on the
validated installation:

```bash
ls -l /etc/grub.d/10_linux
sudo chmod 755 /etc/grub.d/10_linux
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

After rebooting, verify PREEMPT_RT rather than relying only on the kernel name:

```bash
uname -r
cat /sys/kernel/realtime
```

The second command must print `1`.

## 2. Install build prerequisites and LinuxCNC

Install the normal Arch build tools and `hostname`. The missing `hostname`
program caused part of the LinuxCNC build/runtime setup to fail; on Arch it is
provided by `inetutils`:

```bash
sudo pacman -S --needed base-devel git inetutils
command -v hostname
pacman -Qo /usr/bin/hostname
```

Install the stable LinuxCNC package and current Mesa utility from the AUR:

```bash
yay -S linuxcnc
yay -S mesaflash-git
```

The tested installation uses stable `linuxcnc 2.9.10-1`, not
`linuxcnc-git`. The Git package may be newer but is a moving development
target and is unnecessary for this benchmark.

Verify the realtime helper. The leading `s` in the owner execute position is
intentional for this package:

```bash
pacman -Q linuxcnc
ls -l /usr/bin/rtapi_app
```

Expected permissions begin with `-rwsr-xr-x`. Do not run `modprobe rtapi`:
this configuration uses userspace RTAPI on PREEMPT_RT, so there is no `rtapi`
kernel module. The misleading module message from `halcmd` can also appear
when no LinuxCNC realtime session is running or when `halcmd` is invoked as a
different user.

## 3. Build the BLT Tcl/Tk extension correctly

BLT is required by Tcl/Tk-based tools such as the LinuxCNC latency histogram.
The unmodified AUR `blt` recipe failed in two ways on this system:

- GCC rejected the old spline callback declarations with `too many arguments
  to function` under the newer C language rules.
- `libBLT24.so` was initially built without Tcl/Tk dependencies and later
  failed with an undefined `Tk_MeasureChars` symbol.

Clone the AUR recipe, apply the included patch, and force a clean rebuild:

```bash
mkdir -p "$HOME/builds"
cd "$HOME/builds"
git clone https://aur.archlinux.org/blt.git
cd blt
patch -Np1 < "$HOME/linuxcnc/archlinux/blt-PKGBUILD.patch"
makepkg -Cfsi
```

`-f` matters if an earlier package file exists; `makepkg -Csi` alone can end
up reinstalling an already-built broken package instead of producing the
intended replacement.

Confirm that BLT is linked against both Tk and Tcl:

```bash
readelf -d /usr/lib/libBLT24.so | grep NEEDED
```

The output must include at least `libtk8.6.so` and `libtcl8.6.so` in addition
to the usual system libraries.

Some LinuxCNC latency utilities are intended for a source-tree Run In Place
(RIP) environment. The Mesa benchmark in the sibling directory does not
require a RIP installation.

## 4. Replace `r8169` with `r8168-dkms`

The exact PCI device in the tested computer is:

```text
Realtek RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet Controller
PCI ID:          10ec:8168, revision 15
Subsystem:       Lenovo 17aa:3190
Firmware:        rtl8168h-2_0.0.2 (2015-02-26)
PCI address:     0000:01:00.0
```

The realtime kernel's in-tree `r8169` driver produced rapidly increasing Mesa
packet errors and millisecond-scale HostMot2 read delays on this controller.
The AUR `r8168-dkms` driver was materially better.

The realtime headers must be installed so DKMS builds for `linux-rt`:

```bash
sudo pacman -S --needed dkms linux-rt-headers
yay -S r8168-dkms
sudo mkinitcpio -P
sudo reboot
```

The package installs `/usr/lib/modprobe.d/r8168-dkms.conf` containing:

```text
blacklist r8169
```

Verify the active driver after rebooting:

```bash
lspci -nnk -s 01:00.0
ethtool -i enp1s0
```

The first line must be `driver: r8168`. On the validated system it reports
version `8.057.00-NAPI`.

Configure the dedicated Mesa interface without a gateway or DNS server:

```bash
sudo nmcli connection modify "Mesa LAN" \
    connection.interface-name enp1s0 \
    ipv4.method manual \
    ipv4.addresses 192.168.1.111/24 \
    ipv4.gateway "" \
    ipv4.dns "" \
    ipv4.never-default yes \
    ipv6.method disabled
sudo nmcli connection up "Mesa LAN"
ping -c 3 192.168.1.121
```

## 5. Kernel command line and CPU isolation

A representative `/proc/cmdline` is shown below. The root filesystem UUID is
an installation-specific metavalue, not a UUID that should be copied:

```text
BOOT_IMAGE=/vmlinuz-linux-rt root=UUID=<ROOT_FILESYSTEM_UUID> rw rootflags=subvol=@ loglevel=3 quiet ipv6.disable=1 isolcpus=domain,managed_irq,5,11 nohz_full=5,11 rcu_nocbs=5,11 irqaffinity=0-4,6-10
```

GRUB generates the real `root=UUID=...` argument for the installed root
filesystem. Leave that generation to GRUB; only add the tuning parameters to
`GRUB_CMDLINE_LINUX_DEFAULT`.

The tuning portion in `/etc/default/grub` is:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet ipv6.disable=1 isolcpus=domain,managed_irq,5,11 nohz_full=5,11 rcu_nocbs=5,11 irqaffinity=0-4,6-10"
```

`ipv6.disable=1` disables IPv6 system-wide at boot: interfaces receive no IPv6
addresses and applications cannot open IPv6 sockets. Use it only when the
Wi-Fi/SSH network is known to work over IPv4. Remove the parameter and reboot
if IPv6 is needed later; see the
[Linux kernel IPv6 documentation](https://www.kernel.org/doc/html/latest/networking/ipv6.html).

The Ryzen 5 PRO 4650GE presents two logical CPUs per physical core. The tested
allocation is:

| Physical core | Logical CPUs | Intended role |
| --- | --- | --- |
| 0 | 0 / 6 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 1 | 1 / 7 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 2 | 2 / 8 | CPU 2 idle; CPU 8 dedicated to the Mesa Ethernet IRQ during tests |
| 3 | 3 / 9 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 4 | 4 / 10 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 5 | 5 / 11 | CPU 5 isolated and idle; CPU 11 isolated for the LinuxCNC servo thread |

Only CPUs 5 and 11 are kernel-isolated. CPUs 2 and 8 are reserved operationally
by excluding them from the stress workload, pinning the Mesa IRQ to CPU 8, and
keeping Wi-Fi IRQs away from both siblings.

Regenerate the configuration and reboot after changing it:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
cat /proc/cmdline
cat /sys/devices/system/cpu/isolated
cat /sys/devices/system/cpu/nohz_full
ip -6 address
```

CPUs 5 and 11 should be listed as isolated/nohz-full CPUs. The LinuxCNC FIFO
servo thread runs on CPU 11 and CPU 5 is its idle SMT sibling. With
`ipv6.disable=1`, `ip -6 address` should show no IPv6 addresses.

## 6. Network IRQ placement

CPU isolation does not automatically keep every managed MSI-X vector away
from isolated CPUs. The Intel AX200 Wi-Fi driver initially placed vectors on
both CPU 5 and CPU 11. IRQ numbers also change after each reboot.

Reserve physical core CPU2/8 for Mesa, using CPU 8 for the LAN IRQ, and keep
Wi-Fi away from CPUs 2, 5, 8, and 11:

```bash
LAN_IRQ=$(ls /sys/class/net/enp1s0/device/msi_irqs)
echo 8 | sudo tee "/proc/irq/$LAN_IRQ/smp_affinity_list"

for IRQ in $(ls /sys/class/net/wlp2s0/device/msi_irqs); do
    CPU=$(cat "/proc/irq/$IRQ/effective_affinity_list")
    case "$CPU" in
        2)  TARGET=1 ;;
        5)  TARGET=4 ;;
        8)  TARGET=7 ;;
        11) TARGET=10 ;;
        *)  continue ;;
    esac
    echo "$TARGET" | sudo tee "/proc/irq/$IRQ/smp_affinity_list"
done
```

Some Wi-Fi effective affinities update only after another interrupt. Verify
both requested and effective affinity before starting LinuxCNC:

```bash
for DEV in enp1s0 wlp2s0; do
    echo "=== $DEV ==="
    for IRQ in $(ls "/sys/class/net/$DEV/device/msi_irqs"); do
        printf 'IRQ %-3s requested=' "$IRQ"
        cat "/proc/irq/$IRQ/smp_affinity_list"
        printf '        effective='
        cat "/proc/irq/$IRQ/effective_affinity_list"
    done
done
```

These runtime assignments are not persistent across reboot. Reapply them
after boot until a dedicated systemd unit is installed.

The maintained workspace scripts implement the same dynamic IRQ discovery and
also pin/check the LinuxCNC FIFO task once it exists:

```bash
sudo "$HOME/linuxcnc/config/thread-affinity-set.sh"
"$HOME/linuxcnc/config/thread-affinity-check.sh"
```

Run the setter once after boot for the network IRQs and again after LinuxCNC
starts for its realtime task.

The reproducible stress affinity deliberately excludes the two realtime and
two Mesa-network CPUs:

```bash
taskset -c 0-1,3-4,6-7,9-10 \
    stress-ng --cpu 8 --vm 2 --vm-bytes 2G --timeout 24h
```

## 7. BIOS configuration

Installed firmware: Lenovo `M3CKT3EA / 1.62`. The following settings were
applied for the current test:

```text
WirelessLANAccess                 Enabled (required for SSH)
Bluetooth                        Disabled
CStateSupport                    Disabled
ASPMSupport                      Disabled
EnhancedPowerSavingMode          Disabled
OnboardAudioController           Disabled
AMDSecureVirtualMachine (SVM)    Disabled
IOMMU                            Disabled
DASHSupport                      Disabled
Integrated GPU UMA framebuffer   2 GiB
```

The cooling mode was left unchanged; `Full speed` was not selected.
`CPBMode` (AMD boost) was also left unchanged. Change one variable at a time
if either option is tested later.

At runtime, this BIOS configuration results in:

```bash
cat /sys/devices/system/cpu/cpuidle/current_driver
```

printing `none`, confirming that the previous ACPI C2/C3 idle states are no
longer active.

## 8. Final checks

Before a benchmark or machine session, check:

```bash
cat /sys/kernel/realtime
cat /proc/cmdline
ethtool -i enp1s0
ip -4 address show enp1s0
ip -6 address
ping -c 3 192.168.1.121
ls -l /usr/bin/rtapi_app
```

Expected essentials are realtime `1`, the isolation parameters above,
`ipv6.disable=1` when the system-wide IPv6 policy is selected, `r8168`, address
`192.168.1.111/24`, no IPv6 addresses, a reachable Mesa card, and setuid
permissions on `rtapi_app`.

Use `../config/README.md` for the normal operating sequence and
`../mesa-benchmark/README.md` for the 1 ms/2 ms benchmark, load
generation, counters, and safety constraints.
