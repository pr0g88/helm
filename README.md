# Helm Charts for Cluster Application

## Структура

Общая логика Deployment/Service/ServiceAccount/ConfigMap/HPA и хелперы именования (`fullname`, `labels`, `selectorLabels`) вынесены в library chart **`common-library`** (`type: library`). Каждый чарт сервиса подключает его как зависимость в своём `Chart.yaml` и вызывает через `{{ include "common.deployment" . }}` и т.д. — собственные шаблоны сервисов содержат только эти однострочные вызовы, вся специфика (порты, ресурсы, vault-секреты, конфиг) задаётся через `values.yaml`.

Перед `helm lint` / `helm template` / `helm install` для чарта сервиса **обязательно** нужно подтянуть зависимости (включая `common-library` и, где применимо, `migrations-chart`):

```bash
helm dependency update ./catalog-service
```

(в CI это уже делает `templates/common/.helm-deploy-template.gitlab-ci.yml` перед каждым деплоем — вручную нужно только при локальной проверке).

`image.registry` и `image.tag` (и `migrations.image.*` для чартов с миграциями)
в `values.yaml` намеренно пустые — реестр и тег образа подставляет CI через
`--set`/`--state-values-set` из CI/CD-переменных группы. Для команд ниже
(вне CI) их нужно передать самому, например:

```bash
--set image.registry=<registry host:port> --set image.tag=<tag>
```

## Установка

### Dev:
```bash
helm dependency update ./catalog-service
helm upgrade --install catalog-service ./catalog-service -f catalog-service/values-dev.yaml --namespace pizzashop-dev --create-namespace
```
### Staging:

```bash
helm dependency update ./catalog-service
helm upgrade --install catalog-service ./catalog-service -f catalog-service/values-staging.yaml --namespace pizzashop-staging --create-namespace
```
### Production:

```bash
helm dependency update ./catalog-service
helm upgrade --install catalog-service ./catalog-service -f catalog-service/values-prod.yaml --namespace pizzashop-prom --create-namespace
```
### Проверка

```bash
helm dependency update ./catalog-service
helm lint ./catalog-service
helm template ./catalog-service
```

## Секреты Vault

Список секретов, которые Vault Agent Injector должен инжектировать в под, задаётся в `values.yaml` каждого сервиса под `vault.secrets` — список `{name, keys}`, где `keys` — поля, которые нужно прочитать из `vault.secretPath` и записать в файл `/vault/secrets/<name>`:

```yaml
vault:
  enabled: true
  role: "pizzashop-dev"
  secretPath: "kv/pizzashop/dev/order"
  secrets:
    - name: db
      keys: [DB_URL, DB_USERNAME, DB_PASSWORD]
    - name: rabbitmq
      keys: [RABBITMQ_USERNAME, RABBITMQ_PASSWORD]
    - name: jwt
      keys: [JWT_SECRET]
```

Чарты без своей БД/очереди (например `frontend`) явно указывают `vault: { enabled: false }`.
