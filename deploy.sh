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
echoBold "Siddhi CI/CD Setup Provider\n"
echoBold "==========================\n"
echo "Follow this script to generate and deploy the HELM chart for Siddhi CI/CD setup along with a customized values.yaml file generated based on the input provided in this script."


if [[ ! $(which helm) ]]
then
    err_exit "Please install Kubernetes HELM and initialize the cluster with tiller before you start the setup\n"
fi

mkdir -p siddhi-cd

cat > siddhi-cd/requirements.yaml << "EOF"
dependencies:
- name: spinnaker
  version: 1.8.1
  repository: https://kubernetes-charts.storage.googleapis.com
  condition: redis.enabled
- name: docker-registry
  version: 1.8.0
  repository: https://kubernetes-charts.storage.googleapis.com
EOF

cat > siddhi-cd/Chart.yaml << "EOF"
apiVersion: v1
appVersion: "1.0"
description: Jenkins chart for CI/CD pipeline
name: siddhi-cd
version: 0.1.0
EOF

mkdir -p siddhi-cd/charts

mkdir -p siddhi-cd/templates

cat > siddhi-cd/templates/deployment.yaml << "EOF"
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: jenkins
  labels:
    app: jenkins
spec:
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: jenkins
        tier: jenkins
    spec:
      serviceAccountName: jenkins
      initContainers:
      - image: alpine/helm:2.9.0
        name: helm-config
        command: ["/bin/sh"]
        args: ["-c", "helm init --client-only"]
        volumeMounts:
        - name: helm-conf
          mountPath: "/root/.helm"
      containers:
      - image: {{ .Values.image }}
        name: jenkins
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=false"
        - name: SIDDHI_USERNAME
          valueFrom:
            secretKeyRef:
              name: Siddhi-credentials
              key: username
        - name: Siddhi_PASSWORD
          valueFrom:
            secretKeyRef:
              name: Siddhi-credentials
              key: password
        - name: REGISTRY_SERVER
          valueFrom:
            secretKeyRef:
              name: registry-credentials-pod
              key: server
        - name: REGISTRY_USERNAME
          valueFrom:
            secretKeyRef:
              name: registry-credentials-pod
              key: username
        - name: REGISTRY_PASSWORD
          valueFrom:
            secretKeyRef:
              name: registry-credentials-pod
              key: password
        - name: GITHUB_USERNAME
          valueFrom:
            secretKeyRef:
              name: github-credentials
              key: username
        - name: GITHUB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: github-credentials
              key: password
        - name: CASC_JENKINS_CONFIG
          value: "/var/casc_configs"
        imagePullPolicy: Always
        readinessProbe:
          periodSeconds: 10
          httpGet:
            path: "/login"
            port: 8080
        livenessProbe:
          periodSeconds: 10
          initialDelaySeconds: 300
          httpGet:
            path: "/login"
            port: 8080
        securityContext:
          runAsUser: 0
        volumeMounts:
        - name: docker
          mountPath: /var/run/docker.sock
        - name: jenkins-persistent-storage
          mountPath: /var/jenkins_home
        - name: Siddhi-credentials
          mountPath: /Siddhicreds
        - name: jenkins-casc-conf
          mountPath: /var/casc_configs
        - name: helm-conf
          mountPath: "/root/.helm"
        ports:
        - containerPort: 8080
          name: jenkins
          protocol: TCP
      volumes:
      - name: docker
        hostPath:
          path: /var/run/docker.sock
      - name: jenkins-persistent-storage
        persistentVolumeClaim:
          claimName: jenkins-claim
      - name: Siddhi-credentials
        secret:
          secretName: Siddhi-credentials
      - name: jenkins-casc-conf
        configMap:
          name: jenkins-casc-conf
      - name: helm-conf
        emptyDir: {}
EOF

cat > siddhi-cd/templates/kube-conf.yaml << "EOF"
# Copyright (c) 2018, Siddhi Inc. (http://www.Siddhi.org) All Rights Reserved.
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
# limitations under the License.

apiVersion: v1
kind: Secret
metadata:
  name: kube-conf
type: Opaque
stringData:
  config: |-
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURERENDQWZTZ0F3SUJBZ0lSQU9EZGpFMWJ6d0M2a1NyUzRvSTBZRVl3RFFZSktvWklodmNOQVFFTEJRQXcKTHpFdE1Dc0dBMVVFQXhNa01UWXdNak5sTmpjdE1XRTVOQzAwTURSa0xXRTRNR0l0WWpZMU16RTNOR000TURnMwpNQjRYRFRFNU1ERXpNREF6TVRBeE0xb1hEVEkwTURFeU9UQTBNVEF4TTFvd0x6RXRNQ3NHQTFVRUF4TWtNVFl3Ck1qTmxOamN0TVdFNU5DMDBNRFJrTFdFNE1HSXRZalkxTXpFM05HTTRNRGczTUlJQklqQU5CZ2txaGtpRzl3MEIKQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBeWNodng4R3BFcUFTaEZTTDhaTE9XZTZTclBTL1Vhd2w2bW5MZ3lrUwpJR2xoWUFrZ2tsSmtVcGREdzZMeTVkM1dvYk1zckI3cFJFUWtXOUdxN1JvclBUdmtJazZiN2tWMEpvaXVmK1NMCjR2VHV0VElzQ2ZLRGNJRjVuZU1mTWFMWjE1UGRWUit6bHB1OXNLQ29uM2QvdTJrRFNOTlJsdElNcUZybHJPekwKVDZXcjJYVUVzdnYxOE5YVlIxL0hvakRWTE9YWmQ4T0VybDROT0tZbnExVmdnK0gwRVQwNDRKYnJwVGxQN3h2bwpERDVQeEtqcjI5QmJFNHhOQWM5ZG51M2FvMWNGNUZJNlR1MHJPajRFeWcwQ0laUmVuUDV3NFZuL3FhUHBsLzBzCmY1aW5YK2syNDdTaUNSV29wV0twMllIand3Nm43UUlLVHNNUGJSZVlNRzFvSHdJREFRQUJveU13SVRBT0JnTlYKSFE4QkFmOEVCQU1DQWdRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQppM0dDTUI2U3NXdVY0TWlNSmhjQUt5YUdueDJiNUhZZmZlVitscWFZd3ZiaWovamt6T3lYV1Y3d3NoOEdzUi9NCldKQ2pia1JQWXZGZEhXbFNxOFc4NWVQWHJLUnVITTVTN2lxbmFnd25xanVUbnJiK0VTTVVkcS9BTlBGODJhaTUKU0RBL0EvczJRL2FRNU1YdWp0UjVvT3ZUSmxHV0hVbTQ3TFRSUDNkU3Nvdk5LTmpyYlY4ZWlDMTZtb2FiaHZwRApyaWw4Wlc5WnB5ZlJFbmFLNXZPbDBhYWo1am9JNDhuR0hkV0hMbmpyV3ZFc3lFYkFSdkVQemRMWlVPcnpvbGk1Cml4R1YyR0FoNEY3NEhIM0kxdDE3UTVpL3BQNmpCeWxiSUpaMDBkWUlpSlQ4aFpxc0xFcTZCbUZ3ZUZENXdLZEMKSE15cFAvaDRCZDJFREJxYU5xUWhLdz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
        server: https://35.193.151.235
      name: id-cd
    contexts:
    - context:
        cluster: id-cd
        namespace: default
        user: staging-admin
      name: staging
    current-context: staging
    kind: Config
    preferences: {}
    users:
    - name: staging-admin
      user:
        password: fJrsRVDUyagmRjiy
        username: admin
