# Lab EKS: IRSA, Terraform și deployment 2-tier cu Helm
---

## 1. EKS — concepte de bază

### Managed Node Groups vs Fargate Profiles

| | Managed Node Groups | Fargate Profiles |
|---|---|---|
| Compute | EC2 instances gestionate de EKS via ASG | Micro-VM per pod, fără noduri vizibile |
| Control | Instance type, AMI, scaling | Doar namespace + labels |
| Workloads suportate | Orice (DaemonSets, privileged, GPU) | Limitat (fără DaemonSets, hostNetwork, GPU) |
| Cost | Per capacitate EC2, indiferent de utilizare | Per pod (vCPU/memorie cerute) |
| Echivalent GCP | GKE node pools | Fără echivalent direct (parțial GKE Autopilot) |

---

## 2. IRSA — IAM Roles for Service Accounts

Scop: pod-urile primesc credențiale AWS temporare, fără chei statice, prin OIDC federation + AWS STS.

### Flux

```
Pod (serviceAccountName)
   → ServiceAccount (adnotat cu eks.amazonaws.com/role-arn)
   → Token JWT proiectat (injectat de EKS Pod Identity Webhook)
   → AWS STS: AssumeRoleWithWebIdentity
   → validare via IAM OIDC provider (înregistrat pentru cluster)
   → IAM Role (trust policy verifică namespace:serviceaccount)
   → credențiale temporare → apeluri AWS API (S3, DynamoDB etc.)
```

### Resurse Terraform create

- `aws_iam_openid_connect_provider` — înregistrează OIDC issuer-ul clusterului în IAM
- `aws_iam_policy` — permisiunile efective (ex. `s3:GetObject`, `s3:ListBucket`)
- `data.aws_iam_policy_document` (trust policy) — restricționează assume-role la un `namespace:serviceaccount` exact, via condiții `sub` și `aud`
- `aws_iam_role` + `aws_iam_role_policy_attachment`
- `kubernetes_service_account` (opțional în Terraform, sau aplicat separat via `kubectl`)

### Comenzi cheie

```bash
# aplicare
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# verificare identitate reala din pod
kubectl run aws-cli-test --rm -it \
  --image=amazon/aws-cli \
  --serviceaccount=<sa-name> \
  --namespace=<namespace> \
  --command -- aws sts get-caller-identity
```

### Cauze frecvente de eșec

- `serviceAccountName` din pod nu se potrivește exact cu numele din trust policy
- namespace greșit (trust policy verifică exact `system:serviceaccount:<ns>:<sa>`)
- pod pornit înainte de adnotarea SA — webhook-ul injectează doar la creare, pod-ul trebuie recreat

---

## 3. Deployment 2-tier cu Helm — Redis (backend) + Frontend

### Arhitectură

```
Client extern
   → Service web-frontend (LoadBalancer, port 80 → targetPort 8080)
   → Pod-uri frontend (Spring Boot, retail-store-sample-ui)
   → Service backend-redis-master (ClusterIP, port 6379)
   → Pod Redis
```

### Backend — Redis

Chart adus local (nu referit remote):

```bash
helm pull bitnami/redis --version 20.1.5 --untar --untardir ./charts
```

Override-uri esențiale în `redis-values.yaml`:

```yaml
architecture: standalone
auth:
  enabled: false          # simplificare pentru lab; NU pentru productie
master:
  service:
    type: ClusterIP
  persistence:
    enabled: false         # elimina PVC — evita nevoia de StorageClass
replica:
  replicaCount: 0
fullnameOverride: backend-redis
```

```bash
helm install backend ./charts/redis -f redis-values.yaml -n app --create-namespace
```

### Frontend — chart custom

Structură: `Chart.yaml`, `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`.

Imagine folosită: `public.ecr.aws/aws-containers/retail-store-sample-ui:1.0.0` (aplicație demo Spring Boot, publicată oficial de AWS pe ECR Public).

```yaml
image:
  repository: public.ecr.aws/aws-containers/retail-store-sample-ui
  tag: "1.0.0"
service:
  type: LoadBalancer
  port: 80
  targetPort: 8080
```

```bash
helm install web ./frontend-chart -n app
```

### Probes calibrate pentru boot time JVM (~40s)

```yaml
readinessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 50
livenessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 100
  periodSeconds: 15
  failureThreshold: 3
```

### Acces la frontend

```bash
# varianta 1: ELB extern
kubectl get svc web-frontend -n app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# varianta 2: port-forward pentru test rapid
kubectl port-forward svc/web-frontend -n app 8080:80
# -> http://localhost:8080
```

---

## 4. Probleme întâlnite și rezolvate

| Problemă | Cauză | Fix |
|---|---|---|
| `nil pointer evaluating .Values.sentinel.service.type` | `values.yaml` din chart suprascris în loc de fișier separat | repull chart curat, override-uri într-un fișier extern (`-f redis-values.yaml`) |
| `no nodes available to schedule` + `unbound pvc must define a storage class` | EKS Auto Mode nu are StorageClass implicit; Redis cerea PVC fără `storageClassName` | `persistence.enabled: false` (sau `storageClass: auto-ebs-sc` dacă vrei persistență) |
| `azure-vote-front:v1 not found` | Microsoft a șters imaginile `azuredocs` din MCR (august 2025+) | migrare la imagine oficială AWS: `retail-store-sample-ui` |
| `bitnami/redis:7.4.0-debian-12-r4 not found` | Broadcom a mutat majoritatea imaginilor Bitnami în `bitnamilegacy`, catalogul gratuit fiind restructurat | `repository: bitnamilegacy/redis` + `global.security.allowInsecureImages: true` |
| `retail-store-sample-ui:v1 not found` | Tag greșit — versiunea corectă e semver, nu `v1` | `tag: "1.0.0"` |
| Pod killed la ~90s după pornire (liveness) | Probe cu `initialDelaySeconds` prea mic față de boot time-ul Spring Boot (~40s) | `initialDelaySeconds: 100` pe liveness, cu marjă |
| `port-forward` → `connection refused` pe portul 80 | `targetPort` greșit în Service (80 în loc de 8080, portul real ascultat de container) | `targetPort: 8080` în `values.yaml`, urmat de `helm upgrade` |

---

## 5. Lecții cheie

- **Override-urile Helm merg mereu într-un fișier separat**, niciodată peste `values.yaml`-ul original al chart-ului — acesta din urmă documentează toate cheile disponibile și trebuie păstrat intact.
- **`-target` la Terraform apply** e util pentru debugging pas-cu-pas, dar nu e workflow standard — riscă state parțial inconsistent.
- **Aplicațiile JVM au boot time semnificativ** — probe-urile implicite (gândite pentru aplicații ușoare) trebuie recalibrate explicit pentru workload-uri Java/Spring Boot.
- **`targetPort` ≠ `port`** — `port` e ce expune Service-ul extern, `targetPort` trebuie să corespundă exact portului pe care ascultă efectiv containerul.