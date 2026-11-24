{{- define "blocky.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "blocky.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "blocky.labels" -}}
{{ include "blocky.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "blocky.suffixedName" -}}
{{- printf "%s-%s" (include "blocky.fullname" .root | trunc (sub 62 (len .suffix) | int) | trimSuffix "-") .suffix -}}
{{- end -}}

{{- define "blocky.config" -}}
{{- $log := omit .Values.queryLog "databaseSecret" "sqlite" -}}
{{- if eq $log.type "sqlite" -}}
{{- $_ := set $log "target" "/logs/querylog.db" -}}
{{- else if has $log.type (list "postgresql" "timescale") -}}
{{- $_ := set $log "target" "file:/etc/blocky/database/dsn" -}}
{{- end -}}
ports:
  dns: ":1053"
  http: ":4000"
  {{- if .Values.nativeDoH.enabled }}
  https: ":443"
  {{- end }}
{{- if .Values.nativeDoH.enabled }}
certFile: /etc/blocky/tls/tls.crt
keyFile: /etc/blocky/tls/tls.key
http3:
  enable: {{ .Values.nativeDoH.http3 }}
{{- end }}
upstreams:
  {{- toYaml .Values.upstreams | nindent 2 }}
dnssec:
  {{- toYaml .Values.dnssec | nindent 2 }}
blocking:
  {{- toYaml .Values.blocking | nindent 2 }}
caching:
  {{- toYaml .Values.caching | nindent 2 }}
queryLog:
  {{- toYaml $log | nindent 2 }}
{{- end -}}
