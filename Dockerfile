# modified from https://github.com/jaimeps/docker-rl-gym
FROM ubuntu:18.04

WORKDIR /home
RUN mkdir src
#ADD VERSION .

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
RUN sudo update-alternatives --config python

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

# create user account
ENV USER jovyan
ENV HOME /home/${USER}
RUN export uid=1000 gid=1000 &&\
    echo "${USER}:x:${uid}:${gid}:Developer,,,:${HOME}:/bin/bash" >> /etc/passwd &&\
    echo "${USER}:x:${uid}:" >> /etc/group &&\
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&\
    install -d -m 0755 -o ${uid} -g ${gid} ${HOME}
WORKDIR ${HOME}

# Install some scripts
COPY jupyter.sh /usr/bin
COPY aliases.sh /etc/profile.d

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
RUN python -m pip install jupyter-emacskeys
RUN python -m pip install jupyter_contrib_nbextensions
RUN jupyter contrib nbextension install --sys-prefix

RUN python -m pip install RISE
RUN jupyter-nbextension install rise --py --sys-prefix

RUN jupyter nbextension enable highlighter/highlighter --sys-prefix
RUN jupyter nbextension enable toggle_all_line_numbers/main --sys-prefix
RUN jupyter nbextension enable hide_header/main --sys-prefix
#RUN jupyter nbextension enable hide_input/main --sys-prefix
RUN jupyter nbextension enable toc2/main --sys-prefix
RUN python -m pip install black
RUN jupyter nbextension install https://github.com/drillan/jupyter-black/archive/master.zip --sys-prefix
RUN jupyter nbextension enable jupyter-black-master/jupyter-black --sys-prefix

ENV DEBIAN_FRONTEND teletype

# X
ENV DISPLAY :0.0
VOLUME /tmp/.X11-unix
VOLUME ${HOME}
USER ${USER}

#CMD [ "/bin/bash" ]

# Jupyter notebook with virtual frame buffer
CMD cd ${HOME} \
    && xvfb-run -s "-screen 0 1024x768x24" \
    /usr/local/bin/jupyter notebook \
    --port=8888 --ip=0.0.0.0 --allow-root 



