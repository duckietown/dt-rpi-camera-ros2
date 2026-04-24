FROM arm64v8/ros:jazzy

SHELL ["/bin/bash", "-c"]

WORKDIR /app

# libcamera build deps + ROS 2 Zenoh RMW (matches the DT ROS 2 stack)
RUN apt-get update && apt-get install -y --no-install-recommends \
      git python3-pip python3-jinja2 python3-yaml python3-ply \
      meson cmake ninja-build pkg-config \
      libboost-dev \
      libgnutls28-dev openssl libtiff-dev pybind11-dev \
      libglib2.0-dev libgstreamer-plugins-base1.0-dev \
      libyaml-dev libssl-dev libudev-dev libevent-dev libcap-dev \
      libdw-dev libunwind-dev libjpeg-turbo8-dev \
      v4l-utils \
      ros-jazzy-rmw-zenoh-cpp \
    && rm -rf /var/lib/apt/lists/*

# Pinned refs (bump here to upgrade).
# libcamera v0.4.0: last release without the ARM64 Pi IPA serializer regression
# that ships in ros-jazzy-libcamera 0.7.0.
# camera_ros v0.6.0: known-good against libcamera 0.4.x.
ARG LIBCAMERA_REF=v0.4.0
ARG CAMERA_ROS_REF=0.6.0

# Build the Raspberry Pi libcamera fork. Only the vc4 pipeline is enabled
# because the DD24 target is Pi 4; libcamera v0.4.0 predates the pisp
# (Pi 5) pipeline. Bump LIBCAMERA_REF and re-add pisp when we move to Pi 5.
RUN git clone --depth 1 --branch "${LIBCAMERA_REF}" \
        https://github.com/raspberrypi/libcamera.git /tmp/libcamera \
  && cd /tmp/libcamera \
  && meson setup build \
        --buildtype=release \
        -Dpipelines=rpi/vc4 \
        -Dipas=rpi/vc4 \
        -Dv4l2=true \
        -Dgstreamer=enabled \
        -Dtest=false \
        -Dlc-compliance=disabled \
        -Dcam=disabled \
        -Dqcam=disabled \
        -Ddocumentation=disabled \
        -Dpycamera=enabled \
  && ninja -C build install \
  && ldconfig \
  && rm -rf /tmp/libcamera

# Build camera_ros against the libcamera we just installed. --skip-keys=libcamera
# prevents rosdep from pulling the broken ros-jazzy-libcamera apt package.
RUN mkdir -p /app/src \
  && git clone --depth 1 --branch "${CAMERA_ROS_REF}" \
        https://github.com/christianrauch/camera_ros.git /app/src/camera_ros \
  && source /opt/ros/$ROS_DISTRO/setup.bash \
  && cd /app \
  && rosdep update \
  && rosdep install -y --from-paths src --ignore-src \
        --rosdistro $ROS_DISTRO --skip-keys=libcamera \
  && colcon build --event-handlers=console_direct+

COPY docker_entrypoint.sh /app/
RUN chmod +x /app/docker_entrypoint.sh

ENTRYPOINT ["/app/docker_entrypoint.sh"]
CMD ["launch-camera"]
