Goal

Built a Kubernetes app that polls api.turnip.exchange/islands/ and sends a Pushover notification when any island has turnipPrice >= 550. Lives in this repo's GitOps setup (ArgoCD auto-syncs from main).

Files added

- k8s/manifests/turnip-watch/turnip-watch.yaml — Namespace, ExternalSecret (pulling /talos-prod/pushover-creds from AWS Parameter Store), ConfigMap with embedded Python script, Deployment running python:3.12-slim.
- k8s/apps/turnip-watch.yaml — ArgoCD Application, picked up by all-apps.

Design decisions

- Deployment, not CronJob: long-running while True loop with in-memory dedupe state. Tradeoff: pod restart could cause one duplicate notification, but avoids needing a PVC for state.
- Python stdlib only (urllib, json, random): no custom container to build; script baked into a ConfigMap and mounted at /app/watch.py.
- Pushover (not SES): reuses the same /talos-prod/pushover-creds already used by alertmanager — no IAMRA role plumbing needed. ExternalSecret extracts token and user_key from the JSON SSM parameter.
- Poll cadence: BASE_INTERVAL_SECONDS=300 + random.uniform(0, JITTER_MAX_SECONDS=60) → 5–6 min between polls.
- Threshold: THRESHOLD=550 (env var).
- Sentinel handling: API returns a placeholder {"name":"No Islands", "turnipCode":"00000000", "turnipPrice":666} when no islands match. Filtered out by turnipCode == "00000000".
- Notification format: ONE message per set-change, not per island.
  - Title: "Turnip prices: max <max_price> bells"
  - Body: "<N> island(s) with turnipPrice >= 550"
- Dedupe: tracks the set of messageIDs above threshold across polls.
  - Fires when an island joins or leaves the set.
  - Does NOT fire when the set is unchanged.
  - Does NOT fire when the set becomes empty.
  - Known limitation: if a single listing's price changes (same messageID), we won't re-notify — the assumption is that turnip.exchange listings are reposts, not edits. Switch dedup key to (messageID, price) if that's wrong.
- API request mirrors the user's curl: POST body {"islander":"neither","category":"turnips"} with the Firefox User-Agent header.

Git state

3 commits on main, NOT pushed yet:
1. 717b533 Deploy turnip-watch notifier
2. 520bffe Filter turnip-watch sentinel "no islands" response
3. 2824a76 Summarize turnip-watch alerts into one notification per set change

ArgoCD will sync the app on push (auto-sync, self-heal, prune all enabled via all-apps).

Repo conventions referenced

- ArgoCD pattern: k8s/apps/<name>.yaml Application → k8s/manifests/<name>/ directory of plain YAML (no kustomization.yaml needed for single-dir apps; see heartbeats for a similar layout).
- ExternalSecret pattern: dataFrom.extract.key: /talos-prod/<name> with ClusterSecretStore aws-parameter-store — JSON keys in the SSM parameter become individual K8s secret keys.
