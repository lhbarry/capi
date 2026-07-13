# Graph Report - capi  (2026-07-13)

## Corpus Check
- 6 files · ~60,274 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 53 nodes · 47 edges · 7 communities
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `61e2dac6`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]

## God Nodes (most connected - your core abstractions)
1. `Handoff: CAPA lab → next session (`aws_eks` + IAM layout)` - 8 edges
2. `IAM bootstrap (CAPA) — GitOps` - 8 edges
3. `Workload clusters (CAPI / CAPA) — GitOps` - 7 edges
4. `Decide IAM CloudFormation layout before any EKS work` - 6 edges
5. `aws_ec2 — GitOps source of truth for AWS` - 6 edges
6. `Workload cluster addons (`capi-lab-1`)` - 5 edges
7. `Kind management cluster (`capi-mgmt`) — Flux GitOps` - 4 edges
8. `Live environment snapshot (2026-07-13 EOD)` - 3 edges
9. `First task tomorrow (BLOCKING — decide at session start)` - 2 edges
10. `Session completed (aws_ec2)` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (7 total, 0 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.18
Nodes (10): Checklist for next session, Explicit non-goals at session start, Graphify, Handoff: CAPA lab → next session (`aws_eks` + IAM layout), Key paths, Live environment snapshot (2026-07-13 EOD), Principles (carry forward), Second task (after IAM decision): `aws_eks` (+2 more)

### Community 1 - "Community 1"
Cohesion: 0.22
Nodes (8): Apply (from YAML only), Correction history, Delete (from known stack; template remains in git), Files, Generate / refresh template (does not apply), IAM bootstrap (CAPA) — GitOps, Related (not in this template), Resources defined by the template

### Community 2 - "Community 2"
Cohesion: 0.25
Nodes (7): Apply, Delete, Network / NAT (lab), Rules, Status, Workload addons (CNI / CCM), Workload clusters (CAPI / CAPA) — GitOps

### Community 3 - "Community 3"
Cohesion: 0.29
Nodes (6): aws_ec2 — GitOps source of truth for AWS, Correct apply order (high level), Explicitly out of scope for this tree, Hard rules, Layout, Project goal

### Community 4 - "Community 4"
Cohesion: 0.33
Nodes (5): Apply (workload API only), Manifests (source of truth), Order, Why not Flux → Kind?, Workload cluster addons (`capi-lab-1`)

### Community 5 - "Community 5"
Cohesion: 0.29
Nodes (7): Decide IAM CloudFormation layout before any EKS work, Decision record (fill at start of session), First task tomorrow (BLOCKING — decide at session start), If option 1 — implement sketch, Options (pick one), What’s in the monolith today (11 resources), Why this is first

### Community 6 - "Community 6"
Cohesion: 0.40
Nodes (4): CAPA / AWS GitOps, Kind management cluster (`capi-mgmt`) — Flux GitOps, Layout, Weave GitOps UI (lab)

## Knowledge Gaps
- **37 isolated node(s):** `Why this is first`, `What’s in the monolith today (11 resources)`, `Options (pick one)`, `Decision record (fill at start of session)`, `If option 1 — implement sketch` (+32 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Handoff: CAPA lab → next session (`aws_eks` + IAM layout)` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Why does `First task tomorrow (BLOCKING — decide at session start)` connect `Community 5` to `Community 0`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **What connects `Why this is first`, `What’s in the monolith today (11 resources)`, `Options (pick one)` to the rest of the system?**
  _37 weakly-connected nodes found - possible documentation gaps or missing edges._