# newbradb_platform
newbradb Platform repository

## Homework 2. Kubernetes controllers.ReplicaSet, Deployment, DaemonSet

### 2.1 ReplicaSet

Создадим манифест frontend-replicaset.yaml и запустим одну реплику микросервиса frontend.  
Получаем ошибку  

```console
error: error validating "frontend-replicaset.yaml": error validating data: ValidationError(ReplicaSet.spec): missing required field "selector" in io.k8s.api.apps.v1.ReplicaSetSpec; if you choose to ignore these errors, turn validation off with --validate=false
```

Добавим selector в манифест frontend-replicaset.yaml :

```YAML
  selector:
    matchLabels:
      app: frontend
```

Применим манифест и выведем реплики микросервиса frontend : 

```console
$ kubectl get pods -l app=frontend
NAME             READY   STATUS             RESTARTS   AGE
frontend-q2spz   0/1     CrashLoopBackOff   3          74s
```

Error status потому что не указны переменные :

```console
$ kubectl logs frontend-q2spz
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set

```

Добавим переменые из предыдущего урока:

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

Выведем реплики микросервиса frontend:

```console
NAME             READY   STATUS    RESTARTS   AGE
frontend-l5gcj   1/1     Running   0          15s
```

Увеличим количество реплик сервиса ad-hoc командой:

```console
$ kubectl scale replicaset frontend --replicas=3
replicaset.apps/frontend scaled

$ kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       31m
```

Проверим, что благодаря контроллеру pod'ы действительно восстанавливаются после их ручного удаления:

```console
$ kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w
NAME             READY   STATUS    RESTARTS   AGE
frontend-cbbwx   1/1     Running   0          64s
frontend-qrw7l   1/1     Running   0          64s
frontend-rtc86   1/1     Running   0          64s
frontend-cbbwx   1/1     Terminating   0          64s
frontend-qrw7l   1/1     Terminating   0          64s
frontend-fcrz2   0/1     Pending       0          0s
frontend-fcrz2   0/1     Pending       0          0s
frontend-rtc86   1/1     Terminating   0          64s
frontend-w6hd8   0/1     Pending       0          0s
frontend-b94jq   0/1     Pending       0          0s
frontend-w6hd8   0/1     Pending       0          0s
frontend-fcrz2   0/1     ContainerCreating   0          0s
frontend-b94jq   0/1     Pending             0          0s
frontend-b94jq   0/1     ContainerCreating   0          0s
frontend-w6hd8   0/1     ContainerCreating   0          0s
frontend-rtc86   0/1     Terminating         0          64s
frontend-cbbwx   0/1     Terminating         0          64s
frontend-qrw7l   0/1     Terminating         0          64s
frontend-b94jq   1/1     Running             0          1s
frontend-w6hd8   1/1     Running             0          1s
frontend-fcrz2   1/1     Running             0          1s
```

Повторно применим манифест frontend-replicaset.yaml. Количество реплик вновь уменьшилось до одной :

```console
$ kubectl apply -f frontend-replicaset.yaml
replicaset.apps/frontend configured

$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-w6hd8   1/1     Running   0          9m39s
```  

Изменим манифест, чтобы сразу разворачивались три реплики сервиса :

```YAML
  replicas: 3
```

Вновь применим его. Поднялись три реплики сервиса :

```console
$ kubectl apply -f frontend-replicaset.yaml
replicaset.apps/frontend configured

$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-5xzfk   1/1     Running   0          9m24s
frontend-w6hd8   1/1     Running   0          32m
frontend-w6ssf   1/1     Running   0          9m24s
```

### 2.2 Обновление ReplicaSet

Перетегируем старый образ, добавим его в манифест и применим :

```console
$ kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w
NAME             READY   STATUS    RESTARTS   AGE
frontend-5xzfk   1/1     Running   0          24m
frontend-w6hd8   1/1     Running   0          47m
frontend-w6ssf   1/1     Running   0          24m
```

Проверим образ, указанный в ReplicaSet:

```console
$ kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
newbradburyfan/shop:v0.0.2
```

И образ из которого сейчас запущены pod:

```console
$ kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
newbradburyfan/shop:0.1 newbradburyfan/shop:0.1 newbradburyfan/shop:0.1
```

Удалим все запущеные pod, проверим из какого образа перезапустились :

```console
$ kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
newbradburyfan/shop:v0.0.2 newbradburyfan/shop:v0.0.2 newbradburyfan/shop:v0.0.2
```

Как показали примеры выше, ReplicaSet проверяет только количество запущеных pod.  
ReplicaSet не умеет рестартовать pod.    

