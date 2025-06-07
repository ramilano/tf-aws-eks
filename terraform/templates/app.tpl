apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${name}
  namespace: argocd
spec:
  destination:
    name: ''
    namespace: ${namespace}
    server: 'https://kubernetes.default.svc'
  source:
    path: ${path}
    repoURL: ${url}
    targetRevision: main
%{ if ishelm != "" ~}
    helm:
      valueFiles:
        - values.yml
%{ endif ~}
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
