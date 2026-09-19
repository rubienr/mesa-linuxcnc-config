# LinuxCNC operating scripts

This directory applies and checks the tested CPU/IRQ layout and starts an
explicitly selected LinuxCNC INI file. IRQ numbers are discovered dynamically
because they can change at boot.

| Logical CPU | Intended use |
| --- | --- |
| 0, 1, 3, 4, 6, 7, 9, 10 | Housekeeping, desktop, stress workers, and Wi-Fi IRQs |
| 2 | Keep idle; SMT sibling of the Mesa IRQ CPU |
| 5 | Kernel-isolated and idle; SMT sibling of the servo CPU |
| 8 | Mesa Ethernet IRQ |
| 11 | LinuxCNC FIFO servo thread |

The affinity checker requires Wi-Fi IRQs to stay away from CPUs 2, 5, 8, and
11. CPU 5 and 11 are kernel-isolated; CPU 2 and 8 are reserved operationally
by the affinity and stress scripts.

> **Machine-safety warning:** The included benchmark explicitly commands its
> stepgen enables and isolated SSR outputs false, but it is not a validated
> machine configuration or a safety system. Do not use it while drives,
> spindle control, or other hazardous outputs are wired and energized. Use a
> hard E-stop and remove actuator power before configuration testing.

## Normal sequence

Apply network IRQ affinity once after each boot:

```bash
sudo ./set-thread-affinity.sh
```

The launcher intentionally has no default INI. Name the configuration so the
benchmark cannot be started accidentally on a connected machine:

```bash
LIBGL_ALWAYS_SOFTWARE=0 ./start-linuxcnc.sh \
    ../mesa-7i95t-benchmark/mesa-7i95t-bench-1ms.ini
```

Once LinuxCNC is open, rerun the setter so it can pin the newly created FIFO
thread, then verify everything:

```bash
sudo ./set-thread-affinity.sh
./check-thread-affinity.sh
```

Pass the production machine's INI path instead when that configuration is
ready and has been safety-checked:

```bash
LIBGL_ALWAYS_SOFTWARE=0 ./start-linuxcnc.sh /path/to/machine.ini
```

`LIBGL_ALWAYS_SOFTWARE=0` selects the normal hardware-rendered path. If AXIS
crashes because of a GPU/driver problem, retry diagnostically with software
rendering:

```bash
LIBGL_ALWAYS_SOFTWARE=1 ./start-linuxcnc.sh /path/to/config.ini
```

Software rendering increases CPU load and can worsen realtime latency, so
repeat the Mesa and servo checks before relying on that mode.

The scripts accept `LAN_INTERFACE`, `WIFI_INTERFACE`, `LAN_IRQ_CPU`, and
`SERVO_CPU` overrides, but the defaults match this computer and the kernel
parameters documented in `../archlinux/README.md`.

