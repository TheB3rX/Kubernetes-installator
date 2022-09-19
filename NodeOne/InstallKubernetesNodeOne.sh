#!/bin/bash
echo "Change Hostname..."
sudo hostnamectl set-hostname "k8sworker1.example.net" 
exec bash

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
sudo apt-mark hold kubelet kubeadm kubectlx

echo "Join Worker node to the cluster"
sudo kubeadm join k8smaster.example.net:6443 --token vt4ua6.wcma2y8pl4menxh2 \
   --discovery-token-ca-cert-hash sha256:0494aa7fc6ced8f8e7b20137ec0c5d2699dc5f8e616656932ff9173c94962a36

echo "Test Kubernetes installation"
kubectl create deployment nginx-app --image=nginx --replicas=2
kubectl get deployment nginx-app
kubectl expose deployment nginx-app --type=NodePort --port=80

echo "View service status"
kubectl get svc nginx-app
kubectl describe svc nginx-app

echo "If you wanna acces nginx based app please use the next command"
echo "curl http://<woker-node-ip-addres>:31246"