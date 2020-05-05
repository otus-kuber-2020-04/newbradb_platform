# newbradb_platform
newbradb Platform repository

## Lesson 1. Настройка локального окружения. Запуск первого контейнера. Работа с kubectl

### 1.1 Установка kubectl

Устанавливаем kubectl на Ubuntu: 

```console
 curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
 chmod +x kubectl 
 mv kubectl /usr/local/bin
```

Настраиваем автодополнение:

```console
 sudo apt install bash-completion
 source <(kubectl completion bash)
 echo "source <(kubectl completion bash)" >> ~/.bashrc
```

### 1.2 Установка Minikube

Устанавливаем Minikube на Ubuntu:

```console
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 1.3 Запуск Minikube

```console
minikube start
😄  minikube v1.9.2 on Ubuntu 18.04
✨  Automatically selected the docker driver
👍  Starting control plane node m01 in cluster minikube
🚜  Pulling base image ...
🔥  Creating Kubernetes in docker container with (CPUs=2) , Memory=3900MB  ...
🐳  Preparing Kubernetes v1.18.0 on Docker 19.03.2 ...
    ▪ kubeadm.pod-network-cidr=10.244.0.0/16
🌟  Enabling addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube"
```

Проверим, что подключение к кластеру работает корректно:

```console
kubectl cluster-info
Kubernetes master is running at https://172.17.0.2:8443
KubeDNS is running at https://172.17.0.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 1.4 Minikube

Зайдем на ВМ по SSH и посмотрим запущенные Docker контейнеры:

```console
minikube ssh
docker@minikube:~$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
77edbc276979        67da37a9a360           "/coredns -conf /etc…"   13 minutes ago      Up 12 minutes                           k8s_coredns_coredns-66bff467f8-rwh9f_kube-system_87f92e71-0eb3-4b6e-a1ba-049b1bb482fb_0
7127ff0b135f        67da37a9a360           "/coredns -conf /etc…"   13 minutes ago      Up 13 minutes                           k8s_coredns_coredns-66bff467f8-6ttfh_kube-system_58aaf17d-95a4-422e-8567-7705388d899d_0
ae4116649edd        4689081edb10           "/storage-provisioner"   13 minutes ago      Up 13 minutes                           k8s_storage-provisioner_storage-provisioner_kube-system_1412595b-c229-4be6-94b8-1cc407c81ad6_0
758e1d2da4ce        aa67fec7d7ef           "/bin/kindnetd"          13 minutes ago      Up 13 minutes                           k8s_kindnet-cni_kindnet-p4mgm_kube-system_520e6f50-70d0-4ff9-886c-4f51201802f9_0
fdf554bed153        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_storage-provisioner_kube-system_1412595b-c229-4be6-94b8-1cc407c81ad6_0
cc44021bd2c9        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_coredns-66bff467f8-rwh9f_kube-system_87f92e71-0eb3-4b6e-a1ba-049b1bb482fb_0
be03cd11e29a        43940c34f24f           "/usr/local/bin/kube…"   13 minutes ago      Up 13 minutes                           k8s_kube-proxy_kube-proxy-vk2b7_kube-system_08254dd4-57f1-45f1-b3aa-3d44ff2b5e4e_0
b17fef83e6fe        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_coredns-66bff467f8-6ttfh_kube-system_58aaf17d-95a4-422e-8567-7705388d899d_0
b01906446234        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_kindnet-p4mgm_kube-system_520e6f50-70d0-4ff9-886c-4f51201802f9_0
cdbd07474e73        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_kube-proxy-vk2b7_kube-system_08254dd4-57f1-45f1-b3aa-3d44ff2b5e4e_0
aeb6f8a66762        d3e55153f52f           "kube-controller-man…"   13 minutes ago      Up 13 minutes                           k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_c92479a2ea69d7c331c16a5105dd1b8c_0
860217d0d20b        a31f78c7c8ce           "kube-scheduler --au…"   13 minutes ago      Up 13 minutes                           k8s_kube-scheduler_kube-scheduler-minikube_kube-system_5795d0c442cb997ff93c49feeb9f6386_0
39ec49882613        303ce5db0e90           "etcd --advertise-cl…"   13 minutes ago      Up 13 minutes                           k8s_etcd_etcd-minikube_kube-system_ca02679f24a416493e1c288b16539a55_0
746883597ee4        74060cea7f70           "kube-apiserver --ad…"   13 minutes ago      Up 13 minutes                           k8s_kube-apiserver_kube-apiserver-minikube_kube-system_45e2432c538c36239dfecde67cb91065_0
5d3fc1ab1c63        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_kube-scheduler-minikube_kube-system_5795d0c442cb997ff93c49feeb9f6386_0
3ba06a4ba2ee        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_kube-controller-manager-minikube_kube-system_c92479a2ea69d7c331c16a5105dd1b8c_0
b3759c49cc60        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_kube-apiserver-minikube_kube-system_45e2432c538c36239dfecde67cb91065_0
e7b53f54ce6b        k8s.gcr.io/pause:3.2   "/pause"                 13 minutes ago      Up 13 minutes                           k8s_POD_etcd-minikube_kube-system_ca02679f24a416493e1c288b16539a55_0
```