### 2.3 Deployment

Cоберем 2 образa paymentservice с тегамиv0.0.1 и v0.0.2.  
Создадим манифест paymentservice-replicaset.yaml с тремя репликами, разворачивающими из образа версии v0.0.1:  

```console
$ kubectl get pods -l app=paymentservice
NAME                   READY   STATUS    RESTARTS   AGE
paymentservice-4ghd5   1/1     Running   0          3m33s
paymentservice-8xlw6   1/1     Running   0          3m33s
paymentservice-tcwgq   1/1     Running   0          3m33s

$ kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'
newbradburyfan/paymentservice:v0.0.1 newbradburyfan/paymentservice:v0.0.1 newbradburyfan/paymentservice:v0.0.1
```
Создадим манифест paymentservice-deployment.yaml с kind Deployment вместо Replicaset. 
Применим манифест,  предварительно удалив существующую реплику :

```console
$ kubectl delete rs paymentservice
replicaset.apps "paymentservice" deleted

$ kubectl get pods -l app=paymentservice
No resources found in default namespace.

$ kubectl apply -f paymentservice-deployment.yaml
deployment.apps/paymentservice created

$ kubectl get pods -l app=paymentservice
NAME                             READY   STATUS    RESTARTS   AGE
paymentservice-cb846dcc7-7hpvx   1/1     Running   0          58s
paymentservice-cb846dcc7-8f7ps   1/1     Running   0          58s
paymentservice-cb846dcc7-cwh7j   1/1     Running   0          58s
```

Также, помимо 3 pod у нас появился Deployment и новый ReplicaSet 

```console
$ kubectl get deployments
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
paymentservice   3/3     3            3           2m7s
$ kubectl get rs
NAME                       DESIRED   CURRENT   READY   AGE
paymentservice-cb846dcc7   3         3         3       2m13s
```

### 2.4 Обновление Deployment

Обновим Deployment на версию образа v0.0.2 и применим манифест.  
Все новые pod развернуты из образа v0.0.2: 

```console
$ kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'
newbradburyfan/paymentservice:v0.0.2 newbradburyfan/paymentservice:v0.0.2 newbradburyfan/paymentservice:v0.0.2
```

Также создано два ReplicaSet: 

```console
$ kubectl get rs
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-75f846bb64   3         3         3       7m44s
paymentservice-cb846dcc7    0         0         0       15m

```
Посмотрим историю версий нашего Deployment:  

```console
$ kubectl rollout history deployment paymentservice
deployment.apps/paymentservice 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### 2.5 Deployment | Rollback

Представим, что обновление прошло неудачно и сделаем откат:

```console
$ kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-75f846bb64   0         0         0       14m
paymentservice-cb846dcc7    3         3         3       18m
paymentservice-75f846bb64   0         0         0       14m
paymentservice-75f846bb64   1         0         0       14m


```
Podы вернулись на первую версию образа :

```console
$ kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'
newbradburyfan/paymentservice:v0.0.1 newbradburyfan/paymentservice:v0.0.1 newbradburyfan/paymentservice:v0.0.1
```

### 2.6 Deployment | Задание со⭐

Добавим стратегию развертывания в манифест paymentservice-deployment-bg.yaml :

```YAML
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 0
```

Как видим сначала создаются три новых контейнера, а потом удаляются старые :

```console
$ kubectl apply -f paymentservice-deployment-bg.yaml | kubectl get pods -l app=paymentservice -w
NAME                             READY   STATUS    RESTARTS   AGE
paymentservice-cb846dcc7-d698f   1/1     Running   0          33m
paymentservice-cb846dcc7-rvkh8   1/1     Running   0          33m
paymentservice-cb846dcc7-vwjw4   1/1     Running   0          33m
paymentservice-75f846bb64-q9dr9   0/1     Pending   0          0s
paymentservice-75f846bb64-psrxv   0/1     Pending   0          0s
paymentservice-75f846bb64-q9dr9   0/1     Pending   0          0s
paymentservice-75f846bb64-jqcvw   0/1     Pending   0          0s
paymentservice-75f846bb64-psrxv   0/1     Pending   0          0s
paymentservice-75f846bb64-jqcvw   0/1     Pending   0          0s
paymentservice-75f846bb64-q9dr9   0/1     ContainerCreating   0          0s
paymentservice-75f846bb64-psrxv   0/1     ContainerCreating   0          0s
paymentservice-75f846bb64-jqcvw   0/1     ContainerCreating   0          0s
paymentservice-75f846bb64-jqcvw   1/1     Running             0          0s
paymentservice-cb846dcc7-rvkh8    1/1     Terminating         0          33m
paymentservice-75f846bb64-psrxv   1/1     Running             0          0s
paymentservice-75f846bb64-q9dr9   1/1     Running             0          0s
paymentservice-cb846dcc7-d698f    1/1     Terminating         0          33m
paymentservice-cb846dcc7-vwjw4    1/1     Terminating         0          33m
paymentservice-cb846dcc7-d698f    0/1     Terminating         0          33m
paymentservice-cb846dcc7-vwjw4    0/1     Terminating         0          33m
```

Реализуем другую стратегию развертывания в манифесте paymentservice-deployment-reverse.yaml :

```YAML
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

