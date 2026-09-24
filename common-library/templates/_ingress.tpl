{{/*
common.ingress — Ingress (networking.k8s.io/v1). Рендерится, только если
ingress.enabled: true.

Имя ресурса по умолчанию = common.fullname (как у Service/Deployment), но
можно переопределить через ingress.name — нужно, когда Ingress называется
иначе, чем релиз/сервис. Пример: у api-gateway сам сервис называется
api-gateway, а Ingress — api-gateway-swagger (чтобы иметь отдельный host
под Swagger/OpenAPI, не занимая основное имя).
*/}}
{{- define "common.ingress" -}}
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.ingress.name | default (include "common.fullname" .) }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: {{ .Values.ingress.path | default "/" }}
            pathType: {{ .Values.ingress.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
{{- end }}
