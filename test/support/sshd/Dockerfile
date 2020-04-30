FROM ubuntu:18.04

RUN apt-get update && apt-get install -y openssh-server

RUN mkdir /var/run/sshd

RUN adduser --disabled-password --gecos "" deploy && \
    echo "deploy:test" | chpasswd

RUN echo "AllowUsers deploy" >> /etc/ssh/sshd_config

COPY id_rsa.pub id_rsa.pub

RUN mkdir /home/deploy/.ssh && cat id_rsa.pub >> "/home/deploy/.ssh/authorized_keys"

CMD ["/usr/sbin/sshd", "-D"]
