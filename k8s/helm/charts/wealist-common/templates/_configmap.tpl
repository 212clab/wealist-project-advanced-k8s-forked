{{/*
Standard configmap template for weAlist services
Usage in service chart:
  {{- include "wealist-common.configmap" . }}

Config merging priority (higher number = higher priority):
1. shared.config (from environment files - common for all services)
2. config (from service values.yaml - service-specific, overrides shared)

Note: Helm merge gives precedence to first arg, so we use mustMergeOverwrite
to ensure service-specific config overrides shared config.
*/}}
{{- define "wealist-common.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "wealist-common.fullname" . }}-config
  labels:
    {{- include "wealist-common.labels" . | nindent 4 }}
data:
  {{- /* First, add all shared config from environment files */}}
  {{- if .Values.shared }}
  {{- if .Values.shared.config }}
  {{- range $key, $value := .Values.shared.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- /* Then, add/override with service-specific config */}}
  {{- if .Values.config }}
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
  {{- /* Auto-generate DATABASE_URL for Go services if DB_NAME is set */}}
  {{- if .Values.config.DB_NAME }}
  {{- $dbHost := .Values.shared.config.DB_HOST | default "localhost" }}
  {{- $dbPort := .Values.shared.config.DB_PORT | default "5432" }}
  {{- $dbName := .Values.config.DB_NAME }}
  {{- $dbUser := .Values.config.DB_USER | default (regexReplaceAll "wealist_(.*)_db" $dbName "${1}") }}
  DATABASE_URL: {{ printf "postgresql://%s@%s:%s/%s?sslmode=disable" $dbUser $dbHost $dbPort $dbName | quote }}
  {{- end }}
{{- end }}
