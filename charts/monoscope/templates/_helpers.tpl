{{- define "monoscope.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "monoscope.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 48 | trimSuffix "-" -}}
{{- else if contains (include "monoscope.name" .) .Release.Name -}}
{{- .Release.Name | trunc 48 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "monoscope.name" .) | trunc 48 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- define "monoscope.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monoscope.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "monoscope.labels" -}}
{{ include "monoscope.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
{{- define "monoscope.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}
