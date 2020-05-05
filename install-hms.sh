CALICO_VERSION="3.13.3"
CLUSTER_NAME="calico-demo-eks"
IAM_ASSUME_ROLE="arn:aws:iam::ACCOUNTID:role/calico-demo-CalicoHMSNodeInstanceRole"
PULL_SECRET=""
ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_DEFAULT_REGION=$(echo $ZONE | awk '{print substr($0, 1, length($0)-1)}')
DESCRIBE_CLUSTER_RESULT="/tmp/describe_cluster_result.txt"

apt-get update -y && apt-get install -y \
  docker.io \
  curl \
  ipset \
  conntrack \
  python3-pip

pip3 install awscli --upgrade

aws eks describe-cluster \
  --region=${AWS_DEFAULT_REGION} \
  --name ${CLUSTER_NAME} \
  --output=text \
  --query 'cluster.{certificateAuthorityData: certificateAuthority.data, endpoint: endpoint}' > ${DESCRIBE_CLUSTER_RESULT}

B64_CLUSTER_CA=$(cat $DESCRIBE_CLUSTER_RESULT | awk '{print $1}')
APISERVER_ENDPOINT=$(cat $DESCRIBE_CLUSTER_RESULT | awk '{print $2}')

echo $APISERVER_ENDPOINT

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
mkdir -p ${CA_CERTIFICATE_DIRECTORY}
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
echo $B64_CLUSTER_CA | base64 -d > $CA_CERTIFICATE_FILE_PATH

systemctl start docker.service
mkdir -p /root/.docker
cat > /root/.docker/config.json <<EOF
{
  "auths": {
    "quay.io": {
      "auth": "PULL_SECRET",
      "email": ""
    }
  }
}
EOF
sed -i s/PULL_SECRET/${PULL_SECRET}/g /root/.docker/config.json

usermod -aG docker $USER
docker pull calico/node:v${CALICO_VERSION}
docker pull calico/ctl:v${CALICO_VERSION}

docker create --name calicoctl-copy calico/ctl:v${CALICO_VERSION}
docker create --name calico-node-copy calico/node:v${CALICO_VERSION}

docker cp calicoctl-copy:/calicoctl calicoctl
docker cp calico-node-copy:/bin/calico-node calico-node

docker rm calicoctl-copy
docker rm calico-node-copy

chmod +x calico-node calicoctl
mv -f calico-node calicoctl /usr/local/bin/

echo "render calicoctl config"
mkdir -p /etc/calico/
cat > /etc/calico/calicoctl.cfg <<EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/var/lib/kubelet/kubeconfig"
EOF

echo "render kubeconfig"
mkdir -p /var/lib/kubelet/
cat > /var/lib/kubelet/kubeconfig <<'EOF'
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: MASTER_ENDPOINT
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: calico-hms
  name: calico-hms
current-context: calico-hms
users:
- name: calico-hms
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - AWS_DEFAULT_REGION
      - eks
      - get-token
      - --cluster-name
      - CLUSTER_NAME
      - --role-arn
      - IAM_ASSUME_ROLE
      command: /usr/local/bin/aws
EOF
chmod 600 /var/lib/kubelet/kubeconfig

sed -i s,MASTER_ENDPOINT,${APISERVER_ENDPOINT},g /var/lib/kubelet/kubeconfig
sed -i s,AWS_DEFAULT_REGION,${AWS_DEFAULT_REGION},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${CLUSTER_NAME},g /var/lib/kubelet/kubeconfig
sed -i s,IAM_ASSUME_ROLE,${IAM_ASSUME_ROLE},g /var/lib/kubelet/kubeconfig
