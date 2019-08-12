# Jenkins Deployment on Kubernetes

The setup consists of Jenkins and spinnaker. It can be deployed on top of Kubernetes and deployed using HELM which makes it easier to configure, install, scale and upgrade (Refer Installation Instructions at the bottom). In addition to the tools, jenkins jobs and spinnaker pipelines for each specified product are preconfigured, which makes getting started hassle-free.

Use the `jenkins` helm chart to deploy a jenkins instance that could handle the CI/CD operations for Siddhi.

![Drag Racing](docs/resources/diagram.jpg)


The diagram above illustrates the setup. We make use of Spinnaker as a deployment tool and Jenkins as an integration tool.

In order to create or upgrade product deployments, Spinnaker expects a chart and/or docker image(s). These artifacts are provided in the three different flows explained below
1. The HELM chart is stored in a git repository and jenkins polls for changes in the chart. Once change is detected, a predefined jenkins job will build the HELM chart(.tgz) and post it to spinnaker as Webhook.
2. A weekly cron job in Jenkins will build a new docker image from the latest Siddhi image and push it to the private registry in Dockerhub to which Spinnaker will be listening to.
3. The artifact repository contains the docker resources required to build the product docker image. This includes the Dockerfile and artifacts. A change to the repository will trigger a build of a new image based on the weekly image.

Each environment would have a corresponding Spinnaker pipeline (dev, staging, production). Every new change will be deployed to dev instantly, however the promotion to the staging and above environments needs manual approval which will trigger the pipelines to respective environments.

## Installing and Configuring the CI/CD Chart

### Pre-Install

1. Create repositories in Dockerhub for image(s) used in the deployment.
2. Create git repo(s) with the Dockerfiles to build each image.
3. Create a git repo containing the
    * helm chart for deployment
    * Environment specific values files
        * values-dev.yaml
        * values-staging.yaml
        * Values-prod.yaml
    * Secret for the private docker registry
    * Test script

### Install

* Download and execute the interactive script `deploy.sh` which creates the HELM deployment of the CI/CD setup based on the provided values.

### Post-Install

* Changes to the CI/CD setup could be done by modifying the chart and doing an upgrade on the previous HELM deployment.

## Considerations

* Nodes in the cluster should have docker installed because the jenkins pod will use the docker installed on the node it's running on.
