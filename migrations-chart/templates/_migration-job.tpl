{{/*
migrations-chart.migration-job — общий Job для миграций БД (dbmate), для up и down.
Вызывается из migration-up-job.yaml / migration-down-job.yaml с контекстом:
  (dict "type" "up"|"down" "root" .)
где root — корневой контекст чарта-потребителя (order-service и т.п.), т.к. этот чарт
подключается как dependency с alias: migrations.

Хуки: pre-install,pre-upgrade (up) / pre-rollback (down), hook-weight "5" — Job
выполняется до основного деплоя. hook-delete-policy удаляет старый Job перед новым
запуском и после успеха.

MIGRATION_DOWN_ENABLED (ConfigMap migration-config) — фича-флаг, по умолчанию false:
down не выполняется, даже если pre-rollback хук запущен (защита от случайного отката).

Секрет БД получаем через Vault Agent (файл /vault/secrets/db), поэтому в начале
команды — цикл ожидания появления файла.
*/}}
{{- define "migrations-chart.migration-job" -}}
{{- $migrationType := .type }}
{{- $root := .root }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "migrations-chart.fullname" $root }}-{{ $migrationType }}
  labels:
    {{- include "migrations-chart.labels" $root | nindent 4 }}
  annotations:
    {{- if eq $migrationType "up" }}
    "helm.sh/hook": pre-install,pre-upgrade
    {{- else if eq $migrationType "down" }}
    "helm.sh/hook": pre-rollback
    {{- end }}
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: {{ $root.Values.backoffLimit | default 5 }}
  template:
    metadata:
      labels:
        {{- include "migrations-chart.selectorLabels" $root | nindent 8 }}
      {{- if $root.Values.vault.enabled }}
      annotations:
        vault.hashicorp.com/agent-inject: 'true'
        vault.hashicorp.com/agent-inject-status: update
        vault.hashicorp.com/agent-pre-populate-only: "true"
        vault.hashicorp.com/role: {{ $root.Values.vault.role | quote }}
        vault.hashicorp.com/agent-inject-secret-db: {{ $root.Values.vault.secretPath | quote }}
        vault.hashicorp.com/agent-inject-template-db: |
          {{`{{- with secret "`}}{{ $root.Values.vault.secretPath }}{{`" -}}
          {{ .Data.data.POSTGRES_USER }}
          {{ .Data.data.POSTGRES_PASSWORD }}
          {{- end }}`}}
      {{- end }}
    spec:
      serviceAccountName: {{ $root.Values.serviceAccount.name }}
      restartPolicy: Never
      imagePullSecrets:
      - name: zot-registry-secret
      containers:
      - name: migrate
        # ИЗМЕНЕНО: убрано .migrations
        image: "{{ $root.Values.image.registry }}/{{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}"
        imagePullPolicy: {{ $root.Values.image.pullPolicy | default "IfNotPresent" }}
        command: ["/bin/sh", "-c"]
        args:
          - |
            MIGRATION_TYPE="{{ $migrationType }}"
            echo "Migration type: ${MIGRATION_TYPE}"
            
            if [ "$MIGRATION_TYPE" = "down" ] && [ "${MIGRATION_DOWN_ENABLED}" != "true" ]; then
              echo "⏭️ Migration down skipped (MIGRATION_DOWN_ENABLED=${MIGRATION_DOWN_ENABLED})"
              exit 0
            fi
            
            while [ ! -f /vault/secrets/db ]; do
              echo "Waiting for Vault secrets..."
              sleep 1
            done
            
            if [ -f /vault/secrets/db ]; then
              DB_USER=$(sed -n '1p' /vault/secrets/db | tr -d '\n')
              DB_PASSWORD=$(sed -n '2p' /vault/secrets/db | tr -d '\n')
            else
              echo "ERROR: Vault secrets not found"
              exit 1
            fi
            
            DB_HOST="${DB_HOST:-postgres}"
            DB_PORT="${DB_PORT:-5432}"
            
            ENCODED_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${DB_PASSWORD}'))" 2>/dev/null || echo "${DB_PASSWORD}")
            
            export DATABASE_URL="postgres://${DB_USER}:${ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT}/{{ $root.Values.databaseName }}?sslmode=disable"
            echo "Database: {{ $root.Values.databaseName }}"
            
            if [ "$MIGRATION_TYPE" = "up" ]; then
              echo "Starting migrations UP..."
              dbmate up
            elif [ "$MIGRATION_TYPE" = "down" ]; then
              echo "Starting migrations DOWN..."
              dbmate down
            fi
            
            if [ $? -eq 0 ]; then
              echo "✅ Migrations ${MIGRATION_TYPE} completed"
              dbmate status
            else
              echo "❌ Migrations ${MIGRATION_TYPE} failed"
              exit 1
            fi
            
            exit 0
        env:
        - name: DB_HOST
          value: {{ $root.Values.dbHost | default "postgres" | quote }}
        - name: DB_PORT
          value: {{ $root.Values.dbPort | default "5432" | quote }}
        - name: MIGRATION_DOWN_ENABLED
          valueFrom:
            configMapKeyRef:
              name: migration-config
              key: MIGRATION_DOWN_ENABLED
              optional: true
        resources:
          # ИЗМЕНЕНО: убрано .migrations
          {{- toYaml $root.Values.resources | nindent 10 }}
{{- end }}