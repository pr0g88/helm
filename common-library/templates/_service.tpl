{{/*
common.service — Service (ClusterIP/...) для сервиса.
Ожидает: service.{type,port,targetPort}. Порт всегда называется "http"
(так на него ссылаются probes и Ingress).
*/}}
{{- define "common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
    name: http
{{- end }}
