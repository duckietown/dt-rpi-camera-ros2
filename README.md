# dt-rpi-camera-ros2

Raspberry Pi CSI camera driver for the Duckietown ROS 2 stack. Runs
[`camera_ros`](https://github.com/christianrauch/camera_ros/) inside an
`arm64v8/ros:jazzy` container with the Raspberry Pi fork of `libcamera`
built from source.

Forked from [nguyen-v/camera_rpi5_ros2_docker](https://github.com/nguyen-v/camera_rpi5_ros2_docker).
Changes:

- Pinned `libcamera` to `v0.4.0` and `camera_ros` to `v0.6.0`.
- Added `ros-jazzy-rmw-zenoh-cpp` so it speaks to the rest of the DT ROS 2
  stack via Zenoh.
- DT-style entrypoint driven by `VEHICLE_NAME`, `CAMERA_WIDTH`,
  `CAMERA_HEIGHT`, `CAMERA_FPS`, with explicit topic remaps
  (including `image_raw/compressed` — it does not inherit from
  `image_raw` via image_transport).

Why not `apt install ros-jazzy-camera-ros`? That package depends on
`ros-jazzy-libcamera 0.7.0`, whose Raspberry Pi IPA proxy has an ARM64
serializer regression that crashes before the first frame
(`FATAL ControlSerializer: A list of V4L2 controls requires a ControlInfoMap`).
Ubuntu Noble's stock `libcamera 0.2` has an OV5647 `prepareIsp()` IPA bug.
Building the Pi fork from source is currently the only reliable path.

## Hardware

Tested on DD24 (Raspberry Pi 4, OV5647). Only the `vc4` libcamera
pipeline is enabled; add `rpi/pisp` and bump `LIBCAMERA_REF` when we
need Pi 5 support.

## Build

On the target Pi (or any arm64 host):

```
docker build -t duckietown/dt-rpi-camera-ros2:ente-arm64v8 .
```

## Run

Published topics (with `VEHICLE_NAME=drone01`):

- `/drone01/image` (raw)
- `/drone01/image/compressed`
- `/drone01/camera_info`

Typical invocation via the DT ROS 2 duckiedrone stack:

```yaml
camera:
  image: ${REGISTRY}/duckietown/dt-rpi-camera-ros2:ente-${ARCH}
  container_name: ros2-camera
  restart: unless-stopped
  network_mode: host
  privileged: true
  environment:
    VEHICLE_NAME: ${ROBOT_NAME}
    ROS_DOMAIN_ID: 42
    RMW_IMPLEMENTATION: rmw_zenoh_cpp
  volumes:
    - /dev:/dev
    - /run/udev:/run/udev:ro
  depends_on:
    - zenoh-router
```

Environment variables honored by the entrypoint:

| Variable | Default | Notes |
|---|---|---|
| `VEHICLE_NAME` | _(required)_ | Used as topic namespace |
| `CAMERA_WIDTH` | `640` | |
| `CAMERA_HEIGHT` | `480` | |
| `CAMERA_FPS` | `30` | Applied via `FrameDurationLimits` |

Override by passing a different `CMD` (the entrypoint execs any argv that
isn't the literal `launch-camera`).

## References

- [christianrauch/camera_ros](https://github.com/christianrauch/camera_ros/)
- [raspberrypi/libcamera](https://github.com/raspberrypi/libcamera/)
- Jira: DTSW-7758