Проверим, что Kubernetes обладает некоторой устойчивостью к отказам, удалим все контейнеры:

```console
docker rm -f $(docker ps -a -q)
77edbc276979
7127ff0b135f
```

### 1.5 kubectl

Выведем компоненты из пункта 1.4 в виде pods в namespace kube-system: 

```console
kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-66bff467f8-6ttfh           1/1     Running   0          19m
coredns-66bff467f8-rwh9f           1/1     Running   0          19m
etcd-minikube                      1/1     Running   1          19m
kindnet-p4mgm                      1/1     Running   0          19m
kube-apiserver-minikube            1/1     Running   0          19m
kube-controller-manager-minikube   1/1     Running   0          19m
kube-proxy-vk2b7                   1/1     Running   0          19m
kube-scheduler-minikube            1/1     Running   0          19m
storage-provisioner                1/1     Running   0          19m
```

Еще одна проверка на прочность:

```console
kubectl delete pod --all -n kube-system
pod "coredns-66bff467f8-6ttfh" deleted
pod "coredns-66bff467f8-rwh9f" deleted
pod "etcd-minikube" deleted
pod "kindnet-p4mgm" deleted
pod "kube-apiserver-minikube" deleted
pod "kube-controller-manager-minikube" deleted
pod "kube-proxy-vk2b7" deleted
pod "kube-scheduler-minikube" deleted
pod "storage-provisioner" deleted
```

Проверим, что кластер находится в рабочем состоянии:

```console
kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}
```

### 1.6 Задание

Почему все pod в namespace kube-system восстановились?

- etcd, kube-apiserver, kube-controller-manager, kube-scheduler   
Описаны манифестами в папке /etc/kubernetes/manifests 
kubelet использует эту папку как pod-manifest-path для static-pods

- coredns восстанавливется через replicaset где desired имеет значение 2.   
Проверить можно с помощью kubectl :

```console
kubectl get all -n kube-system
NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/kindnet      1         1         1       1            1           <none>                   71m
daemonset.apps/kube-proxy   1         1         1       1            1           kubernetes.io/os=linux   71m

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coredns   2/2     2            2           71m

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/coredns-66bff467f8   2         2         2       71m
``` 

- там же видно, что kube-proxy и kindnet поднимает daemonset 

### 1.7 Dockerfile 

1. Запускающий web-сервер на порту 8000   

```Dockerfile
FROM httpd:2.4
COPY httpd.conf /usr/local/apache2/conf/
EXPOSE 8000 
```
В httpd.conf меняем Listen на 8000

2. Отдающий содержимое директории /app внутри контейнера  

Меняем DocumentRoot и копируем app папку 

