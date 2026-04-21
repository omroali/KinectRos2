FROM osrf/ros:jazzy-desktop-full

RUN apt-get update && apt-get install -y --no-install-recommends gnupg2 \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F42ED6FBAB17C654

RUN echo "deb http://packages.ros.org/ros2-testing/ubuntu $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/ros2-testing.list

ARG  DEBIAN_FRONTEND=noninteractive
ARG  USERNAME=ros
ARG  UID=1000
ARG  GID=1000

# Handle user creation - Ubuntu 24.04 may have existing user with UID/GID 1000
RUN apt-get update && apt-get install -y sudo git usbutils \
    && (deluser --remove-home ubuntu 2>/dev/null || true) \
    && (delgroup ubuntu 2>/dev/null || true) \
    && (getent group ${GID} || addgroup --gid ${GID} ${USERNAME}) \
    && (getent passwd ${UID} || adduser --uid ${UID} --gid ${GID} --disabled-password --gecos "" ${USERNAME}) \
    && usermod -aG plugdev ${USERNAME} \
    && usermod -aG video ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && (getent group dialout || addgroup dialout) \
    && usermod -a -G dialout ${USERNAME}

ENV BASE_WS=/home/${USERNAME}/base_ws
RUN mkdir -p ${BASE_WS}/src \
    && chown -R ${USERNAME}:${USERNAME} ${BASE_WS}

ENV BASH_SCRIPTS=/home/${USERNAME}/bash_scripts
RUN mkdir -p ${BASH_SCRIPTS} \
    && chown -R ${USERNAME}:${USERNAME} ${BASH_SCRIPTS}

ENV ROSBAG_DIR=/home/${USERNAME}/rosbags
RUN mkdir -p ${ROSBAG_DIR} \
    && chown -R ${USERNAME}:${USERNAME} ${ROSBAG_DIR}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo git build-essential \
    python3 python3-pip python3-venv \
    python3-colcon-common-extensions \
    python3-rosdep python3-rosdep-modules && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    vim nano htop tmux net-tools tree && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ros-jazzy-launch-testing \
    ros-jazzy-tf-transformations \
    ros-jazzy-launch-pytest \
    ros-jazzy-ament-cmake-core \
    ros-jazzy-cv-bridge \
    ros-jazzy-image-transport \
    ros-jazzy-compressed-image-transport \
    ros-jazzy-compressed-depth-image-transport \
    ros-jazzy-message-filters \
    libasio-dev \
    ros-jazzy-joy-linux \
    && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iproute2 can-utils \
    libturbojpeg0-dev \
    libusb-1.0-0-dev \
    libomp-dev \
    libpcap-dev \
    cmake \
    pkg-config \
    freeglut3-dev \
    libglfw3-dev \
    libxmu-dev \
    libxi-dev \
    ocl-icd-opencl-dev \
    opencl-headers \
    ocl-icd-libopencl1 \
    clinfo && \
    rm -rf /var/lib/apt/lists/*

# Install libfreenect2 for Kinect v2 support
RUN git clone https://github.com/OpenKinect/libfreenect2.git /tmp/libfreenect2
WORKDIR /tmp/libfreenect2

# Patch: OpenCL 3.0 headers define CL_ICDL_VERSION as a macro, which collides
# with a local variable of the same name in opencl_depth_packet_processor.cpp.
# Rename the local variable to avoid the preprocessor conflict.
RUN grep -rl 'CL_ICDL_VERSION' src/ | xargs sed -i 's/CL_ICDL_VERSION/FREENECT2_CL_ICDL_VERSION/g'

RUN mkdir build && cd build && \
    cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DENABLE_CXX11=ON \
    -DBUILD_OPENNI2_DRIVER=OFF \
    -DENABLE_OPENCL=ON \
    -DENABLE_CUDA=OFF \
    -DENABLE_OPENGL=ON \
    -DENABLE_VAAPI=OFF \
    -DENABLE_TEGRAJPEG=OFF && \
    make && \
    make install && \
    ldconfig

# Clean up build files
RUN rm -rf /tmp/libfreenect2

# Install Python packages (using --break-system-packages for Ubuntu 24.04)
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    tmule==1.5.9 \
    pyserial
    # setuptools \
    # packaging \
    # tmule \

USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN sed -i 's/^#\(force_color_prompt\)/\1/' /home/${USERNAME}/.bashrc

RUN echo '[ -f $HOME/bash_scripts/bashrc_extensions.sh ] && \
    source $HOME/bash_scripts/bashrc_extensions.sh' \
    >> /home/${USERNAME}/.bashrc

CMD ["bin/bash"]
