# modified from https://github.com/jaimeps/docker-rl-gym
FROM ubuntu:18.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root


WORKDIR /home
RUN mkdir src
ADD VERSION .

ENV DEBIAN_FRONTEND noninteractive

# Ubuntu packages + Numpy
RUN apt-get update \
     && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        sudo \
        less \
        jed \
        g++  \
        git  \
        gpg \
        curl  \
        cmake \
        zlib1g-dev \
        libjpeg-dev \
        xvfb \
        xorg-dev \
        libboost-all-dev \
        libsdl2-dev \
        dbus \
        swig \
        python3  \
        python3-dev  \
        python3-distutils \
        python3-pip  \
        ffmpeg \
        libopenblas-base  \
#        cython3  \
     && apt-get upgrade -y \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/*

# use python3.6 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1
RUN update-alternatives --config python

# upgrade pip
RUN python -m pip install --upgrade pip setuptools

# Step 1: basic python packages
COPY requirements_py.txt /tmp/
RUN python -m pip install -r /tmp/requirements_py.txt

# Step 2: install Deep Learning packages
# at first delete numpy that doesn't match to tensorflow 1.10.0
#RUN python -m pip uninstall numpy
#COPY requirements_dl.txt /tmp/
#RUN python -m pip install -r /tmp/requirements_dl.txt

# Step 3: install OpenAI Gym
COPY requirements_gym.txt /tmp/
RUN python -m pip install -r /tmp/requirements_gym.txt

# install gridworld
ENV GYMDIR /usr/local/lib/python3.6/dist-packages/gym/envs/
COPY gridworld-gym/env_register.txt /tmp/
RUN cat /tmp/env_register.txt >> ${GYMDIR}/__init__.py
COPY gridworld-gym/envs/mdp_gridworld.py ${GYMDIR}/toy_text/
RUN  echo "from gym.envs.toy_text.mdp_gridworld import MDPGridworldEnv" >> ${GYMDIR}/toy_text/__init__.py

# install gym-maze
RUN mkdir /tmp/gym-maze
COPY gym-maze /tmp/gym-maze
RUN cd /tmp/gym-maze && python setup.py install

# Step 4: install misc packages
RUN python -m pip install dfply

# Step 5: install additional kernel for iPython
RUN pip install bash_kernel
RUN python -m bash_kernel.install 

# Install graphic driver
RUN apt-get install -y libgl1-mesa-dri libglx0 libgl1 --no-install-recommends
RUN dbus-uuidgen > /etc/machine-id

# Copy a script that we will use to correct permissions after running certain commands
COPY scripts/fix-permissions /usr/local/bin
RUN chmod a+rx /usr/local/bin/fix-permissions

# install nbgrader
RUN python -m pip install --upgrade pip
RUN python -m pip install nbgrader
RUN python -m pip install nose
RUN jupyter nbextension install --sys-prefix --py nbgrader --overwrite
RUN jupyter nbextension disable --sys-prefix --py nbgrader
RUN jupyter serverextension disable --sys-prefix --py nbgrader
# https://github.com/jhamrick/plotchecker
RUN python3 -m pip install plotchecker

# Customize jupyter extensions
RUN python -m pip install jupyter-emacskeys \
    jupyter_contrib_nbextensions && \
    jupyter contrib nbextension install --sys-prefix

RUN python -m pip install RISE && \
    jupyter-nbextension install rise --py --sys-prefix

RUN jupyter nbextension enable highlighter/highlighter --sys-prefix
RUN jupyter nbextension enable toggle_all_line_numbers/main --sys-prefix
RUN jupyter nbextension enable hide_header/main --sys-prefix
#RUN jupyter nbextension enable hide_input/main --sys-prefix
RUN jupyter nbextension enable toc2/main --sys-prefix
RUN python -m pip install black
RUN jupyter nbextension install https://github.com/drillan/jupyter-black/archive/master.zip --sys-prefix
RUN jupyter nbextension enable jupyter-black-master/jupyter-black --sys-prefix

ENV DEBIAN_FRONTEND teletype
ENV JUPYTER_ALLOW_INSECURE_WRITES=true

RUN rm -rf "/root/.cache/yarn" && \
    rm -rf "/root/.node-gyp" 

# create user account
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

ENV SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    HOME=/home/$NB_USER
    
RUN export uid=${NB_UID} gid=${NB_GID} && \
    echo "${NB_USER}:x:${NB_UID}:${NB_GID}:Developer,,,:${HOME}:/bin/bash" >> /etc/passwd && \
    echo "${NB_USER}:x:${NB_UID}:" >> /etc/group && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    install -d -m 0755 -o ${NB_UID} -g ${NB_GID} ${HOME} && \
    fix-permissions ${HOME}

# Install tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
#RUN gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
# && gpg --batch --verify /tini.asc /tini
RUN chmod a+rx /tini

# Configure container startup
ENTRYPOINT ["/tini", "-g", "--"]
CMD ["jupyter.sh"]

# Copy local files as late as possible to avoid cache busting
COPY scripts/jupyter.sh /usr/local/bin
COPY scripts/enable-formgrader /usr/local/bin
COPY scripts/aliases.sh /etc/profile.d
RUN chmod a+rx /usr/local/bin/jupyter.sh
RUN chmod a+rx /usr/local/bin/enable-formgrader

# Fix permissions on /etc/jupyter
USER root
RUN mkdir /etc/jupyter/ && \
    fix-permissions /etc/jupyter/

ENV DISPLAY :0.0
VOLUME /tmp/.X11-unix
VOLUME ${HOME}
USER ${NB_USER}
RUN fix-permissions ${HOME}

# Switch to jovyan to avoid accidental container runs as root
USER $NB_UID



WORKDIR $HOME