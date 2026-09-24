{{/*
common.hpa — HorizontalPodAutoscaler (autoscaling/v2: CPU + память, с behavior
для scaleUp/scaleDown). Рендерится, только если hpa.enabled: true.

По умолчанию hpa.enabled: false почти у всех сервисов — ресурсов кластера
мало, включать автоскейлинг везде смысла нет. Сейчас включён только у
kitchen-service. У части сервисов minReplicas == maxReplicas — это не баг,
а способ иметь готовый (но неактивный) HPA-конфиг на будущее без лишних
ресурсов сейчас: включить масштабирование для другого сервиса — это правка
одной строки (hpa.enabled: true) в его values.yaml.
*/}}
{{- define "common.hpa" -}}
{{- if .Values.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" . }}-hpa
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.fullname" . }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.hpa.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.hpa.targetMemoryUtilizationPercentage }}
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 120
      - type: Pods
        value: 1
        periodSeconds: 120
      selectPolicy: Min
{{- end }}
{{- end }}
