RHCOS_VPCGEN2_IGNITIONDATA_IMAGE='armada-master/rhcos-vpcgen2-ignitiondata'

.PHONY: shellcheck
shellcheck:
	shellcheck usr/local/bin/*.sh
	shellcheck executionscripts/*.sh
	shellcheck template_files.sh
	shellcheck scripts/*.sh

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
	./haproxy_image_template.sh
	./template_files.sh
	./scripts/ignition-generator.sh

.PHONY: armada-openshift-master
armada-openshift-master:
	@ set -x; if [ ! -d "../armada-openshift-master" ]; then \
        echo 'armada-openshift-master project not found, cloning the repo...'; \
        git -C .. clone git@github.ibm.com:alchemy-containers/armada-openshift-master.git; \
        cd ../armada-openshift-master; \
        git checkout hypershift-pr-tester; \
        git submodule update --init --recursive; \
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
