#!/bin/bash
set -e

source /opt/ros/${ROS_DISTRO}/setup.bash
source /app/install/setup.bash

# `launch-camera` is the default CMD: start camera_ros with DT-style env-var
# driven args and topic remaps. Any other argv is exec'd verbatim, so the
# container can still be used for `ros2 topic list`, shells, etc.
if [ "${1:-}" = "launch-camera" ]; then
    : "${VEHICLE_NAME:?VEHICLE_NAME must be set}"
    WIDTH="${CAMERA_WIDTH:-640}"
    HEIGHT="${CAMERA_HEIGHT:-480}"
    FPS="${CAMERA_FPS:-30}"
    FDL=$((1000000 / FPS))

    # image_transport's "compressed" subchannel does not inherit a remap on
    # its parent topic, so remap it explicitly alongside image_raw.
    exec ros2 run camera_ros camera_node --ros-args \
        -r __ns:=/${VEHICLE_NAME} \
        -r image_raw:=/${VEHICLE_NAME}/image \
        -r image_raw/compressed:=/${VEHICLE_NAME}/image/compressed \
        -r camera_info:=/${VEHICLE_NAME}/camera_info \
        -p width:=${WIDTH} \
        -p height:=${HEIGHT} \
        -p FrameDurationLimits:="[${FDL},${FDL}]"
fi

exec "$@"
