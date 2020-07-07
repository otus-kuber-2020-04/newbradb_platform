# newbradb_platform
newbradb Platform repository

### Homework 7. Операторы, CustomResourceDefinition

Работать будем в minikube :

```console
$ minikube start
```

Cоздадим CustomResource deploy/cr.yml и попробуем применить :  

```console
$ kubectl apply -f deploy/cr.yml 
error: unable to recognize "deploy/cr.yml": no matches for kind "MySQL" in version "otus.homework/v1"
```

Ошибка связана с отсутсвием объектов типа MySQL в API kubernetes.

Создадим CRD deploy/crd.yml и пересоздадим CR :

```console
$ kubectl apply -f deploy/crd.yml
customresourcedefinition.apiextensions.k8s.io/mysqls.otus.homework created

$ kubectl apply -f deploy/cr.yml 
mysql.otus.homework/mysql-instance created
```

C созданными объектами можно взаимодействовать через kubectl:

```console
$ kubectl get crd
NAME                   CREATED AT
mysqls.otus.homework   2020-06-26T14:43:27Z

$ kubectl get mysqls.otus.homework
NAME             AGE
mysql-instance   79s

$ kubectl describe mysqls.otus.homework mysql-instance
Name:         mysql-instance
Namespace:    default
Labels:       <none>
Annotations:  API Version:  otus.homework/v1
Kind:         MySQL
Metadata:
  Creation Timestamp:  2020-06-26T14:50:43Z
  Generation:          1
  Managed Fields:
    API Version:  otus.homework/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:database:
        f:image:
        f:password:
        f:storage_size:
      f:usless_data:
    Manager:         kubectl
    Operation:       Update
    Time:            2020-06-26T14:50:43Z
  Resource Version:  10105
  Self Link:         /apis/otus.homework/v1/namespaces/default/mysqls/mysql-instance
  UID:               d16be27b-9ea3-4786-b466-78cccf0ff0c1
Spec:
  Database:      otus-database
  Image:         mysql:5.7
  Password:      otuspassword
  storage_size:  1Gi
usless_data:     useless info
Events:          <none>
```

## Деплой  оператора

Применим манифесты:
- service-account.yml
- role.yml
- role-binding.yml
- deploy-operator.yml

Проверяем что появились pvc:

```console
$ kubectl get pvc
NAME                        STATUS   VOLUME                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
backup-mysql-instance-pvc   Bound    backup-mysql-instance-pv   1Gi        RWO                           13m
mysql-instance-pvc          Bound    mysql-instance-pv          1Gi        RWO                           13m
```

Заполним базу созданного mysql-instance:

```console
$ export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath=" {.items[*].metadata.name}")
$ kubectl exec -it $MYSQLPOD -- mysql -u root -potuspassword -e "CREATE TABLE test ( id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id) );" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
$ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test (id, name) VALUES ( null, 'some data' );" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
$ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name ) VALUES ( null, 'some data-2' );" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
```

Посмотрим содержание таблицы :

```console
 kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+
```

Удалим mysql-instance:

```console
$ kubectl delete mysqls.otus.homework mysql-instance
mysql.otus.homework "mysql-instance" deleted
```

Job выполнилась :

```console
$ kubectl get jobs.batch
NAME                         COMPLETIONS   DURATION   AGE
backup-mysql-instance-job    1/1           0s         64s
```

Создадим заново mysql-instance:

```console 
$ kubectl apply -f kubernetes-operators/deploy/cr.yml 
mysql.otus.homework/mysql-instance created
$ export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath=" {.items[*].metadata.name}")
$ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+
```


## Homework 6. Шаблонизация манифестов Kubernetes

### 6.1 Intro

Устанавливаем google sdk :

```
# Add the Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update the package list and install the Cloud SDK
sudo apt-get update && sudo apt-get install google-cloud-sdk
```

Инициализируем gcloud. Там выбираем проект и регион

```console
$ gcloud init

```

Включаем API и создаем кластер 

```console
$ gcloud services enable container.googleapis.com
$ gcloud container clusters create cluster1

```

Настроим kubectl на локальной машине:

```console
$ gcloud container clusters get-credentials cluster1

```

## 6.2 Устанавливаем готовые Helm charts

Установим Helm 3 :