```Dockerfile
COPY app/ /app
```

3. Работающий с UID 1001

```Dockerfile
RUN usermod -u 1001 nobody
RUN chown -R nobody: /app
RUN chown -R nobody: /usr/local/apache2/logs/
USER 1001
```

4. Пушим контейнер в публичный Docker Registry. 

### 1.8 Манифест pod

Напишем манифест web-pod.yaml и применим его 

```console
kubectl apply -f web-pod.yaml
pod/web created
```

pod web появился 

```console
kubectl get pods
NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          116s
```

### 1.9 kubectl describe

Успешный запуск выглядит так:  

```console
Events:
  Type    Reason     Age        From               Message
  ----    ------     ----       ----               -------
  Normal  Scheduled  <unknown>  default-scheduler  Successfully assigned default/web to minikube
  Normal  Pulling    6m50s      kubelet, minikube  Pulling image "newbradburyfan/less1_web:0.1"
  Normal  Pulled     6m36s      kubelet, minikube  Successfully pulled image "newbradburyfan/less1_web:0.1"
  Normal  Created    6m36s      kubelet, minikube  Created container web
  Normal  Started    6m36s      kubelet, minikube  Started container web
```

Ломаем pod, добавив неправильный image : 

```console
  Warning  Failed     1s         kubelet, minikube  Failed to pull image "less1_web_broken:0.1": rpc error: code = Unknown desc = Error response from daemon: pull access denied for newbradburyfan/less1_web_broken, repository does not exist or may require 'docker login': denied: requested access to the resource is denied
  Warning  Failed     1s         kubelet, minikube  Error: ErrImagePull
```

### 1.10 init containers 

Описываем init контейнер в web-pod.yaml

```console
  initContainers:
  - name: init-web
    image: busybox:1.31
    command: ['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
```

Добавляем volumes и volumeMounts  

### 1.11 Запуск pod

Удаляем существующий и запускаем снова :

```console
kubectl apply -f web-pod.yaml && kubectl get pods -w
pod/web created
NAME   READY   STATUS     RESTARTS   AGE
web    0/1     Init:0/1   0          0s
web    0/1     Init:0/1   0          6s
web    0/1     PodInitializing   0          7s
web    1/1     Running           0          8s
```

Воспользуемся командой kubectl port-forward для проверки работоспособности.  


[Test link](http://localhost:8000/index.html) показывает лого Express 42. Pod с веб сервером поднялся.

### 1.12 Hipster Shop | Задание со⭐

Находим причину неисправности:  

```console
kubectl logs frontend
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set

goroutine 1 [running]:
main.mustMapEnv(0xc0003b2000, 0xb0f14e, 0x1c)
	/go/src/github.com/GoogleCloudPlatform/microservices-demo/src/frontend/main.go:259 +0x10e
main.main()
	/go/src/github.com/GoogleCloudPlatform/microservices-demo/src/frontend/main.go:117 +0x4ff
```

Копируем необходимые env значения в healthy-frontend-pod.yaml :

```YAML
    env:
    - name: PORT
      value: "8080"
    - name: PRODUCT_CATALOG_SERVICE_ADDR
      value: "productcatalogservice:3550"
    - name: CURRENCY_SERVICE_ADDR
      value: "currencyservice:7000"
    - name: CART_SERVICE_ADDR
      value: "cartservice:7070"
    - name: RECOMMENDATION_SERVICE_ADDR
      value: "recommendationservice:8080"
    - name: SHIPPING_SERVICE_ADDR
      value: "shippingservice:50051"
    - name: CHECKOUT_SERVICE_ADDR
      value: "checkoutservice:5050"
    - name: AD_SERVICE_ADDR
      value: "adservice:9555"
    - name: ENV_PLATFORM
      value: "gcp"
```

Pod перешел в статус Running: 

```console
NAME       READY   STATUS    RESTARTS   AGE
frontend   1/1     Running   0          7m4s
```
