FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
# Empty password: internal, disposable box, so no key handoff needed
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server sudo python3 python3-apt \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash ansible \
    && passwd -d ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible \
    && echo 'PermitEmptyPasswords yes' > /etc/ssh/sshd_config.d/test-target.conf \
    && mkdir -p /run/sshd

CMD ["/usr/sbin/sshd", "-D", "-e"]
