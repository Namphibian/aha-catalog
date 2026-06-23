{{- define "app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.labels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}


{{- /*
kebabCase: convert CamelCase or camelCase to kebab-case and lowercase
Usage: {{ include "app.kebab" "dataVolume" }}
*/ -}}
{{- define "app.kebab" -}}
{{ $s := . }}
{{- /* Insert dash before each capital letter */ -}}
{{ $withDashes := regexReplaceAll "([A-Z])" $s "-${1}" }}
{{- /* Remove any leading or trailing dashes */ -}}
{{ $trimmed := regexReplaceAll "^[-]+" $withDashes "" }}
{{ $trimmed = regexReplaceAll "[-]+$" $trimmed "" }}
{{ lower $trimmed }}
{{- end -}}

{{- /*
helpers: app.configValue
Parameters: list containing [ $cfg, $configData, $contextName ]
  - $cfg: the value to resolve (either a literal value or a map with configDataKey)
  - $configData: $.Values.app.configData
  - $contextName: string used in error messages
Returns: the resolved value from configData, or the literal value as-is.
*/ -}}
{{- define "app.configValue" -}}
  {{- $cfg := index . 0 -}}
  {{- $configData := index . 1 -}}
  {{- $contextName := index . 2 -}}
  {{- if kindIs "map" $cfg -}}
    {{- if hasKey $cfg "configDataKey" -}}
      {{- $cfgKey := index $cfg "configDataKey" -}}
      {{- if not (hasKey $configData $cfgKey) -}}
        {{- fail (printf "%s: configDataKey %q not found in .Values.app.configData" $contextName $cfgKey) -}}
      {{- end -}}
      {{- $entry := index $configData $cfgKey -}}
      {{- if not (hasKey $entry "value") -}}
        {{- fail (printf "%s: configData entry %q has no 'value' field" $contextName $cfgKey) -}}
      {{- end -}}
      {{- index $entry "value" -}}
    {{- else -}}
      {{- $cfg -}}
    {{- end -}}
  {{- else -}}
    {{- $cfg -}}
  {{- end -}}
{{- end -}}

{{- /*
helpers: app.configValueStr
Same as app.configValue but always returns a string representation.
For lists, returns JSON. For maps, returns JSON. For scalars, returns printf %v.
*/ -}}
{{- define "app.configValueStr" -}}
  {{- $raw := include "app.configValue" . -}}
  {{- $raw -}}
{{- end -}}

{{- /*
helpers: app.resolvePort
Parameters: list containing [ $portCfg, $configData, $contextName ]
  - $portCfg: the value of ports.<name>.port (either a number/string or a map with configDataKey)
  - $configData: $.Values.app.configData
  - $contextName: string used in error messages (e.g., "service api source")
Returns: numeric port value (rendered as text) or fails with a clear message.
*/ -}}
{{- /*
helpers: app.annotations
Parameters: list containing [ $annotationNames, $root ]
  - $annotationNames: list of annotation set names (from annotationSets)
  - $root: the root context ($)
Renders the merged annotations block (without the "annotations:" key).
*/ -}}
{{- define "app.annotations" -}}
{{- $annotationNames := index . 0 -}}
{{- $root := index . 1 -}}
{{- range $asetName := $annotationNames -}}
{{- $aset := index $root.Values.app.annotationSets $asetName -}}
{{- range $ak, $av := $aset }}
{{ $ak }}: {{ include "app.configValue" (list $av $root.Values.app.configData (printf "annotation %s.%s" $asetName $ak)) | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "app.resolvePort" -}}
  {{- $portCfg := index . 0 -}}
  {{- $configData := index . 1 -}}
  {{- $contextName := index . 2 -}}
  {{- if kindIs "map" $portCfg -}}
    {{- $cfgKey := index $portCfg "configDataKey" -}}
    {{- if not (hasKey $configData $cfgKey) -}}
      {{- fail (printf "%s: configDataKey %q not found in .Values.app.configData" $contextName $cfgKey) -}}
    {{- end -}}
    {{- $entry := index $configData $cfgKey -}}
    {{- if or (not (hasKey $entry "value")) (empty (index $entry "value")) -}}
      {{- fail (printf "%s: configData entry %q has no 'value' field or it is empty" $contextName $cfgKey) -}}
    {{- end -}}
    {{- /* Ensure numeric output */ -}}
    {{- printf "%d" (int (index $entry "value")) -}}
  {{- else -}}
    {{- /* literal port value */ -}}
    {{- printf "%v" $portCfg -}}
  {{- end -}}
{{- end -}}
