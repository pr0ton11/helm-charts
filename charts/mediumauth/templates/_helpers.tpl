{{/* Return names and labels used by this chart. */}}
{{- define "mediumauth.fullname" -}}
{{ include "bjw-s.common.lib.chart.names.fullname" . }}
{{- end -}}

{{- define "mediumauth.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "mediumauth.serviceName" -}}
{{ include "bjw-s.common.lib.chart.names.fullname" . }}
{{- end -}}

{{- define "mediumauth.discoveryRoleName" -}}
{{- printf "%s-%s-ingress-discovery" (include "mediumauth.fullname" .) .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mediumauth.configEncryptionSecretName" -}}
{{- if .Values.configEncryptionKey.existingSecret -}}
{{- .Values.configEncryptionKey.existingSecret -}}
{{- else -}}
{{- printf "%s-config-encryption" (include "mediumauth.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mediumauth.configEncryptionSecretKey" -}}
{{- .Values.configEncryptionKey.existingSecretKey | default "TINYAUTH_CONFIG_ENCRYPTION_KEY" -}}
{{- end -}}
