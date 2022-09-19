#!/bin/bash
echo "Change Hostname..."
sudo hostnamectl set-hostname "k8smaster.example.net"

echo "Done"
exec bash

echo "Edit the nodes with the information"
echo "  192.168.1.173   k8smaster.example.net k8smaster
        192.168.1.174   k8sworker1.example.net k8sworker1
        192.168.1.175   k8sworker2.example.net k8sworker2"

sudo micro /etc/hosts

echo "Disabling swap...."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Load Kernel modules"
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "Set Kernel parameters for Kubernetes"
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF 

echo "Reload changes"
sudo sysctl --system

echo "##########INSTALLATION OF CONTAINERD RUNTIME############"
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

echo "Enable docker repository"
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "Installing containerd"
sudo apt update
sudo apt install -y containerd.io

echo "Configuring containerd to use systemd as cgroup"
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

echo "Restart and enable containerd service"
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Adding apt repository for Kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

echo "Installing Kubernetes components"
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Initialize Kubernetes cluster with Kubeadm"
sudo kubeadm init --control-plane-endpoint=k8smaster.example.net

echo "Start interaction with cluster"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "View cluster and node status"
kubectl cluster-info
kubectl get nodes

echo "Install Calico Pod"
curl https://projectcalico.docs.tigera.io/manifests/calico.yaml -O
kubectl apply -f calico.yaml
kubectl get pods -n kube-system
kubectl get nodes

echo "Test Kubernetes installation"
kubectl create deployment nginx-app --image=nginx --replicas=2
kubectl get deployment nginx-app
kubectl expose deployment nginx-app --type=NodePort --port=80

echo "View service status"
kubectl get svc nginx-app
kubectl describe svc nginx-app

echo "If you wanna acces nginx based app please use the next command"
echo "curl http://<woker-node-ip-addres>:31246"