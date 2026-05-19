# 🔐 ELK Stack sécurisée avec Vault PKI & Ansible

![Ansible](https://img.shields.io/badge/Ansible-automation-red?logo=ansible)
![Vault](https://img.shields.io/badge/Vault-secrets-blue?logo=vault)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-logs-yellow?logo=elastic)
![Kibana](https://img.shields.io/badge/Kibana-visualization-orange?logo=kibana)
![Filebeat](https://img.shields.io/badge/Filebeat-shipper-lightgrey?logo=elastic)

---

## 📌 Description

Ce projet déploie une stack complète **Elasticsearch + Kibana + Filebeat** automatisée avec **Ansible**, sécurisée via **HashiCorp Vault PKI**.

✔ Zéro secret en dur  
✔ Certificats dynamiques  
✔ TLS bout-en-bout  
✔ Infrastructure reproductible  

---

## 🏗️ Architecture globale

```text
                  ┌──────────────┐
                  │   Vault      │
                  │ (PKI + KV2)  │
                  └──────┬───────┘
                         │
 ┌───────────────────────┼───────────────────────┐
 ▼                       ▼                       ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Elasticsearch│   │ Kibana       │   │ Filebeat     │
│ TLS + Auth   │   │ TLS + Auth   │   │ Logs Docker  │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       └──────────────┬───┴──────────────────┘
                      ▼
               🔐 CA Vault PKI
```

---

## 🏗️ Architecture détaillée (Mermaid)

```mermaid
flowchart LR

subgraph Vault["🔐 HashiCorp Vault"]
    PKI["PKI Engine"]
    KV["KV Secrets Engine"]
end

subgraph Ansible["⚙️ Ansible"]
    A1["vault_pki"]
    A2["vault_certs"]
    A3["vault_credentials"]
end

subgraph Elastic["📦 Elastic Stack"]
    ES["Elasticsearch"]
    KB["Kibana"]
    FB["Filebeat"]
end

PKI --> A2
KV --> A3

A2 --> ES
A2 --> KB
A2 --> FB

A3 --> ES
A3 --> KB
A3 --> FB

FB -->|TLS + API Key| ES
KB -->|TLS + kibana_system| ES
```

---

## 🔐 Sécurité

- TLS généré dynamiquement via Vault PKI  
- Secrets stockés dans Vault KV2  
- Keystore utilisé (Kibana / Filebeat)  
- API Key Elasticsearch pour ingestion  
- Aucun mot de passe en clair  

---

## ⚙️ Prérequis

- Ansible ≥ 2.14  
- HashiCorp Vault  
- Collections :
  - community.hashi_vault
  - ansible.posix

---

## 🚀 Deployment

```bash
ansible-playbook site.yml
```

---

## 🎯 Scope

Infrastructure de lab DevOps simulant un environnement de production sécurisé basé sur TLS + Vault PKI.

## 🧠 Design Principles

- Infrastructure as Code
- Zero Trust TLS by default
- Centralized secrets management
- Idempotent automation