```console
$ snap install helm --classic

$ helm version
version.BuildInfo{Version:"v3.2.3", GitCommit:"8f832046e258e2cb800894579b1b3b50c2d83492", GitTreeState:"clean", GoVersion:"go1.13.12"}
```

Добавим репозиторий stable :

```console
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com
"stable" has been added to your repositories
$ helm repo list
NAME  	URL                                             
stable	https://kubernetes-charts.storage.googleapis.com

```

Установка nginx-ingress.
Создадим namespace и release nginx-ingress

```console
$ kubectl create ns nginx-ingress
namespace/nginx-ingress created

$ helm upgrade --install nginx-ingress stable/nginx-ingress --wait \
> --namespace=nginx-ingress \
> --version=1.39.0
Release "nginx-ingress" does not exist. Installing it now.

$ kubectl get secrets -n nginx-ingress | grep nginx-ingress
sh.helm.release.v1.nginx-ingress.v1   helm.sh/release.v1                    1      6m29s
```

Установка сert-manager.
Добавим репозиторий, в котором хранится актуальный helm chart cert-manager:

```console
$ helm repo add jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories
$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈ 
```

Создадим namespace

```console
kubectl create namespace cert-manager
namespace/cert-manager created
```

Также для установки cert-manager предварительно потребуется создать в кластере некоторые **CRD**:

```console
$ kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager-legacy.crds.yaml
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
```


Установим cert-manager:

```console
$ helm install \
>   cert-manager jetstack/cert-manager \
>   --namespace cert-manager \
>   --version v0.15.1
NAME: cert-manager
LAST DEPLOYED: Mon Jun 22 09:59:25 2020
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
cert-manager has been deployed successfully!

```

Посмотрим pods :

```console
$ kubectl get pods -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-75856bb467-m7zs9              1/1     Running   0          31s
cert-manager-cainjector-597f5b4768-fb5rm   1/1     Running   0          31s
cert-manager-webhook-5c9f7b5f75-jmbsl      1/1     Running   0          31s
```

И для корректной работы должен быть создан ClusterIssuer:

```YAML
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: email@gmail.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - http01:
        ingress:
          class:  nginx
```

Проверим статус :  

```console
$ kubectl apply -f kubernetes-templating/cert-manager/issuer.yaml 
clusterissuer.cert-manager.io/letsencrypt-production created

$ kubectl describe clusterissuers -n cert-manager
Name:         issuer
Namespace:    
Labels:       <none>
Annotations:  API Version:  cert-manager.io/v1alpha2
Kind:         ClusterIssuer
Metadata:
  Creation Timestamp:  2020-06-22T07:21:58Z
  Generation:          1
  Resource Version:    9667
  Self Link:           /apis/cert-manager.io/v1alpha2/clusterissuers/issuer
  UID:                 0ebe7dd3-b459-11ea-8de8-42010aa4006c
Spec:
  Acme:
    Email:  newbradburyfan@gmail.com
    Private Key Secret Ref:
      Name:  letsencrypt-production
    Server:  https://acme-staging-v02.api.letsencrypt.org/directory
    Solvers:
      http01:
        Ingress:
          Class:  nginx
Status:
  Acme:
    Last Registered Email:  e,ao;gmail.com
    Uri:                    https://acme-staging-v02.api.letsencrypt.org/acme/acct/14288481
  Conditions:
    Last Transition Time:  2020-06-22T07:21:59Z
    Message:               The ACME account was registered with the ACME server
    Reason:                ACMEAccountRegistered
    Status:                True
    Type:                  Ready
Events:                    <none>


Name:         letsencrypt-production
Namespace:    
Labels:       <none>
Annotations:  API Version:  cert-manager.io/v1alpha2
Kind:         ClusterIssuer
Metadata:
  Creation Timestamp:  2020-06-22T08:41:29Z
  Generation:          1
  Resource Version:    32296
  Self Link:           /apis/cert-manager.io/v1alpha2/clusterissuers/letsencrypt-production
  UID:                 2a983314-b464-11ea-8de8-42010aa4006c
Spec:
  Acme:
    Email:  email@gmail.com
    Private Key Secret Ref:
      Name:  letsencrypt-production
    Server:  https://acme-v02.api.letsencrypt.org/directory
    Solvers:
      http01:
        Ingress:
          Class:  nginx
Status:
  Acme:
    Last Registered Email:  email@gmail.com
    Uri:                    https://acme-v02.api.letsencrypt.org/acme/acct/89448190
  Conditions:
    Last Transition Time:  2020-06-22T08:41:30Z
    Message:               The ACME account was registered with the ACME server
    Reason:                ACMEAccountRegistered

```

