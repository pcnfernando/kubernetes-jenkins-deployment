# Siddhi CI/CD on Kubernetes

The setup consists of Jenkins and spinnaker. It can be deployed on top of Kubernetes and deployed using HELM which makes it easier to configure, install, scale and upgrade (Refer Installation Instructions at the bottom). In addition to the tools, jenkins jobs and spinnaker pipelines for Siddhi are preconfigured, which makes getting started hassle-free.

Use the `jenkins` helm chart to deploy a jenkins instance that could handle the CI/CD operations for Siddhi.

Each environment would have a corresponding Spinnaker pipeline (dev, staging, production). Every new change will be deployed to dev instantly, however the promotion to the staging and above environments needs manual approval which will trigger the pipelines to respective environments.

## Installing and Configuring the CI/CD Chart

### Pre-Install

1. Create a Siddhi Testsuite Git repository containing the Siddhi artifacts. (Refer https://github.com/pcnfernando/siddhi-test-suite) 

### Install

* Download and execute the interactive script `deploy.sh` which creates the HELM deployment of the CI/CD setup based on the provided values.

### Post-Install

* Changes to the CI/CD setup could be triggered by changes to the Siddhi TestSuite repository.

## Considerations

* Nodes in the cluster should have docker installed because the jenkins pod will use the docker installed on the node it's running on.
