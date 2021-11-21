FROM wcp-alchemy-containers-team-access-redhat-docker-remote.artifactory.swg-devops.com/ubi8/ubi-minimal as intermediate
ARG ARTIFACTORY_API_KEY=blank
RUN mkdir -p /tmp/bincache
ENV OC_VERSION="4.7.30"
RUN microdnf update -y && microdnf install tar util-linux gettext -y && microdnf clean all
RUN curl -H "X-JFrog-Art-Api:${ARTIFACTORY_API_KEY}" -LO "https://na.artifactory.swg-devops.com/artifactory/wcp-alchemy-containers-team-openshift-generic-remote/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz" \
    && tar xvzf openshift-client-linux.tar.gz && mv kubectl /tmp/bincache/kubectl && mv oc /tmp/bincache/oc


FROM wcp-alchemy-containers-team-access-redhat-docker-remote.artifactory.swg-devops.com/ubi8/ubi-minimal:8.4-200
ARG REPO_SOURCE_URL=blank
LABEL "razee.io.source-url"="${REPO_SOURCE_URL}"
LABEL "compliance.owner"="ibm-armada-bootstrap"
ARG BUILD_URL=blank
LABEL "razee.io.build-url"="${BUILD_URL}"
RUN microdnf update -y && microdnf clean all
COPY --from=intermediate /tmp/bincache/kubectl /usr/local/bin/kubectl
RUN  chmod 0710 /usr/local/bin/kubectl && /usr/local/bin/kubectl version --client
COPY executionscripts/* /usr/local/bin/
RUN chmod 0750 /usr/local/bin/*
COPY executionscripts/reconcile_nodepool_metadata.sh /usr/local/bin/reconcile_nodepool_metadata.sh
RUN chmod 0750 /usr/local/bin/reconcile_nodepool_metadata.sh
USER 65532
ENTRYPOINT [ "/usr/local/bin/reconcile_nodepool_metadata.sh" ]