EOF

cat > siddhi-cd/templates/spinnaker-pipeline-creator.yaml << "EOF"
apiVersion: batch/v1
kind: Job
metadata:
  name: spinnaker-pipeline-creator
  annotations:
    "helm.sh/hook": "post-install,post-upgrade"
    "helm.sh/hook-delete-policy": "before-hook-creation"
    "helm.sh/hook-weight": "0"
spec:
  template:
    spec:
      initContainers:
      # initContainer that waits for spinnaker gate API to be ready
      - name: wait-for-spin-gate
        image: aaquiff/spin
        command: ["/bin/sh"]
        args: ["-c", "until spin application list --gate-endpoint $SPINNAKER_API; do echo 'Request to spin-gate failed. Retrying in 5s'; sleep 5; done;"]
        env:
        - name: SPINNAKER_API
          value: "http://spin-gate.{{ .Release.Namespace }}.svc.cluster.local:8084"
      containers:
      - name: spin
        image: aaquiff/spin
        command: ["/bin/sh"]
        args: ["-c", "sh /spinnaker/run.sh"]
        env:
        - name: SPINNAKER_API
          value: "http://spin-gate.{{ .Release.Namespace }}.svc.cluster.local:8084"
        volumeMounts:
        - name: spinnaker-conf
          mountPath: /spinnaker
      restartPolicy: Never
      volumes:
      - name: spinnaker-conf
        configMap:
          name: spinnaker-conf

---

