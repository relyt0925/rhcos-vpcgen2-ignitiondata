kubectl -n master-clusterid7 create cm 98-ibm-machineconfig-kubelet --from-file=data=/Users/tylerlisowski/gopath/src/github.ibm.com/lisowski/tyler-handy-scripts/additional-ibmcloud-ignition-payloads/ibm-payload-kubelet.yaml
kubectl -n master-clusterid7 label cm 98-ibm-machineconfig-kubelet ignition-config="true"
kubectl -n master-clusterid7 create cm 97-ibm-machineconfig-extradisk --from-file=data=/Users/tylerlisowski/gopath/src/github.ibm.com/lisowski/tyler-handy-scripts/additional-ibmcloud-ignition-payloads/ibm-payload-dedicateddisk.yaml
kubectl -n master-clusterid7 label cm 97-ibm-machineconfig-extradisk ignition-config="true"
kubectl -n master-clusterid7 delete pods -l app=machine-config-server
kubectl -n master-clusterid7 get secret clusterid7-user-data -o jsonpath='{.data.value}' | base64 -d

kubectl -n master-clusterid7 delete cm 98-ibm-machineconfig-kubelet
kubectl -n master-clusterid7 delete cm 97-ibm-machineconfig-extradisk
