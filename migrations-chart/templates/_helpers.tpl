{{/*
Имена и лейблы для Job-ов миграций. Аналог common-library/_helpers.tpl, но не через
library chart — миграции подключаются условно (condition: migrations.enabled) и
исторически не заведены в common-library.
*/}}
{{- define "migrations-chart.name" -}}
{{- printf "%s-migrations" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "migrations-chart.fullname" -}}
{{- printf "%s-migrations" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "migrations-chart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "migrations-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end }}

{{- define "migrations-chart.selectorLabels" -}}
app: {{ include "migrations-chart.name" . }}
{{- end }}