{{- $root := . -}}
{{- $files := .Files }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: spinnaker-conf
data:
  run.sh: |-
    cd spinnaker
    {{- range .Values.applications }}
    spin applications save spintest --file {{ .name }}.json --gate-endpoint $SPINNAKER_API && \

    spin pipeline save -f {{ .name }}-deploy-production.json --gate-endpoint $SPINNAKER_API && \
    id=`spin pipelines get --application {{ .name }} --name "Deploy Production" --output=jsonpath={.id} --gate-endpoint $SPINNAKER_API` && \

    sed "s|<DEPLOY_PRODUCTION_ID>|$id|" {{ .name }}-deploy-staging.json > ../{{ .name }}-deploy-staging.json && \
    spin pipeline save -f ../{{ .name }}-deploy-staging.json --gate-endpoint $SPINNAKER_API && \
    id=`spin pipelines get --application {{ .name }} --name "Deploy Staging" --output=jsonpath={.id} --gate-endpoint $SPINNAKER_API` && \

    sed "s|<DEPLOY_STAGING_ID>|$id|" {{ .name }}-deploy-dev.json > ../{{ .name }}-deploy-dev.json && \
    spin pipeline save -f ../{{ .name }}-deploy-dev.json --gate-endpoint $SPINNAKER_API && \
    id=`spin pipelines get --application {{ .name }} --name "Deploy Dev" --output=jsonpath={.id} --gate-endpoint $SPINNAKER_API` && \

    sed "s|<DEPLOY_DEV_ID>|$id|" {{ .name }}-bake-artifacts.json > ../{{ .name }}-bake-artifacts.json && \
    spin pipeline save -f ../{{ .name }}-bake-artifacts.json --gate-endpoint $SPINNAKER_API
    {{- end }}
  {{- range .Values.applications }}
  {{- $application := . }}
  {{ .name }}.json: |-
    {
      "cloudProviders": "kubernetes",
      "email": "{{ .email }}",
      "lastModifiedBy": "anonymous",
      "name": "{{ .name }}",
      "trafficGuards": [],
      "user": "[anonymous]"
    }

  {{ .name }}-bake-artifacts.json: |-
    {
      "application": "{{ .name }}",
      "name": "Bake Manifests",
      "expectedArtifacts": [
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "56330e63-2a3a-4979-a432-043e0c653685"
              },
              "displayName": "chart",
              "id": "4397cbfc-50f8-4244-b721-2a35d8e04715",
              "matchArtifact": {
                  "id": "7f76f43f-37fd-4410-81f2-c1acd4cf8422",
                  "name": "{{ .chart.name }}-.*\\.tgz",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": true
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "1db24043-0cd0-4511-b645-e4fa7f52a689"
              },
              "displayName": "values-dev.yaml",
              "id": "aec2c4f1-2cb2-4d50-962a-dedc2a7457e0",
              "matchArtifact": {
                  "id": "d98b429d-0a8e-4c3e-87d1-d57974f0c6ae",
                  "name": "values-dev.yaml",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": true
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "6525a786-41fc-448b-b675-9e0386007d95"
              },
              "displayName": "values-staging.yaml",
              "id": "d08add4b-ccdb-49fd-bc79-299bb47ddc10",
              "matchArtifact": {
                  "id": "853945fb-a1f7-46a3-9707-8feb76ed01c9",
                  "name": "values-staging.yaml",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": true
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "3b6e0f4b-df2f-4434-a081-b000c0b08c00"
              },
              "displayName": "values-prod.yaml",
              "id": "14234aae-38d8-424b-9d11-76cbade0e194",
              "matchArtifact": {
                  "id": "c2ec0634-256c-4ab9-8f81-f1d67ebf6280",
                  "name": "values-prod.yaml",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": true
          }
        {{- range $index, $image := .images }}
        {{- $imageName := printf "%s/%s/%s" $root.Values.registry.address $image.organization $image.repository }}
          ,{
              "defaultArtifact": {
                  "id": "beebe844-426d-46ee-9a9f-b13eeb251717",
                  "name": "{{- $imageName}}",
                  "reference": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "displayName": "{{- $imageName}}",
              "id": "{{ $index }}",
              "matchArtifact": {
                  "id": "a8417d7f-2fa1-4d7b-a06b-e9610d5604fa",
                  "name": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "useDefaultArtifact": true,
              "usePriorArtifact": true
          }
        {{- end }}
      ],
      "keepWaitingPipelines": false,
      "lastModifiedBy": "anonymous",
      "limitConcurrent": true,
      "stages": [
          {
              "evaluateOverrideExpressions": false,
              "expectedArtifacts": [
                  {
                      "defaultArtifact": {},
                      "displayName": "dev-chart",
                      "id": "226a10b2-fa11-4ac0-813e-a4556d574721",
                      "matchArtifact": {
                          "kind": "base64",
                          "name": "dev-chart",
                          "type": "embedded/base64"
                      },
                      "useDefaultArtifact": false
                  }
              ],
              "inputArtifacts": [
                  {
                      "account": "embedded-artifact",
                      "id": "4397cbfc-50f8-4244-b721-2a35d8e04715"
                  },
                  {
                      "account": "embedded-artifact",
                      "id": "aec2c4f1-2cb2-4d50-962a-dedc2a7457e0"
                  }
              ],
              "name": "Bake (Manifest) Dev",
              "namespace": "{{ .name }}-dev",
              "outputName": "dev",
              "overrides": {
                  "password": "{{ $root.Values.registry.password }}",
                  "registry": "{{ $root.Values.registry.address }}",
                  "username": "{{ $root.Values.registry.username }}"
              },
              "refId": "1",
              "requisiteStageRefIds": [],
              "templateRenderer": "HELM2",
              "type": "bakeManifest"
          },
          {
              "evaluateOverrideExpressions": false,
              "expectedArtifacts": [
                  {
                      "defaultArtifact": {},
                      "displayName": "production-chart",
                      "id": "c5dfdee9-9b49-40a1-a241-9bb48a1284aa",
                      "matchArtifact": {
                          "kind": "base64",
                          "name": "production-chart",
                          "type": "embedded/base64"
                      },
                      "useDefaultArtifact": false
                  }
              ],
              "inputArtifacts": [
                  {
                      "account": "embedded-artifact",
                      "id": "4397cbfc-50f8-4244-b721-2a35d8e04715"
                  },
                  {
                      "account": "embedded-artifact",
                      "id": "14234aae-38d8-424b-9d11-76cbade0e194"
                  }
              ],
              "name": "Bake (Manifest) Prod",
              "namespace": "{{ .name }}-prod",
              "outputName": "prod",
              "overrides": {
                  "password": "{{ $root.Values.registry.password }}",
                  "registry": "{{ $root.Values.registry.registry }}",
                  "username": "{{ $root.Values.registry.username }}"
              },
              "refId": "3",
              "requisiteStageRefIds": [],
              "templateRenderer": "HELM2",
              "type": "bakeManifest"
          },
          {
              "evaluateOverrideExpressions": false,
              "expectedArtifacts": [
                  {
                      "defaultArtifact": {},
                      "displayName": "staging-chart",
                      "id": "8146fe52-8dd8-4a6b-bf04-c3ee66f63193",
                      "matchArtifact": {
                          "kind": "base64",
                          "name": "staging-chart",
                          "type": "embedded/base64"
                      },
                      "useDefaultArtifact": false
                  }
              ],
              "inputArtifacts": [
                  {
                      "account": "embedded-artifact",
                      "id": "4397cbfc-50f8-4244-b721-2a35d8e04715"
                  },
                  {
                      "account": "embedded-artifact",
                      "id": "d08add4b-ccdb-49fd-bc79-299bb47ddc10"
                  }
              ],
              "name": "Bake (Manifest) Staging",
              "namespace": "{{ .name }}-staging",
              "outputName": "staging",
              "overrides": {
                  "password": "{{ $root.Values.registry.password }}",
                  "registry": "{{ $root.Values.registry.address }}",
                  "username": "{{ $root.Values.registry.username }}"
              },
              "refId": "8",
              "requisiteStageRefIds": [],
              "templateRenderer": "HELM2",
              "type": "bakeManifest"
          },
          {
              "application": "{{ .name }}",
              "failPipeline": true,
              "name": "Pipeline",
              "pipeline": "<DEPLOY_DEV_ID>",
              "refId": "7",
              "requisiteStageRefIds": [
                  "1",
                  "3",
                  "8"
              ],
              "type": "pipeline",
              "waitForCompletion": true
          }
      ],
      "triggers": [
          {
              "enabled": true,
              "expectedArtifactIds": [
                  "4397cbfc-50f8-4244-b721-2a35d8e04715",
                  "aec2c4f1-2cb2-4d50-962a-dedc2a7457e0",
                  "14234aae-38d8-424b-9d11-76cbade0e194"
              ],
              "payloadConstraints": {},
              "source": "chart",
              "type": "webhook"
          }
          {{- range $index, $image := .images }}
            {{- $imageName := printf "%s/%s/%s" $root.Values.registry.address $image.organization $image.repository }}
          ,{
              "account": "dockerhub",
              "enabled": true,
              "expectedArtifactIds": [
                  "{{- $index }}"
              ],
              "organization": "{{ $image.organization }}",
              "registry": "{{ $root.Values.registry.address }}",
              "repository": "{{ $image.organization }}/{{ $image.repository }}",
              "type": "docker"
          }
          {{- end }}
      ],
      "updateTs": "1558523410000"
    }

  {{ .name }}-deploy-dev.json: |-
    {
      "application": "{{ .name }}",
      "name": "Deploy Dev",
      "expectedArtifacts": [
        {{- range $index, $image := .images }}
        {{- $imageName := printf "%s/%s/%s" $root.Values.registry.address $image.organization $image.repository }}
            {
              "defaultArtifact": {
                  "id": "beebe844-426d-46ee-9a9f-b13eeb251717",
                  "name": "{{- $imageName}}",
                  "reference": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "displayName": "{{- $imageName}}",
              "id": "{{- $index }}",
              "matchArtifact": {
                  "id": "a8417d7f-2fa1-4d7b-a06b-e9610d5604fa",
                  "name": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
            },
        {{- end }}
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "ef99e6d2-5335-4cb9-aa44-3afee04c641a"
              },
              "displayName": "dev-chart",
              "id": "5fb1c65d-625c-4c17-9e60-9cbf688edad7",
              "matchArtifact": {
                  "id": "7873fd97-34b8-4d3f-aa20-6e9dac6c13dc",
                  "name": "dev-chart",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "edf1d805-a605-446c-b1c2-336cfac65f36"
              },
              "displayName": "production-chart",
              "id": "be8e2ac8-93ef-461a-9244-345a0d11b00e",
              "matchArtifact": {
                  "id": "ec2cb412-bbad-4f2d-886c-660ec3032bbc",
                  "name": "production-chart",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "2f210ffa-7cd7-482c-a6aa-50ea1acfda0f"
              },
              "displayName": "staging-chart",
              "id": "2c294f40-e908-46ac-bd88-3df63b4d8b1d",
              "matchArtifact": {
                  "id": "0aeaff79-b56f-4524-902a-1fda4cfe1c4d",
                  "name": "staging-chart",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          }
      ],
      "keepWaitingPipelines": false,
      "lastModifiedBy": "anonymous",
      "limitConcurrent": true,
      "stages": [
          {
              "account": "default",
              "cloudProvider": "kubernetes",
              "manifestArtifactAccount": "embedded-artifact",
              "manifestArtifactId": "5fb1c65d-625c-4c17-9e60-9cbf688edad7",
              "moniker": {
                  "app": "{{ .name }}"
              },
              "name": "Deploy (Manifest) Dev",
              "refId": "2",
              "relationships": {
                  "loadBalancers": [],
                  "securityGroups": []
              },
              "requiredArtifactIds": [
                {{- range $index, $image := .images }}
                {{if ne $index 0}},{{end}}"{{- $index}}"
                {{- end }}
              ],
              "requisiteStageRefIds": [],
              "skipExpressionEvaluation": true,
              "source": "artifact",
              "type": "deployManifest"
          },
          {
              "failPipeline": true,
              "judgmentInputs": [],
              "name": "Manual Judgment",
              "notifications": [],
              "refId": "6",
              "requisiteStageRefIds": [
                  "2"
              ],
              "type": "manualJudgment"
          },
          {
              "application": "{{ .name }}",
              "failPipeline": true,
              "name": "Pipeline",
              "pipeline": "<DEPLOY_STAGING_ID>",
              "refId": "7",
              "requisiteStageRefIds": [
                  "6"
              ],
              "type": "pipeline",
              "waitForCompletion": true
          }
      ],
      "triggers": [],
      "updateTs": "1558527470000"
    }

  {{ .name }}-deploy-staging.json: |-
    {
      "application": "{{ .name }}",
      "name": "Deploy Staging",
      "expectedArtifacts": [
        {{- range $index, $image := .images }}
        {{- $imageName := printf "%s/%s/%s" $root.Values.registry.address $image.organization $image.repository }}
          {
              "defaultArtifact": {
                  "id": "{{- $index }}",
                  "name": "{{- $imageName}}",
                  "reference": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "displayName": "{{- $imageName}}",
              "id": "{{- $index}}",
              "matchArtifact": {
                  "id": "a8417d7f-2fa1-4d7b-a06b-e9610d5604fa",
                  "name": "{{- $imageName}}",
                  "type": "docker/image"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          },
        {{- end }}
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "ef99e6d2-5335-4cb9-aa44-3afee04c641a"
              },
              "displayName": "staging-chart",
              "id": "5fb1c65d-625c-4c17-9e60-9cbf688edad7",
              "matchArtifact": {
                  "id": "7873fd97-34b8-4d3f-aa20-6e9dac6c13dc",
                  "name": "staging-chart",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          },
          {
              "defaultArtifact": {
                  "customKind": true,
                  "id": "edf1d805-a605-446c-b1c2-336cfac65f36"
              },
              "displayName": "production-chart",
              "id": "be8e2ac8-93ef-461a-9244-345a0d11b00e",
              "matchArtifact": {
                  "id": "ec2cb412-bbad-4f2d-886c-660ec3032bbc",
                  "name": "production-chart",
                  "type": "embedded/base64"
              },
              "useDefaultArtifact": false,
              "usePriorArtifact": false
          }
      ],
      "keepWaitingPipelines": false,
      "lastModifiedBy": "anonymous",
      "limitConcurrent": true,
      "stages": [
          {
              "account": "default",
              "cloudProvider": "kubernetes",
              "manifestArtifactAccount": "embedded-artifact",
              "manifestArtifactId": "5fb1c65d-625c-4c17-9e60-9cbf688edad7",
              "moniker": {
                  "app": "{{ .name }}"
              },
              "name": "Deploy (Manifest) staging",
              "refId": "2",
              "relationships": {
                  "loadBalancers": [],
                  "securityGroups": []
              },
              "requiredArtifactIds": [
                {{- range $index, $image := .images }}
                {{if ne $index 0}},{{end}}"{{- $index}}"
                {{- end }}
              ],
              "requisiteStageRefIds": [],
              "skipExpressionEvaluation": true,
              "source": "artifact",
              "type": "deployManifest"
          },
          {
              "command": "{{ .testScript.command}}",
              "failPipeline": true,
              "name": "Test Script",
              "refId": "5",
              "repoBranch": "master",
              "repoUrl": "{{ .chart.repo }}",
              "requisiteStageRefIds": [
                  "2"
              ],
              "scriptPath": "{{ .testScript.path }}",
              "type": "script",
              "user": "[anonymous]",
              "waitForCompletion": true
          },
          {
              "failPipeline": true,
              "judgmentInputs": [],
              "name": "Manual Judgment",
              "notifications": [],
              "refId": "6",
              "requisiteStageRefIds": [
                  "5"
              ],
              "type": "manualJudgment"
          },
          {
              "application": "{{ .name }}",
              "failPipeline": true,
              "name": "Pipeline",
              "pipeline": "<DEPLOY_PRODUCTION_ID>",
              "refId": "7",
              "requisiteStageRefIds": [
                  "6"
              ],
              "type": "pipeline",
              "waitForCompletion": true
          }
      ],
      "triggers": [],
      "updateTs": "1558005007000"
    }

  {{ .name }}-deploy-production.json: |-
    {
      "application": "{{ .name }}",
      "name": "Deploy Production",
      "expectedArtifacts": [
        {
          "defaultArtifact": {
            "customKind": true,
            "id": "56330e63-2a3a-4979-a432-043e0c653685"
          },
          "displayName": "production-chart",
          "id": "4397cbfc-50f8-4244-b721-2a35d8e04715",
          "matchArtifact": {
            "id": "7f76f43f-37fd-4410-81f2-c1acd4cf8422",
            "name": "production-chart",
            "type": "embedded/base64"
          },
          "useDefaultArtifact": false,
          "usePriorArtifact": true
        }
        {{- range $index, $image := .images }}
        {{- $imageName := printf "%s/%s/%s" $root.Values.registry.address $image.organization $image.repository }}
        ,{
          "defaultArtifact": {
            "customKind": true,
            "id": "d0960d0c-5294-408d-a24b-81ec1537abd8"
          },
          "displayName": "{{- $imageName}}",
          "id": "{{- $index}}",
          "matchArtifact": {
            "id": "152022db-5a95-4963-a88c-3e7f3e31af01",
            "name": "{{- $imageName}}",
            "type": "docker/image"
          },
          "useDefaultArtifact": false,
          "usePriorArtifact": true
        }
        {{- end }}
      ],
      "keepWaitingPipelines": false,
      "lastModifiedBy": "anonymous",
      "limitConcurrent": true,
      "stages": [
        {
          "account": "default",
          "cloudProvider": "kubernetes",
          "manifestArtifactAccount": "embedded-artifact",
          "manifestArtifactId": "4397cbfc-50f8-4244-b721-2a35d8e04715",
          "moniker": {
            "app": "{{ .name }}"
          },
          "name": "Deploy (Manifest) Production",
          "refId": "4",
          "relationships": {
            "loadBalancers": [],
            "securityGroups": []
          },
          "requiredArtifactIds": [
            {{- range $index, $image := .images }}
            {{if ne $index 0}},{{end}}"{{- $index}}"
            {{- end }}
          ],
          "requisiteStageRefIds": [],
          "skipExpressionEvaluation": true,
          "source": "artifact",
          "type": "deployManifest"
        }
      ],
      "triggers": [],
      "updateTs": "1558004473000"
    }

  {{- end }}
EOF

cat > siddhi-cd/templates/NOTES.txt << "EOF"
1. You will need a port forwarding tunnel in order to access the Jenkins UI:
    export JENKINS_POD=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app=jenkins" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward --namespace {{ .Release.Namespace }} $JENKINS_POD 8080

2. You will need to create 2 port forwarding tunnels in order to access the Spinnaker UI:
    export DECK_POD=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "cluster=spin-deck" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward --namespace {{ .Release.Namespace }} $DECK_POD 9000

    export GATE_POD=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "cluster=spin-gate" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward --namespace {{ .Release.Namespace }} $GATE_POD 8084
EOF

cat > siddhi-cd/templates/jenkins-casc-conf.yaml << "EOF"
# Copyright (c) 2018, Siddhi Inc. (http://www.Siddhi.org) All Rights Reserved.
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
# limitations under the License.

apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-casc-conf
data:
  global-config.yaml: |-
    unclassified:
      globalLibraries:
        libraries:
          - name: "Siddhi-jenkins-shared-lib"
            defaultVersion: master
            retriever:
              modernSCM:
                scm:
                  git:
                    remote: "https://github.com/Aaquiff/jenkins-shared-lib"
    credentials:
      system:
        domainCredentials:
          - credentials:
              - usernamePassword:
                  scope: GLOBAL
                  id: github_credentials
                  username: ${GITHUB_USERNAME}
                  password: ${GITHUB_PASSWORD}
    jenkins:
      systemMessage: "Siddhi CI/CD Setup"
      securityRealm:
        local:
          allowsSignup: false
          users:
            - id: "{{ .Values.jenkins.username }}"
              password: "{{ .Values.jenkins.password }}"
      authorizationStrategy: loggedInUsersCanDoAnything
    jobs:
      {{- $namespace := .Release.Namespace }}
      {{- range .Values.applications }}
      {{- $application := . }}
      - script: >
          folder("{{ $application.name }}")
      {{- range $index, $image := .images }}
      - script: >
          job("{{ $application.name }}/{{ $image.repository }}-image") {
            description()
            logRotator(10)
            keepDependencies(false)
            disabled(false)
            concurrentBuild(true)
            scm {
                git {
                    remote {
                        name('docker-repo')
                        url('{{ $image.gitRepo }}')
                        credentials('github_credentials')
                    }
                }
            }
            triggers {
              cron('@daily')
            }
            steps {
              shell("""
                timestamp() {
                  date +\"%Y%m%d%H%M%S\"
                }

                IMAGE_NAME={{ $image.organization }}/{{ $image.repository }}:`timestamp`
                docker login hub.docker.com -u \$SIDDHI_USERNAME -p \$SIDDHI_PASSWORD
                docker build -t \$IMAGE_NAME .
                docker login -u \$REGISTRY_USERNAME -p \$REGISTRY_PASSWORD
                docker push \$IMAGE_NAME""")
            }
          }
      - script: >
          job("{{ $application.name }}/{{ $image.repository }}-artifacts") {
            description()
            logRotator(10)
            keepDependencies(false)
            disabled(false)
            concurrentBuild(true)
            scm {
                git {
                    remote {
                        name('docker-repo')
                        url('{{ $image.gitRepo }}')
                        credentials('github_credentials')
                    }
                }
            }
            triggers {
                scm('* * * * *')
            }
            steps {
              shell("""
                TAG=`docker images {{ $image.organization }}/{{ $image.repository }} --format '{{ "{{ .Tag }}" }}' | sort -nrk1 | head -1`
                sed -i "s|{{ $image.SiddhiImage }}|{{ $image.organization }}/{{ $image.repository }}:\$TAG|" Dockerfile
                docker build -t {{ $image.organization }}/{{ $image.repository }}:\$TAG .
                docker login -u \$REGISTRY_USERNAME -p \$REGISTRY_PASSWORD
                docker push {{ $image.organization }}/{{ $image.repository }}:\$TAG""")
            }
          }
      {{- end }}
      - script: >
          job("{{ .name }}/chart") {
            description()
            logRotator(10)
            keepDependencies(false)
            disabled(false)
            concurrentBuild(true)
            scm {
                git {
                    remote {
                        name('chart-repo')
                        url('{{ .chart.repo }}')
                        credentials('github_credentials')
                    }
                }
            }
            triggers {
                scm('* * * * *')
            }
            steps {
              shell(
              """
              cat {{ .chart.name }}/values-dev.yaml | base64 >test
              VALUES_DEV_CONTENT=`tr -d '\\n' < test`

              cat {{ .chart.name }}/values-staging.yaml | base64 >test
              VALUES_STAGING_CONTENT=`tr -d '\\n' < test`

              cat {{ .chart.name }}/values-prod.yaml | base64 >test
              VALUES_PROD_CONTENT=`tr -d '\\n' < test`

              CHART_PATH=`helm package {{ .chart.name }} | sed 's|Successfully packaged chart and saved it to: ||'`
              CHART_NAME=`basename \$CHART_PATH`
              cat \$CHART_NAME | base64 > test
              CHART_CONTENT=`tr -d '\\n' < test`

              curl -X POST --header "Content-Type: application/json" --request POST --data '{"artifacts": [ {"type": "embedded/base64","name": "'"\$CHART_NAME"'", "reference": "'"\$CHART_CONTENT"'" }, {"type": "embedded/base64","name": "values-dev.yaml","reference": "'"\$VALUES_DEV_CONTENT"'" }, {"type": "embedded/base64","name": "values-prod.yaml","reference": "'"\$VALUES_PROD_CONTENT"'" }, {"type": "embedded/base64","name": "values-staging.yaml","reference": "'"\$VALUES_STAGING_CONTENT"'" } ]}' http://spin-gate.{{ $namespace }}.svc.cluster.local:8084/webhooks/webhook/chart
              """)

            }
          }
      {{- end }}
EOF

cat > siddhi-cd/templates/roles.yaml << "EOF"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: {{ .Release.Namespace }}
automountServiceAccountToken: true

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: Jenkins-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: {{ .Release.Namespace }}
EOF

cat > siddhi-cd/templates/secrets.yaml << "EOF"
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: registry-credentials-pod
data:
  username: {{ .Values.registry.username | b64enc }}
  password: {{ .Values.registry.password | b64enc }}
  server: {{ .Values.registry.server | b64enc }}
  email: {{ .Values.registry.email | b64enc }}

---

apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: github-credentials
data:
  username: {{ .Values.github.username | b64enc }}
  password: {{ .Values.github.password | b64enc }}

---

apiVersion: v1
kind: Secret
metadata:
  name: Siddhi-credentials
type: Opaque
data:
  username: {{ .Values.SiddhiUsername | b64enc }}
  password: {{ .Values.SiddhiPassword | b64enc }}
EOF

cat > siddhi-cd/templates/spinnaker-jenkins-job-configurator.yaml << "EOF"
apiVersion: batch/v1
kind: Job
metadata:
  name: spinnaker-jenkins-job-configurator
  annotations:
    "helm.sh/hook": "post-install"
    "helm.sh/hook-delete-policy": "before-hook-creation"
    "helm.sh/hook-weight": "0"
spec:
  template:
    spec:
      containers:
      - name: spin-jenkins-job-configurator
        image: appropriate/curl
        command: ["/bin/sh"]
        args: ["-c", "sh /spinnaker/run.sh"]
        env:
        - name: JENKINS_HOST
          value: "http://jenkins-service.{{ .Release.Namespace }}.svc.cluster.local:8080"
        - name: JOB_NAME
          value: "job"
        volumeMounts:
        - name: spinnaker-jenkins-job-conf
          mountPath: /spinnaker
      restartPolicy: Never
      volumes:
      - name: spinnaker-jenkins-job-conf
        configMap:
          name: spinnaker-jenkins-job-conf

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: spinnaker-jenkins-job-conf
data:
  run.sh: |-
    cd spinnaker
    echo "Creating job"
    curl -X POST --fail "$JENKINS_HOST/createItem?name=$JOB_NAME" \
    --data-binary @scriptJobConfig.xml \
    --user {{ .Values.jenkins.username }}:{{ .Values.jenkins.password }} \
    -H "Content-Type:text/xml"
  scriptJobConfig.xml: |-
    <?xml version='1.0' encoding='UTF-8'?>
    <project>
      <actions/>
      <description></description>
      <logRotator class="hudson.tasks.LogRotator">
        <daysToKeep>10</daysToKeep>
        <numToKeep>500</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
      </logRotator>
      <keepDependencies>false</keepDependencies>
      <properties>
        <hudson.security.AuthorizationMatrixProperty>
          <permission>hudson.model.Item.Delete:api_team</permission>
          <permission>hudson.model.Item.Read:api_team</permission>
          <permission>hudson.model.Run.Delete:api_team</permission>
          <permission>hudson.model.Item.Workspace:api_team</permission>
          <permission>hudson.model.Item.Build:api_team</permission>
          <permission>hudson.scm.SCM.Tag:api_team</permission>
          <permission>hudson.model.Item.Configure:api_team</permission>
          <permission>hudson.model.Run.Update:api_team</permission>
          <permission>hudson.model.Item.Discover:anonymous</permission>
        </hudson.security.AuthorizationMatrixProperty>
        <hudson.plugins.buildblocker.BuildBlockerProperty plugin="build-blocker-plugin@1.7.1">
          <useBuildBlocker>true</useBuildBlocker>
          <blockLevel>UNDEFINED</blockLevel>
          <scanQueueFor>DISABLED</scanQueueFor>
          <blockingJobs>STASH_MAINTENANCE_DOWNTIME</blockingJobs>
        </hudson.plugins.buildblocker.BuildBlockerProperty>
        <com.chikli.hudson.plugin.naginator.NaginatorOptOutProperty plugin="naginator@1.15">
          <optOut>false</optOut>
        </com.chikli.hudson.plugin.naginator.NaginatorOptOutProperty>
        <hudson.model.ParametersDefinitionProperty>
          <parameterDefinitions>
            <hudson.model.StringParameterDefinition>
              <name>TASK_ID</name>
              <description>Unique Task Id generated by Spinnaker</description>
              <defaultValue>0</defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>SCRIPT_PATH</name>
              <description>Path to the folder hosting the scripts</description>
              <defaultValue>.</defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>COMMAND</name>
              <description>Executable script and parameters</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>IMAGE_ID</name>
              <description>The image ID for this region based on the AMI Spinnaker is deploying</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>REGION_PARAM</name>
              <description>The region the Spinnaker deployment is running against</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>ENV_PARAM</name>
              <description>Environment Spinnaker is running against</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>CLUSTER_PARAM</name>
              <description>The cluster Spinnaker is deploying to</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>CMC</name>
              <description>The CMC this deployment is associated with</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>CONTEXT</name>
              <description>The parameters available to this task</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
            <hudson.model.StringParameterDefinition>
              <name>REPO_URL</name>
              <description>git repository url.</description>
              <defaultValue></defaultValue>
            </hudson.model.StringParameterDefinition>
          </parameterDefinitions>
        </hudson.model.ParametersDefinitionProperty>
        <com.gmail.ikeike443.PlayAutoTestJobProperty plugin="play-autotest-plugin@0.0.12"/>
        <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
          <autoRebuild>false</autoRebuild>
          <rebuildDisabled>false</rebuildDisabled>
        </com.sonyericsson.rebuild.RebuildSettings>
        <hudson.plugins.disk__usage.DiskUsageProperty plugin="disk-usage@0.25"/>
      </properties>
      <scm class="hudson.plugins.git.GitSCM" plugin="git@2.4.0">
        <configVersion>2</configVersion>
        <userRemoteConfigs>
          <hudson.plugins.git.UserRemoteConfig>
            <name>apidaemon</name>
            <url>$REPO_URL</url>
          </hudson.plugins.git.UserRemoteConfig>
        </userRemoteConfigs>
        <branches>
          <hudson.plugins.git.BranchSpec>
            <name>master</name>
          </hudson.plugins.git.BranchSpec>
        </branches>
        <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
        <browser class="hudson.plugins.git.browser.Stash">
          <url></url>
        </browser>
        <submoduleCfg class="list"/>
        <extensions>
          <hudson.plugins.git.extensions.impl.PerBuildTag/>
          <hudson.plugins.git.extensions.impl.WipeWorkspace/>
        </extensions>
      </scm>
      <canRoam>false</canRoam>
      <disabled>false</disabled>
      <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
      <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
      <jdk>Oracle JDK8</jdk>
      <triggers/>
      <concurrentBuild>true</concurrentBuild>
      <builders>
        <hudson.plugins.descriptionsetter.DescriptionSetterBuilder plugin="description-setter@1.10">
          <regexp></regexp>
          <description>TASK=${TASK_ID} REGION=${REGION_PARAM} ENV=${ENV_PARAM} CLUSTER=${CLUSTER_PARAM} IMAGE=${IMAGE_ID} CMC=${CMC} ${SCRIPT_PATH}/${COMMAND} ${CONTEXT}</description>
        </hudson.plugins.descriptionsetter.DescriptionSetterBuilder>
        <hudson.tasks.Shell>
          <command># To run groovy scripts in this stage, you need to add groovy to your path:
    # export PATH=$PATH:/PATH/TO/GROOVY/bin
    # To add support for grapes, you need to install the package and add this flag,
    # pointing to the correct grape root directory.
    # export JAVA_OPTS=&apos;-Dgrape.root=${WORKSPACE}/.groovy/grape&apos;
    echo ${TASK_ID}
    sh ${SCRIPT_PATH}/${COMMAND}</command>
        </hudson.tasks.Shell>
      </builders>
      <publishers>
        <hudson.tasks.ArtifactArchiver>
          <artifacts>*.properties, *.json, *.yml</artifacts>
          <allowEmptyArchive>true</allowEmptyArchive>
          <onlyIfSuccessful>false</onlyIfSuccessful>
          <fingerprint>false</fingerprint>
          <defaultExcludes>true</defaultExcludes>
        </hudson.tasks.ArtifactArchiver>
      </publishers>
      <buildWrappers>
        <EnvInjectBuildWrapper plugin="envinject@1.91.4">
          <info>
            <propertiesContent>PYTHONUNBUFFERED=1
    P4USER=rolem</propertiesContent>
            <loadFilesFromMaster>false</loadFilesFromMaster>
          </info>
        </EnvInjectBuildWrapper>
      </buildWrappers>
    </project>
EOF

cat > siddhi-cd/templates/service.yaml << "EOF"
apiVersion: v1
kind: Service
metadata:
  name: jenkins-service
spec:
  selector:
    app: jenkins
  ports:
  - name: servlet-http
    port: 8080
    targetPort: 8080
    protocol: TCP

---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: jenkins-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  tls:
  - hosts:
    - jenkins
  rules:
  - host: jenkins
    http:
      paths:
      - path: /
        backend:
          serviceName: jenkins-service
          servicePort: 8080
EOF

cat > siddhi-cd/templates/_helpers.tpl << "EOF"
{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "jenkins.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jenkins.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "jenkins.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
EOF

cat > siddhi-cd/templates/volumes.yaml << "EOF"
# kind: PersistentVolume
# apiVersion: v1
# metadata:
#   name: jenkins
#   labels:
#     type: local
# spec:
#   capacity:
#     storage: 2Gi
#   accessModes:
#     - ReadWriteOnce
#   hostPath:
#     path: "/data/jenkins/"

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-claim
  labels:
    app: jenkins
    tier: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wum-claim
  labels:
    app: jenkins
    tier: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

cat > siddhi-cd/values.yaml << "EOF"
namespace: jenkins
image: 'aaquiff/jenkins-docker-kube:latest'
SiddhiUsername: <SIDDHI_SUBSCRIPTION_USERNAME>
SiddhiPassword: <SIDDHI_SUBSCRIPTION_PASSWORD>

# Admin credentials of jenkins instance to be created
jenkins:
  username: <JENKINS_USERNAME>
  password: <JENKINS_PASSWORD>

registry:
  server: 'https://index.docker.io/v1/'
  username: <REGISTRY_USERNAME>
  password: <REGISTRY_PASSWORD>
  email: <REGISTRY_EMAIL>
  address: index.docker.io

github:
  username: <GITHUB_USERNAME>
  password: <GITHUB_PASSWORD>

# applications:
#   - name: Siddhiei
#     email: <SIDDHI_USERNAME>
#     testScript:
#       path: tests
#       command: test.sh
#     chart:
#       name: scalable-integrator
#       repo: 'https://github.com/Aaquiff/ei-cd'
#     images:
#       - SiddhiImage: 'docker.Siddhi.com/Siddhiei-integrator:6.4.0'
#         organization: aaquiff
#         repository: Siddhiei-6.4.0
#         gitRepo: 'https://github.com/Aaquiff/docker-ei'

# Values for Spinnaker chart
spinnaker:
  dockerRegistries:
    - name: dockerhub
      address: index.docker.io
      username: <REGISTRY_USERNAME>
      password: <REGISTRY_PASSWORD>
      email: <REGISTRY_EMAIL>
      repositories:
        <REPOSITORIES>
  halyard:
    spinnakerVersion: 1.13.8
    image:
      tag: 1.20.2
    additionalScripts:
      create: true
      data:
        enable_ci.sh: |-
          echo "Configuring jenkins master"
          USERNAME="<JENKINS_USERNAME>"
          PASSWORD="<JENKINS_PASSWORD>"
          $HAL_COMMAND config ci jenkins enable
          echo $PASSWORD | $HAL_COMMAND config ci jenkins master edit master --address http://jenkins-service.jenkins.svc.cluster.local:8080 --username $USERNAME --password || echo $PASSWORD | $HAL_COMMAND config ci jenkins master add master --address http://jenkins-service.jenkins.svc.cluster.local:8080 --username $USERNAME --password
          $HAL_COMMAND config features edit --pipeline-templates true
  ingress:
    enabled: true
    host: spinnaker
    annotations:
      ingress.kubernetes.io/ssl-redirect: 'true'
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "true"
    tls:
      - secretName: '-tls'
        hosts:
          - domain.com
  ingressGate:
    enabled: true
    host: gate.spinnaker
    annotations:
      ingress.kubernetes.io/ssl-redirect: 'true'
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "true"
    tls:
     - secretName: -tls
       hosts:
         - domain.com
EOF

cat > siddhi-cd/requirements.lock << "EOF"
dependencies:
- name: spinnaker
  repository: https://kubernetes-charts.storage.googleapis.com
  version: 1.8.1
- name: docker-registry
  repository: https://kubernetes-charts.storage.googleapis.com
  version: 1.8.0
digest: sha256:ea49ffa93decf53b549e6886529bac7204825a85371584801e6ee28d110973b4
generated: 2019-05-28T15:29:33.797757+05:30
EOF

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
      - SiddhiImage: 'Siddhi_IMAGE'
        organization: ORGANIZATION
        repository: REPOSITORY
        gitRepo: 'GIT_REPO'
EOF

replaceTag() {
    sed -i "s|$1|$2|g" siddhi-cd/values.yaml
}

if [ "$1" != "" ]; then
  SIDDHI_SUBSCRIPTION_USERNAME=$1
  SIDDHI_SUBSCRIPTION_PASSWORD=$2
  REGISTRY_USERNAME=$3
  REGISTRY_PASSWORD=$4
  REGISTRY_EMAIL=$5
  JENKINS_USERNAME=$6
  JENKINS_PASSWORD=$7
  GITHUB_USERNAME=$8
  GITHUB_PASSWORD=$9
else
  print_notice "Siddhi Subscription credentials"
  read -p "Enter Your Siddhi Username: " SIDDHI_SUBSCRIPTION_USERNAME
  read -s -p "Enter Your Siddhi Password: " SIDDHI_SUBSCRIPTION_PASSWORD
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

replaceTag "<SIDDHI_SUBSCRIPTION_USERNAME>" "$SIDDHI_SUBSCRIPTION_USERNAME"
replaceTag "<SIDDHI_SUBSCRIPTION_PASSWORD>" "$SIDDHI_SUBSCRIPTION_PASSWORD"
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

  echo "" >> siddhi-cd/values.yaml
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
  replaceValues EMAIL $SIDDHI_SUBSCRIPTION_USERNAME >> siddhi-cd/values.yaml

  DATA="- $ORGANIZATION/$REPOSITORY"
  cat siddhi-cd/values.yaml | sed "s|<REPOSITORIES>|${DATA}<REPOSITORIES>|" |
  sed 's|<REPOSITORIES>|\
          <REPOSITORIES>|g' > siddhi-cd/values2.yaml
  rm siddhi-cd/values.yaml
  mv siddhi-cd/values2.yaml siddhi-cd/values.yaml

fi

replaceTag "<REPOSITORIES>" ""

print_notice "siddhi-cd/values.yaml created"

cd siddhi-cd


print_notice "Building chart dependencies..."
helm dependency build

print_notice "Deploying the helm chart..."
# helm upgrade siddhi-cd . -f values.yaml --install --namespace siddhi-cd

print_notice "Siddhi CI/CD chart generated and deployed. Further changes could be made by upgrading the helm deployment."
