FROM jenkins/jenkins:lts
USER root

#Pre-Install Jenkins Plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

# Installing Docker
RUN apt-get update && apt-get install software-properties-common apt-transport-https ca-certificates -y; \
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -;\
add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/debian  $(lsb_release -cs) stable";\
apt-get update && apt-get install docker-ce -y

# Installing kubectl from Docker
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -;\
touch /etc/apt/sources.list.d/kubernetes.list;\
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list;\
apt-get update && apt-get install -y kubectl

# Installing utils for reverese DNS lookup
RUN apt-get install knot-dnsutils -y
RUN kdig
# Installing maven
RUN apt-get install maven -y
RUN mvn -v

# Install helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh

RUN wget https://www-us.apache.org/dist//jmeter/binaries/apache-jmeter-5.1.tgz
RUN tar -C /usr/local -xzf apache-jmeter-5.1.tgz
ENV PATH="/usr/local/apache-jmeter-5.1/bin:${PATH}"

# Grant jenkins user group access to /var/run/docker.sock
RUN addgroup --gid 1001 dsock
RUN gpasswd -a jenkins dsock

RUN usermod -aG sudo jenkins

# USER JENKINS
