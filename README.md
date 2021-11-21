# General PR testing steps:

First the general branch structure of this repo mirrors what openshift does upstream for release tracking branches
master -> tracks latest "release"
release-4.X -> tracks the corresponding Openshift release. For example release-4.8 holds the payload for Openshift 4.8 clusters. The testing corresponding to that branch will just test the potential cluster combinations an RHCOS 4.8 worker can be apart of. In practice this is only a Hypershift 4.9 cluster and a Hypershift 4.8 cluster. Note that for the period of time 4.9 isn't available no testing needs to be done at 4.9 (nop the test). 

There is a centralized Openshift test cluster in the Alchemy Staging Account that is called bts-oc4-rhcos-prtester. It is setup and onboarded with the proper security controls. The following prereq microservices are deployed to it to fully setup the cluster:

https://razeeflags.containers.cloud.ibm.com/alchemy-containers/flags/armada-cruisers/production/armada-hypershift-operator

All tests across all branches run against that same cluster (test runs get unique cluster names).

The following steps are performed for a given branch. I will use release-4.8 as an example 

Test 1: Hypershift cluster at 4.8, RHCOS workers also at 4.8
1) Order Hypershift cluster at 4.8 using the automation provided by armada-openshift-master (molecule)
2) Run local spruce templating (subsituting in the appropriate variables for pr testing) on services/rhcos-vpcgen2-ignitiondata/deployment.yaml. The output of this will be at services/rhcos-vpcgen2-ignitiondata/production.yaml
3) Note that there are also some variables that are replaced by cluster updater at apply time and need to be done in automation in the PR tester. Currently those variables are:
     - {{ DOCKER_REGISTRY }}: registry.ng.bluemix.net
     - managed_cluster_tail: the cluster name
     - {{ kubx-masters.armada-info-configmap.ICR_REGISTRY_URL }}: us.icr.io
4) Apply those resources into the cluster namespace you just ordered in step 1 
5) Apply the node pool corresponding to the appropriate pool value and cluster
6) Wait for user data to appear and use it to boot RHCOS machine to join ordered hypershift PR test cluster. Boot 2 RHCOS machines per test cluster
7) Wait for nodes to join cluster (node data registred)
8) Label joined nodes with appropriate metadata. See example of what's done for RHEL workers with: https://github.ibm.com/alchemy-containers/openshift-4-worker-automation/blob/develop/ansible/roles/label-node/tasks/main.yml#L19
9) Run basic pods/nodes/checks example here: https://github.ibm.com/alchemy-containers/openshift-4-worker-automation/blob/develop/deploy_ci.sh#L398 
10) We have to do some "mocing" in the PR test environment to get some Openshift tests to pass: An example of some of that mocking is automated in openshift-4-worker-automation here: https://github.ibm.com/alchemy-containers/openshift-4-worker-automation/blob/develop/deploy_ci.sh#L184
11) Then proceed to schedule Openshift 4 E2E tests in the cluster and collect results in similar way that is done in openshift-4-worker-automation repo here: https://github.ibm.com/alchemy-containers/openshift-4-worker-automation/blob/develop/deploy_ci.sh#L252

Test 2: Hypershift cluster at 4.9 (+1), RHCOS workers at 4.8
Follows same general pattern as above except hypershift cluster is ordered with the 4.9 BOM instead. Note in practice this phase does not exist for long (when the cluster is upgraded everything is queued to also start moving to 4.9.) However, there is a period of time where there could be a 4.9 control plane and 4.8 workers being added so it should still be tested. 

Note this changes for every version. For example, for 4.7 the hosted clusters ordered are one 4.7 cluster and one 4.8 cluster. 

We have found it beneficial to report status back throughout the test in the form of comments on the PR since these tests can take a long time to run . The helper functions to do that are also contained in the openshift-4-worker-automation repo here: https://github.ibm.com/alchemy-containers/openshift-4-worker-automation/blob/develop/deploy_ci.sh#L326

# Cherry pick make task
While supporting releases, there may be a need to cherry pick commits merged into the master branch onto multiple/specific release branches. Here is an example of how to run automation given a Pull Request that was merged to master and a release branch:

```
make cherry-pick pullRequestURL=https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/104 releaseBranch=release-4.9
```

this command will cherry pick the [merged commit](https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/commit/d7eb2b67c7a510a9f13b09688e095d10931d1442) in `pullRequestURL` and raise a new [PR](https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/112) to the release branch. A [comment](https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/104#issuecomment-35739790) will be left on the original PR indicating that the cherry pick PR was raised.

Builds of the cherry-pick can be found in [Travis](https://travis.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/builds). This is an [example job](https://travis.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/jobs/56639636) which will include output of the PR that was raised.

e.g.

```
{"level":"info","ts":1631900602.1327708,"caller":"git/git.go:317","msg":"Cherry pick ran successfully"}
{"level":"info","ts":1631900602.1329272,"caller":"git/git.go:168","msg":"Pushing changes..."}
{"level":"info","ts":1631900605.4328966,"caller":"git/git.go:177","msg":"Changes successfully pushed!"}
{"level":"info","ts":1631900606.1194534,"caller":"git/github.go:68","msg":"PR created: https://github.ibm.com/alchemy-containers/rhcos-vpcgen2-ignitiondata/pull/112"}
```

Requirements:
1. The pull request specified must be `merged`
1. The new cherry pick pull request will need to be manually reviewed/approved/merged to the target branch 