Установка сhartmuseum.  
Создаем файл values.yaml для chartmuseum, который включает :  
- Создание ingress ресурса с корректным hosts.name (должен использоваться nginx-ingress)
- Автоматическую генерацию Let's Encrypt сертификата

```YAML
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-production"
  hosts:
    - name: chartmuseum.35.204.214.4.nip.io
      path: /
      tls: true
      tlsSecret: chartmuseum.35.204.214.4.nip.io
securityContext: {}
env:
  open:
    DISABLE_API: false
```

Создадим namespace и установим сhartmuseum:

```console
$ kubectl create ns chartmuseum
namespace/chartmuseum created

$ helm upgrade --install chartmuseum stable/chartmuseum --wait \
> --namespace=chartmuseum \
> --version=2.3.2 \
> -f values.yaml 
Release "chartmuseum" does not exist. Installing it now.
NAME: chartmuseum
LAST DEPLOYED: Mon Jun 22 11:28:20 2020
NAMESPACE: chartmuseum
STATUS: deployed
```

Проверим, что release chartmuseum установился:

```console
$ helm ls -n chartmuseum
NAME       	NAMESPACE  	REVISION	UPDATED                                 	STATUS  	CHART            	APP VERSION
chartmuseum	chartmuseum	1       	2020-06-22 11:28:20.690461436 +0300 EEST	deployed	chartmuseum-2.3.2	0.8.2     
```

Проверим сертификат на https://chartmuseum.35.204.214.4.nip.io/  
Он валидный :

```
This certificate has been verified for the following usages:

SSL Server Certificate

Issued by: 

Common Name (CN)	Let's Encrypt Authority X3
Organization (O)	Let's Encrypt
```

## Установка harbor
Пишем манифест values.yaml

```YAML
 expose:
  type: ingress
  tls:
    enables: true
    secretName: harbor.35.204.214.4.nip.io
    notarySecretName: notary.35.204.214.4.nip.io
  ingress:
    hosts:
      core: harbor.35.204.214.4.nip.io
    annotations:
      kubernetes.io/ingress.class: "nginx"
      cert-manager.io/cluster-issuer: "letsencrypt-production"
notary:
  enabled: false
```

Добавляем helm repo
```console
$ helm repo add harbor https://helm.goharbor.io
"harbor" has been added to your repositories

$helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈ 
```

Создаем namespace и устанавливем harbor :
```console
$ kubectl create ns harbor
namespace/harbor created

$ helm upgrade --install harbor harbor/harbor --wait --namespace=harbor --version=1.3.2 -f values.yaml 
Release "harbor" does not exist. Installing it now.
NAME: harbor
LAST DEPLOYED: Mon Jun 22 13:54:52 2020
NAMESPACE: harbor
STATUS: deployed
REVISION: 1
```

Проверяем  https://harbor.35.204.214.4.nip.io/ :

```console
$ curl https://harbor.35.204.214.4.nip.io/
<!doctype html>
<html>

<head>
    <meta charset="utf-8">
    <title>Harbor</title>

```

### Создаем свой helm chart

Стандартными средствами helm инициализируем структуру директории с содержимым будущего helm chart:

```console
$ helm create kubernetes-templating/hipster-shop
Creating kubernetes-templating/hipster-shop
```

Перенесем файл all-hipster-shop.yaml в директорию templates и попробуем установить наш helm chart :

```console
$ kubectl create ns hipster-shop
namespace/hipster-shop created

$ helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" does not exist. Installing it now.
NAME: hipster-shop
LAST DEPLOYED: Mon Jun 22 14:16:49 2020
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
``` 

Выносим все что связано с frontend в отдельный helm chart.

Создадим заготовку:

```console
$ helm create kubernetes-templating/frontend
Creating kubernetes-templating/frontend
```

Создадим файлы service.yaml, ingress.yaml, deployment.yaml в папке templates 
Выносим описание deployment и service для frontend из файла all-hipster-shop.yaml и переустановим chart hipster-shop ::

```console
$ helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Mon Jun 22 14:42:08 2020
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

Доступа к frontend больше нет :
```console
$ kubectl get svc -n hipster-shop -l app=frontend
No resources found in hipster-shop namespace.

