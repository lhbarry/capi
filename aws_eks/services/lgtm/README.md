# Grafana LGTM + OpenTelemetry (diagram services)

Matches **ARCHITECTURE.md §7** and `docs/architecture.svg`:

| Diagram label | Role |
|---------------|------|
| **OpenTelemetry** · Collector · OTLP | Telemetry collection (Obs. Infra) |
| **Grafana LGTM** · Loki · Tempo · Mimir | Observability backend |

## Not in architecture

- Any telemetry agent other than **OpenTelemetry**  
- CloudWatch as day-2 ops UI or primary alerting  
- New AWS rail products beyond **EFS · EBS · S3**  


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
