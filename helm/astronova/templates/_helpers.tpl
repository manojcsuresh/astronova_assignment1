{{- define "astronova.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "astronova.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: astronova
{{- end }}

{{- define "astronova.backend.labels" -}}
{{ include "astronova.labels" . }}
app.kubernetes.io/name: astronova-backend
app.kubernetes.io/component: backend
{{- end }}

{{- define "astronova.frontend.labels" -}}
{{ include "astronova.labels" . }}
app.kubernetes.io/name: astronova-frontend
app.kubernetes.io/component: frontend
{{- end }}

{{- define "astronova.backend.selectorLabels" -}}
app.kubernetes.io/name: astronova-backend
app.kubernetes.io/component: backend
{{- end }}

{{- define "astronova.frontend.selectorLabels" -}}
app.kubernetes.io/name: astronova-frontend
app.kubernetes.io/component: frontend
{{- end }}
