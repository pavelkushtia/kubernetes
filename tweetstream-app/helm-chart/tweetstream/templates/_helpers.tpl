{{/*
Expand the name of the chart.
*/}}
{{- define "tweetstream.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tweetstream.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tweetstream.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tweetstream.labels" -}}
helm.sh/chart: {{ include "tweetstream.chart" . }}
{{ include "tweetstream.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: tweetstream
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tweetstream.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tweetstream.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tweetstream.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tweetstream.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database connection string
*/}}
{{- define "tweetstream.databaseUrl" -}}
{{- if .Values.database.enabled -}}
postgresql://{{ .Values.database.auth.username }}:{{ .Values.database.auth.password }}@{{ .Values.database.name }}:{{ .Values.database.service.port }}/{{ .Values.database.auth.database }}
{{- else -}}
{{- .Values.externalDatabase.url }}
{{- end -}}
{{- end }}

{{/*
Redis connection string
*/}}
{{- define "tweetstream.redisUrl" -}}
{{- if .Values.redis.enabled -}}
redis://{{ .Values.redis.name }}:{{ .Values.redis.service.port }}
{{- else -}}
{{- .Values.externalRedis.url }}
{{- end -}}
{{- end }}

{{/*
Kafka connection string
*/}}
{{- define "tweetstream.kafkaUrl" -}}
{{- if .Values.kafka.enabled -}}
{{ include "tweetstream.fullname" . }}-kafka:{{ .Values.kafka.service.port }}
{{- else -}}
{{- .Values.externalKafka.url }}
{{- end -}}
{{- end }}

{{/*
API image
*/}}
{{- define "tweetstream.apiImage" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/%s:%s" .Values.global.imageRegistry .Values.api.image.repository .Values.api.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.api.image.repository .Values.api.image.tag }}
{{- end }}
{{- end }}

{{/*
Frontend image
*/}}
{{- define "tweetstream.frontendImage" -}}
{{- if .Values.global.imageRegistry }}
{{- printf "%s/%s:%s" .Values.global.imageRegistry .Values.frontend.image.repository .Values.frontend.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.frontend.image.repository .Values.frontend.image.tag }}
{{- end }}
{{- end }}

{{/*
Common environment variables for API
*/}}
{{- define "tweetstream.apiEnv" -}}
- name: NODE_ENV
  value: {{ .Values.api.env.NODE_ENV | quote }}
- name: PORT
  value: {{ .Values.api.env.PORT | quote }}
- name: DATABASE_URL
  value: {{ include "tweetstream.databaseUrl" . | quote }}
- name: REDIS_URL
  value: {{ include "tweetstream.redisUrl" . | quote }}
- name: KAFKA_BROKERS
  value: {{ include "tweetstream.kafkaUrl" . | quote }}
- name: JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "tweetstream.fullname" . }}-secrets
      key: jwt-secret
- name: FRONTEND_URL
  value: "http://{{ (index .Values.ingress.hosts 0).host }}"
{{- end }}

{{/*
Namespace
*/}}
{{- define "tweetstream.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride }}
{{- end }} 