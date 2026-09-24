{{/*
common.configmap — ConfigMap с переменными окружения сервиса.
Рендерит все пары ключ/значение из .Values.configMap как строки (через quote).
Секреты сюда не класть — для них vault.secrets в common.deployment.
*/}}
{{- define "common.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . }}-config
  labels:
    {{- include "common.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