```

Устанавливываем chart frontend :
```console
$ helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop
Release "frontend" does not exist. Installing it now.
NAME: frontend
LAST DEPLOYED: Mon Jun 22 14:48:52 2020
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Доступ к frontend появился :

```console
$ kubectl get svc -n hipster-shop -l app=frontend
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend   NodePort   10.59.240.252   <none>        80:32620/TCP   2m40s
```

Пришло время минимально шаблонизировать наш chart *frontend*  

Для начала продумаем структуру файла values.yaml
- Docker образ из которого выкатывается frontend может  пересобираться, поэтому логично вынести его тег в переменную *frontend.image.tag*

В values.yaml это будет выглядеть следующим образом:

```YAML
image:
tag: v0.1.3
```
Теперь в манифесте deployment.yaml надо указать, что мы хотим использовать это переменную.  

Было:
```
image: gcr.io/google-samples/microservices-demo/frontend:v0.1.3
```
Стало:
```
image: gcr.io/google-samples/microservices-demo/frontend:{{ .Values.image.tag }}
```

Аналогичным образом шаблонизируем Port, targetPort и NodePort и количестов реплик.
Получаем файл values.yaml

```YAML
image:
  tag: v0.1.3

replicas: 1

service:
  type: NodePort
  port: 80
  targetPort: 8080
  NodePort: 32500
```

Необходимо включить frontend  в зависимости приложения hipster-shop.  
Для начала, удалим release frontend из кластера:

```console
$ helm delete frontend -n hipster-shop
release "frontend" uninstalled
```

Добавляем frontend как зависимость в Chart.yaml 

```YAML
dependencies:
  - name: frontend
    version: 0.1.0
    repository: "file://../frontend"
```

Обновим зависимости :

```console
$ helm dep update kubernetes-templating/hipster-shop
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts
```

В директории kubernetes-templating/hipster-shop/charts
появился архив frontend-0.1.0.tgz содержащий chart frontend

Обновим release *hipster-shop* и убедимся, что ресурсы frontend вновь созданы.

```console
$ helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Wed Jun 24 14:43:23 2020
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 2
TEST SUITE: None

$ kubectl get svc -n hipster-shop -l app=frontend
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend   NodePort   10.59.242.146   <none>        80:32500/TCP   32s
```

Осталось понять, как из CI-системы мы можем менять параметры helm chart, описанные в values.yaml.

Для этого существует специальный ключ **--set**

> Так как как мы меняем значение переменной для зависимости - перед названием переменной указываем имя (название chart) этой зависимости.  
> Если бы мы устанавливали chart frontend напрямую, то команда выглядела бы как --set service.NodePort=31234

Изменим NodePort для **frontend** в release, не меняя его в самом chart:

```console
$ helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop --set frontend.service.NodePort=31234
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Wed Jun 24 14:46:51 2020
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 3
TEST SUITE: None

$ kubectl get svc -n hipster-shop -l app=frontend
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend   NodePort   10.59.242.146   <none>        80:31234/TCP   4m11s
```

### Kubecfg

Выносим манифесты описывающие service и deployment для этих микросервисов из файла all-hipster-shop.yaml в директорию kubernetes-templating/kubecfg

Устанавливаем kubecfg 

```console
$ kubecfg version
kubecfg version: v0.16.0
jsonnet version: v0.15.0
client-go version: v0.0.0-master+$Format:%h$
```

Устанавливаем libsonnet библиотеку и пишем services.jsonnet

Установим манифесты

```console
$ kubecfg update services.jsonnet --namespace hipster-shop
INFO  Validating deployments paymentservice
INFO  validate object "apps/v1beta2, Kind=Deployment"
INFO  Validating services paymentservice
INFO  validate object "/v1, Kind=Service"
INFO  Validating deployments shippingservice
INFO  validate object "apps/v1beta2, Kind=Deployment"
INFO  Validating services shippingservice
INFO  validate object "/v1, Kind=Service"
INFO  Fetching schemas for 4 resources
INFO  Creating services paymentservice
INFO  Creating services shippingservice
INFO  Creating deployments paymentservice
INFO  Creating deployments shippingservice
```

### Kustomize

Вынесем еще один сервис в kubernetes-templating/kustomize/base 

В директории kubernetes-templating/kustomize/overrides добавим окружения prod и dev

