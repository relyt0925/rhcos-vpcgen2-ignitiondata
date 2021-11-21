RHCOS_VPCGEN2_IGNITIONDATA_IMAGE='armada-master/rhcos-vpcgen2-ignitiondata'

.PHONY: shellcheck
shellcheck:
	shellcheck usr/local/bin/*.sh
	shellcheck executionscripts/*.sh
	shellcheck template_files.sh
	shellcheck kubelet_service_template.sh
	shellcheck haproxy_image_template.sh
	shellcheck oc_check.sh
	shellcheck rhcos_image_locator.sh
	shellcheck scripts/*.sh
	shellcheck rhcos-image-import/image-clean-script.sh

.PHONY: runanalyzedeps
runanalyzedeps:
	@docker build --rm --build-arg ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY}"  -t armada/analyze-deps -f Dockerfile.dependencycheck .
	docker run -v `pwd`/dependency-check:/results armada/analyze-deps

.PHONY: analyzedeps
analyzedeps:
	/tmp/dependency-check/bin/dependency-check.sh --enableExperimental --log /results/logfile --out /results --disableAssembly \
 		--suppress /src/dependency-check/suppression-file.xml --format JSON --prettyPrint --failOnCVSS 0 --scan /src

.PHONY: runignitiontemplating
runignitiontemplating:
	./oc_check.sh
	./kubelet_service_template.sh
	./machine_configdaemon_sha_template.sh
	./haproxy_image_template.sh
	./template_files.sh
	./scripts/ignition-generator.sh

.PHONY: armada-openshift-master
armada-openshift-master:
	@ set -x; if [ ! -d "../armada-openshift-master" ]; then \
        echo 'armada-openshift-master project not found, cloning the repo...'; \
        git -C .. clone git@github.ibm.com:alchemy-containers/armada-openshift-master.git; \
        cd ../armada-openshift-master; \
        git checkout hypershift-named-cert-update-newapi; \
        git submodule update --init --recursive; \
    fi; \


.PHONY: rhcos-management-cluster-config
rhcos-management-cluster-config:
	@ set -x; if [ ! -d "../rhcos-management-cluster-config" ]; then \
        echo 'rhcos-management-cluster-config project not found, cloning the repo...'; \
        git -C .. clone git@github.ibm.com:alchemy-containers/rhcos-management-cluster-config.git; \
    fi; \

.PHONY: armada-softlayer-image
armada-softlayer-image:
	@ set -x; if [ ! -d "../armada-softlayer-image" ]; then \
        echo 'armada-softlayer-image project not found, cloning the repo...'; \
        git -C .. clone git@github.ibm.com:alchemy-containers/armada-softlayer-image.git; \
        cd ../armada-softlayer-image; \
    fi; \

.PHONY: openshift-4-worker-automation
openshift-4-worker-automation:
	@ set -x; if [ ! -d "../openshift-4-worker-automation" ]; then \
        echo 'openshift-4-worker-automation project not found, cloning the repo...'; \
        git -C .. clone --depth 1 --single-branch --branch develop git@github.ibm.com:alchemy-containers/openshift-4-worker-automation.git; \
    fi; \

.PHONY: rhcos-incluster-config
rhcos-incluster-config:
	@ set -x; if [ ! -d "../rhcos-incluster-config" ]; then \
        echo 'rhcos-incluster-config project not found, cloning the repo...'; \
        git -C .. clone git@github.ibm.com:alchemy-containers/rhcos-incluster-config.git; \
    fi; \

.PHONY: deploy-hosted-cluster
deploy-hosted-cluster: armada-openshift-master
	./scripts/deploy-hosted-cluster.sh

.PHONY: destroy-hosted-cluster
destroy-hosted-cluster:
	./scripts/destroy-hosted-cluster.sh

.PHONY: store-cos
store-cos:
	ansible-playbook store-cos.yml -e s3_log_file="/tmp/${CLUSTER_ID}-${TRAVIS_JOB_ID}.txt"

.PHONY: buildimage
buildimage:
	@docker build \
      --build-arg REPO_SOURCE_URL="${REPO_SOURCE_URL}" \
      --build-arg BUILD_URL="${BUILD_URL}" \
      --build-arg ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY}" \
      -t ${RHCOS_VPCGEN2_IGNITIONDATA_IMAGE}\:${TRAVIS_COMMIT} -f Dockerfile .

.PHONY: buildprtestimage
buildprtestimage:
	@docker build \
      --build-arg REPO_SOURCE_URL="${REPO_SOURCE_URL}" \
      --build-arg BUILD_URL="${BUILD_URL}" \
      --build-arg ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY}" \
      -t ${PRTEST_RHCOS_VPCGEN2_IGNITIONDATA_IMAGE}\:${TRAVIS_COMMIT} -f Dockerfile .

.PHONY: imageToCOS
imageToCOS:
	$(MAKE) armada-softlayer-image
	./rhcos-image-import/rhcos_image_import.sh
     
.PHONY: cleanoldImages
cleanoldImages:
	$(MAKE) armada-softlayer-image
	./rhcos-image-import/image-clean-script.sh

.PHONY: ordercluster
ordercluster:
	./oc_check.sh
ifdef TRAVIS_COMMIT
	$(MAKE) buildprtestimage
	./build-tools/docker/pushDockerImage.sh ${PRTEST_RHCOS_VPCGEN2_IGNITIONDATA_IMAGE} ${TRAVIS_COMMIT}
endif
	$(MAKE) deploy-hosted-cluster

# example usage make cherry-pick pullRequestURL=https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/104 releaseBranch=release-4.9
.PHONY: cherry-pick
cherry-pick:
	./scripts/cherry-pick-tag.sh $(pullRequestURL) $(releaseBranch)

.PHONY: cleaniaasresources
cleaniaasresources:
	./scripts/clean-iaas-resources.sh
