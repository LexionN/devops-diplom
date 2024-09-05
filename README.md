
# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:


### Создание облачной инфраструктуры

Для начала необходимо подготовить облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
Для облачного k8s используйте региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизируйте ресурсы ВМ и долю ЦПУ. В обоих вариантах используйте прерываемые ВМ для worker nodes.

Предварительная подготовка к установке и запуску Kubernetes кластера.

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя
2. Подготовьте [backend](https://www.terraform.io/docs/language/settings/backends/index.html) для Terraform:  
   а. Рекомендуемый вариант: S3 bucket в созданном ЯО аккаунте(создание бакета через TF)
   б. Альтернативный вариант:  [Terraform Cloud](https://app.terraform.io/)  
3. Создайте VPC с подсетями в разных зонах доступности.
4. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.
5. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://www.terraform.io/docs/language/settings/backends/index.html) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.

Ожидаемые результаты:

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий.
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

### Выполнение:

1. Создадим сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Для упрощения напишем скрипт:

```
#!/bin/sh

# Подготавливаем SA
yc iam service-account delete sa-robot
yc iam service-account create --name sa-robot
ID_SA=`yc iam service-account list | grep 'sa-robot' | awk '{print $2}'`
yc resource-manager folder add-access-binding --id b1gnc2bkas267cooida6 --role editor --service-account-id $ID_SA
yc resource-manager folder add-access-binding --id b1gnc2bkas267cooida6 --role storage.admin --service-account-id $ID_SA
yc iam access-key create --service-account-id $ID_SA --format json > ~/.ssh/sa-key.json
yc iam key create --service-account-id $ID_SA --format json --output ~/.ssh/sa-iam.json

# Извлекаем access_key и secret_key
ACCESS_KEY_ID=$(grep 'key_id' ~/.ssh/sa-key.json | awk '{print $2}' | tr -d \")
SECRET_ACCESS_KEY=$(grep 'secret' ~/.ssh/sa-key.json | awk '{print $2}' | tr -d \")

# Устанавливаем переменные окружения
export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
export TF_VAR_access_key=$ACCESS_KEY_ID
export TF_VAR_secret_key=$SECRET_ACCESS_KEY
```

2. Подготавливаем bucket:

```
resource "yandex_storage_bucket" "my_bucket" {
  access_key = var.access_key
  secret_key = var.secret_key
  bucket                = "aleksey-naumov"
  default_storage_class = "STANDARD"
  acl    = "private"
}
```

3. Размещаем backend для Terraform в заранее подготовленный bucket:

```
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    
    bucket = "aleksey-naumov"
    region = "ru-central1"
    key    = "terraform.tfstate"
   
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
    skip_metadata_api_check     = true

  }
}
```

4. Создадим VPC с подсетями в разных зонах доступности. Для этого используем локальные переменные:

```
locals {
    vpc_zone = tolist ([
      "ru-central1-a", 
      "ru-central1-b",
      "ru-central1-d"
    ])
}
```

Создаем ресурсы:

```
resource "yandex_vpc_network" "network_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "public_subnet" {
  count          = length(local.vpc_zone)
  name           = "public_${local.vpc_zone[count.index]}"
  zone           = local.vpc_zone[count.index]
  network_id     = yandex_vpc_network.network_vpc.id
  v4_cidr_blocks = [var.public_cidr[count.index]]
}
```

5. Убедимся, что теперь можно выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.

```
$ terraform apply

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

--------------------ВЫВОД ПРОПУЩЕН------------------------

Plan: 4 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

yandex_vpc_network.network_vpc: Creating...
yandex_vpc_network.network_vpc: Creation complete after 3s [id=enp2fc69ab7gtjmfq7mb]
yandex_vpc_subnet.public_subnet[2]: Creating...
yandex_vpc_subnet.public_subnet[1]: Creating...
yandex_vpc_subnet.public_subnet[0]: Creating...
yandex_vpc_subnet.public_subnet[1]: Creation complete after 0s [id=e2ljegbh6m99n850vsqq]
yandex_vpc_subnet.public_subnet[0]: Creation complete after 1s [id=e9b742nucqphhs5f5lqi]
yandex_vpc_subnet.public_subnet[2]: Creation complete after 1s [id=fl8ab1frul3bcgeeu002]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

```
$ terraform destroy
yandex_vpc_network.network_vpc: Refreshing state... [id=enpur45aeas52aba40k6]
yandex_vpc_subnet.public_subnet[2]: Refreshing state... [id=fl85k23rgc7afserkdus]
yandex_vpc_subnet.public_subnet[1]: Refreshing state... [id=e2lljtr90obi885n25e3]
yandex_vpc_subnet.public_subnet[0]: Refreshing state... [id=e9b87s9g3k6cetf06p6e]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

--------------------ВЫВОД ПРОПУЩЕН------------------------

Plan: 0 to add, 0 to change, 4 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

yandex_vpc_subnet.public_subnet[1]: Destroying... [id=e2lljtr90obi885n25e3]
yandex_vpc_subnet.public_subnet[2]: Destroying... [id=fl85k23rgc7afserkdus]
yandex_vpc_subnet.public_subnet[0]: Destroying... [id=e9b87s9g3k6cetf06p6e]
yandex_vpc_subnet.public_subnet[0]: Destruction complete after 1s
yandex_vpc_subnet.public_subnet[2]: Destruction complete after 2s
yandex_vpc_subnet.public_subnet[1]: Destruction complete after 3s
yandex_vpc_network.network_vpc: Destroying... [id=enpur45aeas52aba40k6]
yandex_vpc_network.network_vpc: Destruction complete after 0s

Destroy complete! Resources: 4 destroyed.
```

Подтвердим скриншотами созданные ресурсы:

![image](https://github.com/user-attachments/assets/d354fc16-fb01-43af-81a0-e7d15f1a6915)

![image](https://github.com/user-attachments/assets/eabe13fe-9998-4dea-b837-72f89b5a56a2)



---
### Создание Kubernetes кластера

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры.   Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

1. Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.  
   а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.  
   б. Подготовить [ansible](https://www.ansible.com/) конфигурации, можно воспользоваться, например [Kubespray](https://kubernetes.io/docs/setup/production-environment/tools/kubespray/)  
   в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
2. Альтернативный вариант: воспользуйтесь сервисом [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)  
  а. С помощью terraform resource для [kubernetes](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster) создать **региональный** мастер kubernetes с размещением нод в разных 3 подсетях      
  б. С помощью terraform resource для [kubernetes node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group)
  
Ожидаемый результат:

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

---
### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

2. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ к тестовому приложению.

---
### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)
