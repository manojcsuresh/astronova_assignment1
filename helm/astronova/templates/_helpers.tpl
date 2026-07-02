{{/*
AstroNova Helm Helpers
*/}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "astronova.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "astronova.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: astronova
{{- end }}

{{/*
Backend labels
*/}}
{{- define "astronova.backend.labels" -}}
{{ include "astronova.labels" . }}
app.kubernetes.io/name: astronova-backend
app.kubernetes.io/component: backend
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "astronova.frontend.labels" -}}
{{ include "astronova.labels" . }}
app.kubernetes.io/name: astronova-frontend
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Backend selector labels
*/}}
{{- define "astronova.backend.selectorLabels" -}}
app.kubernetes.io/name: astronova-backend
app.kubernetes.io/component: backend
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "astronova.frontend.selectorLabels" -}}
app.kubernetes.io/name: astronova-frontend
app.kubernetes.io/component: frontend
{{- end }}
