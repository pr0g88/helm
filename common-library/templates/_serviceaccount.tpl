{{/*
common.serviceaccount — ServiceAccount пода.
Ожидает: serviceAccount.name — используется и здесь, и в
Deployment.spec.serviceAccountName; шаблон их совпадение не проверяет,
следите за этим в values.yaml сами.
*/}}
{{- define "common.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
{{- end }}
