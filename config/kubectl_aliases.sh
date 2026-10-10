# kubectl aliases — source this from ~/.bashrc or ~/.zshrc
# Pattern: k + verb-initial + resource-initial (+ optional suffix)
#   g=get  d=describe  e=edit  D=delete  a=apply
#   p=pods s=svc d=deploy n=nodes ns=namespaces i=ingress c=configmap sec=secret
#   ...w = watch, ...a = all namespaces, ...y = yaml, ...o = wide

# --- core ------------------------------------------------------------------
alias k='kubectl'
# keep tab-completion working on the alias (bash + zsh)
if [ -n "$BASH_VERSION" ]; then
  # bash-completion loads kubectl's completion lazily; without this __start_kubectl is undefined
  declare -F __start_kubectl >/dev/null || _comp_load kubectl 2>/dev/null
  complete -o default -F __start_kubectl k 2>/dev/null
elif [ -n "$ZSH_VERSION" ]; then
  compdef k=kubectl 2>/dev/null
fi

# switch default namespace / context
kns() {
  if [ -z "$1" ]; then
    kubectl config view --minify -o jsonpath='{..namespace}'; echo
  else
    kubectl config set-context --current --namespace="$1"
  fi
}
kctx() {
  if [ -z "$1" ]; then
    kubectl config get-contexts
  else
    kubectl config use-context "$1"
  fi
}

# --- get -------------------------------------------------------------------
alias kg='kubectl get'
alias kga='kubectl get all'
alias kgaa='kubectl get all --all-namespaces'
alias kgp='kubectl get pods'
alias kgpw='kubectl get pods -w'
alias kgpa='kubectl get pods --all-namespaces'
alias kgpo='kubectl get pods -o wide'
alias kgd='kubectl get deployments'
alias kgda='kubectl get deployments --all-namespaces'
alias kgs='kubectl get svc'
alias kgsa='kubectl get svc --all-namespaces'
alias kgn='kubectl get nodes'
alias kgno='kubectl get nodes -o wide'
alias kgns='kubectl get namespaces'
alias kgi='kubectl get ingress'
alias kgc='kubectl get configmaps'
alias kgsec='kubectl get secrets'
alias kgss='kubectl get statefulsets'
alias kgds='kubectl get daemonsets'
alias kgj='kubectl get jobs'
alias kgcj='kubectl get cronjobs'
alias kgpv='kubectl get pv'
alias kgpvc='kubectl get pvc'
alias kgev='kubectl get events --sort-by=.lastTimestamp'
alias kgeva='kubectl get events --all-namespaces --sort-by=.lastTimestamp'
alias kgcrd='kubectl get crds'

# --- describe --------------------------------------------------------------
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kds='kubectl describe svc'
alias kdn='kubectl describe node'
alias kdi='kubectl describe ingress'
alias kdc='kubectl describe configmap'
alias kdsec='kubectl describe secret'
alias kdss='kubectl describe statefulset'

# --- edit ------------------------------------------------------------------
alias ke='kubectl edit'
alias kep='kubectl edit pod'
alias ked='kubectl edit deployment'
alias kes='kubectl edit svc'
alias kec='kubectl edit configmap'

# --- apply / delete --------------------------------------------------------
alias ka='kubectl apply -f'
alias kak='kubectl apply -k'          # kustomize dir
alias kdiff='kubectl diff -f'
alias kdiffk='kubectl diff -k'
alias kD='kubectl delete'
alias kDf='kubectl delete -f'
alias kDp='kubectl delete pod'
alias kDpf='kubectl delete pod --grace-period=0 --force'

# --- logs / exec / debug ---------------------------------------------------
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias klp='kubectl logs -p'           # previous container
alias klt='kubectl logs --tail=100'
alias klft='kubectl logs -f --tail=100'
alias kx='kubectl exec -it'
alias kpf='kubectl port-forward'
alias kdbg='kubectl debug -it'
alias ktop='kubectl top pods'
alias ktopn='kubectl top nodes'
alias krun='kubectl run -it --rm --restart=Never tmp --image=busybox -- sh'

# --- rollouts / scaling ----------------------------------------------------
alias kro='kubectl rollout'
alias kros='kubectl rollout status'
alias kroh='kubectl rollout history'
alias kror='kubectl rollout restart'
alias krou='kubectl rollout undo'
alias ksc='kubectl scale'
alias ksd='kubectl scale deployment'

# --- yaml output ------------------------------------------------------------
alias kgy='kubectl get -o yaml'
alias kgpy='kubectl get pod -o yaml'
alias kgdy='kubectl get deployment -o yaml'
alias kgsy='kubectl get svc -o yaml'
alias kgcy='kubectl get configmap -o yaml'
alias kdry='kubectl create --dry-run=client -o yaml'

# --- misc ------------------------------------------------------------------
alias kav='kubectl api-versions'
alias kar='kubectl api-resources'
alias kex='kubectl explain'
alias kauth='kubectl auth can-i'
alias kci='kubectl cluster-info'
alias kcv='kubectl config view --minify'

# --- small helpers -----------------------------------------------------------
# exec into first container of a pod matched by name substring: kxs kafka
kxs() { kubectl exec -it "$(kubectl get pods -o name | grep -m1 "$1" | cut -d/ -f2)" -- "${2:-sh}"; }
# follow logs of pods matched by name substring: kls kafka
kls() { kubectl logs -f "$(kubectl get pods -o name | grep -m1 "$1")" "${@:2}"; }
# decode a secret's keys: ksecd my-secret
ksecd() { kubectl get secret "$1" -o go-template='{{range $k,$v := .data}}{{$k}}={{$v|base64decode}}{{"\n"}}{{end}}'; }
# pods not in Running/Completed
alias kgpbad="kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded"
# nodes with pod counts
alias kgnp='kubectl get pods --all-namespaces -o json | jq -r ".items[].spec.nodeName" | sort | uniq -c'