Устанавливываем :

```console
$ kubectl apply -k kubernetes-templating/kustomize/overrides/prod/
service/prod-adservice created
deployment.apps/prod-adservice created
$ kubectl apply -k kubernetes-templating/kustomize/overrides/dev
service/dev-adservice created
deployment.apps/dev-adservice created

```


## Homework 5. Volumes

Применим манифест minio-statefulset.yaml c StatefulSet конфигурацией :

```console
$ kubectl apply -f minio-statefulset.yaml
statefulset.apps/minio created
```

Проверим есть ли pod и PVC :  

```
$ kubectl get pods
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          19s

$ kubectl get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-7fa871b5-a65f-448c-948c-1bbdca47c331   10Gi       RWO            standard       6m7s

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-7fa871b5-a65f-448c-948c-1bbdca47c331   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                8m6s

$ kubectl get pods
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          20m
```

Создадим Headless Service : 

```console
$ kubectl apply -f minio-headless-service.yaml
service/minio created
```

### Задание со *

Манифест  берем отсюда https://kubernetes.io/docs/concepts/configuration/secret/  
Меняем MINIO_ACCESS_KEYи MINIO_SECRET_KEY :

```
$ echo -n 'minio123' | base64
bWluaW8xMjM=

$ echo -n 'minio' | base64
bWluaW8=
```


## Homework 4. Networks

### 4.1 Добавление проверок Pod

Домашнее задание делаем в minikube :

```console
$ minikube start --driver=virtualbox
```

Добавляем  readinessProbe в web-pod.yaml из предыдущего задания, запускаем pod - результат аналогичный показаному на слайдах.

Добавим другой вид проверок:

```YAML
    livenessProbe:
      httpGet:
        path: /index.html
        port: 8000
```

Запускаем pod :

```console
$ kubectl apply -f web-pod.yaml 
pod/web configured

$ kubectl describe pod web 
```

Как видим Conditions изменились на True : 

```
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
```

### 4.2 Создание Deployment

Создадим deployment приложения web и применим его  :

```console
$ kubectl apply -f web-deploy.yaml 
deployment.apps/web configured

$ kubectl describe deployment web 
```

Conditions в результате :  

```
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
```

Поробуем разные стратегии развертывания.  

- maxSurge 0 и maxUnavailable 0 :  

```console
<pre>The Deployment &quot;web&quot; is invalid: spec.strategy.rollingUpdate.maxUnavailable: Invalid value: intstr.IntOrString{Type:0, IntVal:0, StrVal:&quot;&quot;}: may not be 0 when `maxSurge` is 0</pre>
```

- maxSurge 100% и maxUnavailable 100%.  :

```console
ROLLOUT STATUS:
- [Current rollout | Revision 5] [MODIFIED]  default/web-56c5c7b8d6
    ✅ ReplicaSet is available [3 Pods available of a 3 minimum]
       - [Ready] web-56c5c7b8d6-szffw
       - [Ready] web-56c5c7b8d6-d22fs
       - [Ready] web-56c5c7b8d6-2kvcq
```

- maxSurge 0 и maxUnavailable 100% :  

```console

ROLLOUT STATUS:
- [Current rollout | Revision 8] [MODIFIED]  default/web-8c54b8857
    ⌛ Waiting for ReplicaSet to attain minimum available Pods (2 available of a 3 minimum)
       - [Ready] web-8c54b8857-kvbfw
       - [Ready] web-8c54b8857-9tmvr
       - [ContainersNotReady] web-8c54b8857-sr887 containers with unready status: [web]


ROLLOUT STATUS:
- [Current rollout | Revision 6] [MODIFIED]  default/web-8c54b8857
    ✅ ReplicaSet is available [3 Pods available of a 3 minimum]
       - [Ready] web-8c54b8857-dbfh6
       - [Ready] web-8c54b8857-5kwcz
       - [Ready] web-8c54b8857-wrtz6
```

### 4.3 Создание Service | ClusterIP

Создадим манифест web-svc-cip.yaml и применим его :

```console
$ kubectl apply -f web-svc-cip.yaml
service/web-svc-cip created

$ kubectl get svc
NAME          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes    ClusterIP   10.96.0.1     <none>        443/TCP   4m21s
web-svc-cip   ClusterIP   10.99.87.26   <none>        80/TCP    15s
```

Проверим результат. Сurl работает :

