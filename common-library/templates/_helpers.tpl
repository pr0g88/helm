{{/*
Общие хелперы именования и лейблов для всех чартов сервисов PizzaShop.

common.name / common.fullname / common.labels / common.selectorLabels —
единственный источник правды для того, как называется каждый k8s-ресурс
(Deployment/Service/ConfigMap/...) и как он лейблится. Раньше у каждого из
11 чартов была своя копия этого файла с именем чарта, зашитым прямо в имя
define (order-service.fullname, catalog-service.fullname, ...). Теперь имя
берётся динамически из .Chart.Name того контекста, с которым хелпер
include-ится — поэтому имена ресурсов не изменились при переходе на
common-library (уже задеплоенные Release/Deployment/Service не переименовались).

Использование из чарта-потребителя:
  {{ include "common.fullname" . }}
  {{- include "common.labels" . | nindent 4 }}
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "common.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "common.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "common.selectorLabels" -}}
app: {{ include "common.name" . }}
{{- end }}
