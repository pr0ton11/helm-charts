{{/*
Return the full name used by this chart and the bjw-s common defaults.
*/}}
{{- define "grist.fullname" -}}
{{ include "bjw-s.common.lib.chart.names.fullname" . }}
{{- end -}}

{{- define "grist.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "grist.serviceName" -}}
{{ include "bjw-s.common.lib.chart.names.fullname" . }}
{{- end -}}

{{- define "grist.redis.name" -}}
{{ include "grist.fullname" . }}-redis
{{- end -}}

{{- define "grist.redis.serviceName" -}}
{{ include "grist.redis.name" . }}-master
{{- end -}}

{{- define "grist.redis.secretName" -}}
{{- .Values.redis.auth.existingSecret | default (include "grist.redis.name" .) -}}
{{- end -}}

{{- define "grist.redis.password" -}}
{{- if .Values.redis.auth.password -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- $secretName := include "grist.redis.secretName" . -}}
{{- $secretKey := .Values.redis.auth.existingSecretPasswordKey | default "redis-password" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $secret (index $secret.data $secretKey) -}}
{{- index $secret.data $secretKey | b64dec -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
{{- end -}}
