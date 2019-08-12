FILE=$1
cat >$FILE <<"EOF"
#!/bin/bash

# ------------------------------------------------------------------------
# Copyright 2017 WSO2, Inc. (http://Siddhi.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------

set -e

ECHO=`which echo`

# methods
function echoBold () {
  echo -en  $'\e[1m'"${1}"$'\e[0m'
}

function err_exit(){
    msg=$@
    echoBold "ERROR: ${msg}"
    exit 1
}

function print_notice() {
  echo ""
  echoBold "$1\n"
}

echoBold "==========================\n"
echoBold "siddhi CI/CD Setup Provider\n"
echoBold "==========================\n"
echo "Follow this script to generate and deploy the HELM chart for Siddhi CI/CD setup along with a customized values.yaml file generated based on the input provided in this script."


if [[ ! $(which helm) ]]
then
    err_exit "Please install Kubernetes HELM and initialize the cluster with tiller before you start the setup\n"
fi

EOF

for entry in $(find siddhi-cd ! -name '.*'); do
  if test -f $entry; then
    filecontent=$(cat $entry)
    echo "cat > $entry << \"EOF\"" >>$FILE
    echo "$filecontent" >>$FILE
    echo "EOF" >>$FILE
    echo "" >>$FILE
  else
    echo "mkdir $entry" >>$FILE
    echo "" >>$FILE
  fi
done

cat >>$FILE <<"EOF"
cat > app.yaml << "EOF"
applications:
  - name: APP_NAME
    email: EMAIL
    testScript:
      path: TEST_PATH
      command: TEST_COMMAND
    chart:
      name: CHART_NAME
      repo: 'CHART_REPO'
    images:
      - siddhiImage: 'siddhi_IMAGE'
        organization: ORGANIZATION
        repository: REPOSITORY
        gitRepo: 'GIT_REPO'
EOF

echo "EOF" >>$FILE

cat >>$FILE <<"EOF"

replaceTag() {
    sed -i '' "s|$1|$2|" siddhi-cd/values.yaml
}

if [ "$1" != "" ]; then
  siddhi_SUBSCRIPTION_USERNAME=$1
  siddhi_SUBSCRIPTION_PASSWORD=$2
  REGISTRY_USERNAME=$3
  REGISTRY_PASSWORD=$4
  REGISTRY_EMAIL=$5
  JENKINS_USERNAME=$6
  JENKINS_PASSWORD=$7
  GITHUB_USERNAME=$8
  GITHUB_PASSWORD=$9
else
  print_notice "Siddhi Subscription credentials"
  read -p "Enter Your Siddhi Username: " Siddhi_SUBSCRIPTION_USERNAME
  read -s -p "Enter Your Siddhi Password: " Siddhi_SUBSCRIPTION_PASSWORD
  ${ECHO}
  print_notice "Docker registry credentials"

  read -p "Enter Your Registry Username: " REGISTRY_USERNAME
  read -s -p "Enter Your Registry Password: " REGISTRY_PASSWORD
  ${ECHO}
  read -p "Enter Your Registry Email: " REGISTRY_EMAIL

  print_notice "Jenkins credentials for the admin user to be created."
  read -p "Enter Your Jenkins username: " JENKINS_USERNAME
  read -s -p "Enter Your Jenkins password: " JENKINS_PASSWORD
  ${ECHO}

  print_notice "Github credentials are required to access the repositories used in the setup"
  read -p "Enter Your Github username: " GITHUB_USERNAME
  read -s -p "Enter Your Github password: " GITHUB_PASSWORD
  ${ECHO}
fi

replaceTag "<Siddhi_SUBSCRIPTION_USERNAME>" "$Siddhi_SUBSCRIPTION_USERNAME"
replaceTag "<Siddhi_SUBSCRIPTION_PASSWORD>" "$Siddhi_SUBSCRIPTION_PASSWORD"
replaceTag "<REGISTRY_USERNAME>" "$REGISTRY_USERNAME"
replaceTag "<REGISTRY_PASSWORD>" "$REGISTRY_PASSWORD"
replaceTag "<REGISTRY_EMAIL>" "$REGISTRY_EMAIL"
replaceTag "<JENKINS_USERNAME>" "$JENKINS_USERNAME"
replaceTag "<JENKINS_PASSWORD>" "$JENKINS_PASSWORD"
replaceTag "<GITHUB_USERNAME>" "$GITHUB_USERNAME"
replaceTag "<GITHUB_PASSWORD>" "$GITHUB_PASSWORD"

print_notice "Jenkins and spinnaker pipelines could also be preconfigured."
read -p "Do you want to create pipelines for an application?(N/y)" -n 1 -r
${ECHO}

if [[ ${REPLY} =~ ^[Yy]$ ]]; then

  read -p "Uniqe name for you application: " APP_NAME

  read -p "Url for the git repo containing the chart: " CHART_REPO
  read -p "Name of the chart (folder with same name should be present at the root of the repository): " CHART_NAME

  read -p "Path to the test script within the git repository(excluding the filename): " TEST_PATH
  read -p "Test file name at the given path : " TEST_COMMAND

  read -p "Siddhi image: " Siddhi_IMAGE
  read -p "Docker organization: " ORGANIZATION
  read -p "Docker repository: " REPOSITORY
  read -p "Git repository containing the docker resources: " GIT_REPO

  function replaceValues() {
      sed "s|$1|$2|"
  }

  echo "" >> Siddhi-cd/values.yaml
  cat app.yaml |
  replaceValues APP_NAME $APP_NAME |
  replaceValues TEST_PATH $TEST_PATH |
  replaceValues TEST_COMMAND $TEST_COMMAND |
  replaceValues CHART_NAME $CHART_NAME |
  replaceValues CHART_REPO $CHART_REPO |
  replaceValues Siddhi_IMAGE $Siddhi_IMAGE |
  replaceValues ORGANIZATION $ORGANIZATION |
  replaceValues REPOSITORY $REPOSITORY |
  replaceValues GIT_REPO $GIT_REPO |
  replaceValues EMAIL $Siddhi_SUBSCRIPTION_USERNAME >> Siddhi-cd/values.yaml

  DATA="- $ORGANIZATION/$REPOSITORY"
  cat Siddhi-cd/values.yaml | sed "s|<REPOSITORIES>|${DATA}<REPOSITORIES>|" |
  sed 's|<REPOSITORIES>|\
          <REPOSITORIES>|g' > Siddhi-cd/values2.yaml
  rm Siddhi-cd/values.yaml
  mv Siddhi-cd/values2.yaml Siddhi-cd/values.yaml

fi

replaceTag "<REPOSITORIES>" ""

print_notice "Siddhi-cd/values.yaml created"

cd Siddhi-cd


print_notice "Building chart dependencies..."
helm dependency build

print_notice "Deploying the helm chart..."
# helm upgrade Siddhi-cd . -f values.yaml --install --namespace Siddhi-cd

print_notice "Siddhi CI/CD chart generated and deployed. Further changes could be made by modifying the chart Siddhi-cd and upgrading."
EOF
