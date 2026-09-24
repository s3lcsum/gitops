{{- define "cilium-edge.tlsListener" -}}
tls-{{ replace "." "-" . }}
{{- end -}}