```
# curl http://10.99.87.26/index.html
<html>
```

Пинга нет:

```
--- 10.99.87.26 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
```

IP не видно :

```console
# arp -an | grep 10.99.87.26
# ip addr show | grep 10.99.87.26
#
```
Вот где кластерный IP :

```console
# iptables --list -nv -t nat | grep 10.99.87.26
    1    60 KUBE-SVC-WKCOG6KH24K26XRJ  tcp  --  *      *       0.0.0.0/0            10.99.87.26          /* default/web-svc-cip: cluster IP */ tcp dpt:80
```

Включим IPVS для kube-proxy чезез ConfigMap и удалим kube-proxy, чтобы DaemonSet поднял с новой конфигурацией :  

```console
$  kubectl --namespace kube-system edit configmap/kube-proxy
configmap/kube-proxy edited

$ kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'
pod "kube-proxy-c4t9s" deleted
```

Удаляем лишние iptables правила на VM, устанавливаем ipvsadm через toolbox контейнер. 
Теперь видно и наш сервис :

```console
[root@minikube ~]# ipvsadm --list -n
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.99.87.26:80 rr
  -> 172.17.0.4:8000              Masq    1      0          0         
  -> 172.17.0.5:8000              Masq    1      0          0         
  -> 172.17.0.6:8000              Masq    1      0          0  
```
Кластерный IP успешно пингуется :

```
--- 10.99.87.26 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
```

Кластерный IP теперь есть на интерфейсе kube-ipvs0 :

```console
# ip addr show kube-ipvs0
16: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default 
    link/ether 5a:b2:69:ac:b2:31 brd ff:ff:ff:ff:ff:ff
    inet 10.99.87.26/32 brd 10.99.87.26 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
```

### 4.3 Установка MetalLB

Устанавливаем MetalLB, пишем манифест metallb-config.yaml и манифест web-svc-lb.yaml для LoadBalancer сервиса.  

Проверка конфигурации:

```console
$ kubectl --namespace metallb-system logs pod/controller-57f648cb96-7g696
{"caller":"service.go:114","event":"ipAllocated","ip":"172.17.255.1","msg":"IP address assigned by controller","service":"default/web-svc-lb","ts":"2020-05-27T12:05:28.83633644Z"}

$ kubectl describe svc web-svc-lb
Name:                     web-svc-lb
Namespace:                default
Labels:                   <none>
Annotations:              Selector:  app=web
Type:                     LoadBalancer
IP:                       10.106.15.11
LoadBalancer Ingress:     172.17.255.1
Port:                     <unset>  80/TCP
TargetPort:               8000/TCP
NodePort:                 <unset>  31887/TCP
Endpoints:                172.17.0.4:8000,172.17.0.5:8000,172.17.0.6:8000
Session Affinity:         None
External Traffic Policy:  Cluster
```

Сеть кластера изолирована от нашей основной ОС. Мы не сможем открыть http://172.17.255.1/index.html  
Выполним minikube ssh чтобы узнать IP-адрес виртуалки

```console
$ ip addr show eth1
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:fc:f9:81 brd ff:ff:ff:ff:ff:ff
    inet 192.168.99.100/24 brd 192.168.99.255 scope global dynamic eth1
       valid_lft 740sec preferred_lft 740sec
```

Проверим IP с помощью minikube на всякий случай: 

```console
$ minikube ip
192.168.99.100
```

Добавляем статический маршрут :

```console
$ sudo ip route add 172.17.255.0/24 via  192.168.99.100
```

Страница http://172.17.255.1/index.html работает  

```
$ curl http://172.17.255.1/index.html 
<html>
<head/>
<body>
<!-- IMAGE BEGINS HERE -->
```


### 4.4 Создание Ingress

Устанавливем основной манифест для ingress-nginx, потом пишем манифест nginx-lb.yaml.  
Применим созданный манифест и посмотрим на IP-адрес :

```cosole
$ kubectl describe svc ingress-nginx -n ingress-nginx
Name:                     ingress-nginx
Namespace:                ingress-nginx
Labels:                   app.kubernetes.io/name=ingress-nginx
                          app.kubernetes.io/part-of=ingress-nginx
Annotations:              Selector:  app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx
Type:                     LoadBalancer
IP:                       10.111.189.45
LoadBalancer Ingress:     172.17.255.2
Port:                     http  80/TCP
```

