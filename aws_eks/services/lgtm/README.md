# Grafana LGTM + OpenTelemetry (diagram services)

Matches **ARCHITECTURE.md §7** and `docs/architecture.svg`:

| Diagram label | Role |
|---------------|------|
| **OpenTelemetry** · Collector · OTLP | Telemetry collection (Obs. Infra) |
| **Grafana LGTM** · Loki · Tempo · Mimir | Observability backend |

## Not in architecture

- **Fluent Bit** (never catalogued — do not use as baseline)  
- CloudWatch as day-2 ops UI or primary alerting  

## Layout

| Path | Purpose |
|------|---------|
| [architecture.md](architecture.md) | OTel → LGTM paths |
| [alerts/](alerts/) | Mimir/Grafana rules (replace CW alarms) |
| [collectors/](collectors/) | **OpenTelemetry** Collector sketches only |
| [values-sketch.md](values-sketch.md) | Install notes |

## Install target

- **Services cluster:** LGTM backends + OTel gateway  
- **Workload cluster:** OTel agents/collectors shipping OTLP to Services  
- Grafana UI: OAuth2 Proxy + Keycloak (diagram identity path)  