По этой стратегии удаляется один старый pod и создается один новый:  

```console
$ kubectl apply -f paymentservice-deployment-reverse.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-75f846bb64-jqcvw   1/1     Running   0          14m
paymentservice-75f846bb64-psrxv   1/1     Running   0          14m
paymentservice-75f846bb64-q9dr9   1/1     Running   0          14m
paymentservice-cb846dcc7-kjpzw    0/1     Pending   0          0s
paymentservice-cb846dcc7-kjpzw    0/1     Pending   0          0s
paymentservice-75f846bb64-jqcvw   1/1     Terminating   0          14m
paymentservice-cb846dcc7-kjpzw    0/1     ContainerCreating   0          0s
paymentservice-cb846dcc7-wggvf    0/1     Pending             0          0s
paymentservice-cb846dcc7-wggvf    0/1     Pending             0          0s
paymentservice-cb846dcc7-wggvf    0/1     ContainerCreating   0          0s
paymentservice-cb846dcc7-kjpzw    1/1     Running             0          0s
paymentservice-75f846bb64-psrxv   1/1     Terminating         0          14m
paymentservice-cb846dcc7-hgnzd    0/1     Pending             0          0s
paymentservice-cb846dcc7-hgnzd    0/1     Pending             0          1s
paymentservice-cb846dcc7-hgnzd    0/1     ContainerCreating   0          1s
paymentservice-cb846dcc7-wggvf    1/1     Running             0          1s
paymentservice-75f846bb64-q9dr9   1/1     Terminating         0          14m
paymentservice-cb846dcc7-hgnzd    1/1     Running             0          1s
paymentservice-75f846bb64-jqcvw   0/1     Terminating         0          15m
paymentservice-75f846bb64-q9dr9   0/1     Terminating         0          15m
```

### 2.7 Probes 

Создадим манифест frontend-deployment.yaml и добавим туда описание readinessProbe :

```YAML
          ports:
          - containerPort: 8080
          readinessProbe:
            initialDelaySeconds: 10
            httpGet:
              path: "/_healthz"
              port: 8080
              httpHeaders:
              - name: "Cookie"
                value: "shop_session-id=x-readiness-probe"
```

Види три запущенных pod c указанием readinessProbe :

```console
$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
frontend-8494458dd7-6tbdz   1/1     Running   0          2m46s
frontend-8494458dd7-gq8pf   1/1     Running   0          2m46s
frontend-8494458dd7-tsjt4   1/1     Running   0          2m46s

$ kubectl describe pod frontend-8494458dd7-6tbdz

Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
```

Cымитируем некорректную работу приложения, изменив название readinessProbe :

```console
NAME                        READY   STATUS    RESTARTS   AGE
frontend-55c64dc7d-2zlbw    0/1     Running   0          14m

Warning  Unhealthy  35s (x89 over 15m)  kubelet, kind-worker  Readiness probe failed: HTTP probe failed with statuscode: 404
```

### 2.8 DaemonSet | Задание со ⭐

Скопипастим манифест node-exporter-daemonset.yaml и применим его.  

Затестим как отдаются метрики :

```console
$ kubectl port-forward node-exporter-4pjr8 9100:9100
Forwarding from 127.0.0.1:9100 -> 9100
Forwarding from [::1]:9100 -> 9100

$ curl localhost:9100/metrics
# HELP go_gc_duration_seconds A summary of the GC invocation durations.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0
go_gc_duration_seconds{quantile="0.25"} 0
go_gc_duration_seconds{quantile="0.5"} 0
go_gc_duration_seconds{quantile="0.75"} 0
go_gc_duration_seconds{quantile="1"} 0
go_gc_duration_seconds_sum 0
go_gc_duration_seconds_count 0
# HELP go_goroutines Number of goroutines that currently exist.
```

### 2.9 DaemonSet | Задание с ⭐ ⭐

Если Node Exporter не запускается на мастре нодах добавим cледующие tollerations :  

```YAML
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
	  effect: NoSchedule
```


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
