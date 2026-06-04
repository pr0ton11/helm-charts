{{/*
Return the full name used by this chart and the bjw-s common defaults.
*/}}
{{- define "paperless-ngx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "paperless-ngx.redis.name" -}}
{{ include "paperless-ngx.fullname" . }}-redis
{{- end -}}

{{- define "paperless-ngx.serviceName" -}}
{{ include "bjw-s.common.lib.chart.names.fullname" . }}
{{- end -}}

{{- define "paperless-ngx.redis.serviceName" -}}
{{ include "paperless-ngx.redis.name" . }}-master
{{- end -}}

{{- define "paperless-ngx.redis.secretName" -}}
{{- .Values.redis.auth.existingSecret | default (include "paperless-ngx.redis.name" .) -}}
{{- end -}}

{{- define "paperless-ngx.redis.password" -}}
{{- if .Values.redis.auth.password -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- $secretName := include "paperless-ngx.redis.secretName" . -}}
{{- $secretKey := .Values.redis.auth.existingSecretPasswordKey | default "redis-password" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $secret (index $secret.data $secretKey) -}}
{{- index $secret.data $secretKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}
