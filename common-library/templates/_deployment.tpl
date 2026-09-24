{{/*
common.deployment — Deployment для любого сервиса PizzaShop (backend или frontend).
Единый шаблон вместо 11 копий deployment.yaml. Вызывается одной строкой:
  {{ include "common.deployment" . }}

Ожидает в values.yaml вызывающего чарта:
  replicaCount, image.{registry,repository,tag,pullPolicy}
  imagePullSecrets              (список, опционально)
  serviceAccount.name
  service.port
  resources.{requests,limits}
  probes.{liveness,readiness}.{path,port,initialDelaySeconds,periodSeconds,timeoutSeconds,failureThreshold}
  command / args / extraEnv     (списки, опционально — нужны только api-gateway,
                                  вариант "Vault -> env-file" через кастомный entrypoint)
  vault.enabled, vault.role, vault.secretPath
  vault.secrets                 (список {name, keys[]}, см. ниже)
  configMap.*                   (сам ConfigMap собирает common.configmap;
                                  сюда попадает только через envFrom по имени)

--- vault.secrets ---
Каждый элемент списка = один файл, который Vault Agent Injector положит в
/vault/secrets/<name> пода, с полями <keys>, прочитанными из vault.secretPath:
  vault:
    secrets:
      - name: db
        keys: [DB_URL, DB_USERNAME, DB_PASSWORD]

Это рендерится в аннотацию agent-inject-template-<name> с телом — шаблоном
САМОГО Vault Agent (его собственный Go-template), а не Helm. Поэтому текст
"{{- with secret ... -}}" / "{{ .Data.data.KEY }}" собирается через
printf "{{- with secret %q -}}" ... и printf "{{ .Data.data.%s }}" . ,
а не пишется как `{{ .Data.data.KEY }}` напрямую в YAML. Прямая запись
ломает парсинг файла самим Helm (text/template не различает "это моя
разметка" от "это чужой текст, просто похожий на неё" — он видит {{ }}
везде в файле). printf здесь — единственный надёжный способ вывести текст
"{{ ... }}", не дав Helm попытаться исполнить его как свой template action.
*/}}
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
      {{- if .Values.vault.enabled }}
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: {{ .Values.vault.role | quote }}
        {{- range .Values.vault.secrets }}
        vault.hashicorp.com/agent-inject-secret-{{ .name }}: {{ $.Values.vault.secretPath | quote }}
        vault.hashicorp.com/agent-inject-template-{{ .name }}: |
          {{ printf "{{- with secret %q -}}" $.Values.vault.secretPath }}
          {{- range .keys }}
          {{ printf "{{ .Data.data.%s }}" . }}
          {{- end }}
          {{ "{{- end }}" }}
        {{- end }}
      {{- end }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      terminationGracePeriodSeconds: 30
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        {{- with .Values.command }}
        command:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.args }}
        args:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        ports:
        - name: http
          containerPort: {{ .Values.service.port }}
        envFrom:
        - configMapRef:
            name: {{ include "common.fullname" . }}-config
        {{- with .Values.extraEnv }}
        env:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: {{ .Values.probes.liveness.path }}
            port: {{ .Values.probes.liveness.port }}
          initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
          periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
          timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds }}
          failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
        readinessProbe:
          httpGet:
            path: {{ .Values.probes.readiness.path }}
            port: {{ .Values.probes.readiness.port }}
          initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
          periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
          timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
          failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      restartPolicy: Always
{{- end }}
