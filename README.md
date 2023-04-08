# armbian-onecloud
[![build](https://img.shields.io/github/actions/workflow/status/hzyitc/armbian-onecloud/ci.yml)](https://github.com/hzyitc/armbian-onecloud/actions/workflows/ci.yml) [![downloads](https://img.shields.io/github/downloads/hzyitc/armbian-onecloud/total)](https://github.com/hzyitc/armbian-onecloud/releases) [![downloads@latest](https://img.shields.io/github/downloads/hzyitc/armbian-onecloud/latest/total)](https://github.com/hzyitc/armbian-onecloud/releases/latest)

[README](README.md) | [中文文档](README_zh.md)

**All modifications have been submitted to [the official repository](https://github.com/armbian/build) and you can directly use the official repository for compilation.**

## First-time login

Hostname: `onecloud`

Username: `root`

Password: `1234`

## Build parameters

### `BOARD`=`onecloud`

### `BRANCH`={`edge`,`current`}

| BRANCH    | KERNEL VERSION | eMMC | HDMI | VPU |
| :-:       | :-:            | :-:  | :-:  | :-: |
| `edge`    | `v6.2`         | ✔️¹  | ✔️² | ✔️² |
| `current` | `v6.1`         | ✔️¹  | ✔️² | ✔️² |

> ¹: Patch required
>
> ²: Support through patching

## Boot from `u-boot` 

### Boot from `USB`

```
setenv bootdev "usb 0"
usb start
fatload ${bootdev} 0x20800000 boot.scr && autoscr 0x20800000
```

### Boot from `eMMC`

```
setenv bootdev "mmc 1"
fatload ${bootdev} 0x20800000 boot.scr && autoscr 0x20800000
```

## GPIO

There is a missing 44-pins chip on the board (presumably for a WiFi module) which has many pins directly connected to the `SoC`. They are able to be used as `GPIO`.

Please check the `dts` (added by `patch/kernel/meson-{edge,current}/onecloud-0001-add-dts.patch`) for specific definitions.

NOTE: These pins in the `dts` were measured on `V1.0 board` and have not been verified on the V1.3 board.

## Related link

[`armbian/build`](https://github.com/armbian/build) - Armbian official repository

[`xdarklight/linux@meson-mx-integration-5.18-20220417`](https://github.com/xdarklight/linux/tree/meson-mx-integration-5.18-20220417) - the source code of `HDMI` patch

[`S805_Datasheet V0.8 20150126.pdf`](https://dn.odroid.com/S805/Datasheet/S805_Datasheet%20V0.8%2020150126.pdf) - S805 datasheet