curl отдает 404 от nginx:

```
$ curl http://172.17.255.2/index.html
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.17.10</center>
```

Напишем манифест web-svc-headless.yaml с параметром clusterIP: None  
Проверим что IP действительно не назаначен:

```console
$ kubectl apply -f web-svc-headless.yaml
service/web-svc created

$ kubectl describe svc web-svc
Name:              web-svc
Namespace:         default
Labels:            <none>
Annotations:       Selector:  app=web
Type:              ClusterIP
IP:                None
```

Напишем манифест для ingress-прокси web-ingress.yaml и проверим коректно ли заполнены Address и Backends:  

```console
$ kubectl describe ingress/web
Name:             web
Namespace:        default
Address:          192.168.99.100
Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /web   web-svc:8000 (172.17.0.4:8000,172.17.0.5:8000,172.17.0.6:8000)
Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /
Events:
  Type    Reason  Age   From                      Message
  ----    ------  ----  ----                      -------
  Normal  CREATE  22s   nginx-ingress-controller  Ingress default/web
  Normal  UPDATE  4s    nginx-ingress-controller  Ingress default/web
```

Можно проверить что страничка доступна :

```console
$ curl http://172.17.255.2/web/index.html 
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0<html>
<head/>
<body>
<!-- IMAGE BEGINS HERE -->
```

### 4.5 Задание со ⭐ | DNS через MetalLB

Пишем манифест corendns-lb.yaml. Добавим анотации чтобы coredns запрашивал IP из определеного нами пула :

```YAML
  annotations:
    metallb.universe.tf/allow-shared-ip: coredns
```

Находим нужные pods и смотрим их Labels: 

```console
$ kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-66bff467f8-4488n           1/1     Running   0          3h18m
coredns-66bff467f8-b8ms9           1/1     Running   0          3h18m


$ kubectl describe pod coredns-66bff467f8-4488n -n kube-system | grep Labels
Labels:               k8s-app=kube-dns
```

Добавим selector в манифест : 

```YAML
  selector:
    k8s-app: kube-dns
```

Также укажем необходимый TCP порт. Манифест corendns-lb-udp.yaml будет такой же, просто изменим название и протокол на UDP.
Применим оба манифеста и затестим через nslookup:  

```console
$ nslookup web-svc-cip.default.svc.cluster.local 172.17.255.10
Server:		172.17.255.10
Address:	172.17.255.10#53

Name:	web-svc-cip.default.svc.cluster.local
Address: 10.110.237.26


$ kubectl get svc -n kube-system
NAME             TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                  AGE
coredns-lb       LoadBalancer   10.99.11.3      172.17.255.10   53:32215/TCP             3h43m
coredns-lb-udp   LoadBalancer   10.108.47.120   172.17.255.10   53:32537/UDP             3h42m
``` 

## Homework 3. Security. 

### 3.1 task01

Создадим Service Accounts bob и dave.

```console
$ kubectl get sa
NAME      SECRETS   AGE
bob       1         116s
dave      1         7s
default   1         3m44s
```

Для аккаунта bob напишем RoleBinding c админ правами: 

```console
$ kubectl get clusterrolebinding bob
NAME   ROLE                AGE
bob    ClusterRole/admin   21m
```

### 3.2 task02

Cоздадим namespace, Serive Account, ClusterRole, ClusterRoleBinding

```console
$ kubectl get ns
NAME              STATUS   AGE
default           Active   17m
kube-node-lease   Active   17m
kube-public       Active   17m
kube-system       Active   17m
prometheus        Active   31s

$ kubectl get sa -n prometheus
NAME      SECRETS   AGE
carol     1         75s
default   1         81s

$ kubectl get clusterrolebinding.rbac.authorization.k8s.io prometheus 
NAME         ROLE                     AGE
prometheus   ClusterRole/prometheus   8m35s

```

### 3.3 task03

Создадим namespace dev, Service Acccounts jane и ken. Jane admin, а ken нет.

```console
$ kubectl get ns
NAME              STATUS   AGE
default           Active   39m
dev               Active   81s

$ kubectl get sa -n dev
NAME      SECRETS   AGE
default   1         2m13s
jane      1         77s
ken       1         63s

$ kubectl get rolebinding -n dev
NAME   ROLE                AGE
jane   ClusterRole/admin   2m27s
ken    ClusterRole/view    86s

```

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
