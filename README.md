# A Different Hunting

My pet project designed to mass scan Bug Bounty targets using Cloud/DevOps/SRE best practices.

This repository is public so curious people can understand my hacking methodology and
to showcase my knowledge in Cloud DevOps Engineering for job interviews :stuck_out_tongue_winking_eye:

**It is intended for personal use, so there is no extensive documentation provided.**

> This project is licensed under the MIT license, so feel free to fork and customize it as you wish.

## How to Run

### Development / Testing

1. This will deploy everything locally with [kind](https://kind.sigs.k8s.io). Simply run:
```sh
./ops/apply.sh -e dev
```

2. To destroy the cluster once you're done run:
```sh
./ops/dev/delete_cluster.sh
```

### Production

1. Save your [SOPS](https://github.com/getsops/sops) Age Private Key into `~/.config/sops/age/keys.txt`.
> SOPS is used to securely expose this repository. All sensitive information is encrypted.

2. Connect to a Kubernetes Cluster.

3. Run:
```sh
./ops/apply.sh -e live
```

> Previously, I had ArgoCD installed for GitOps, but I found it unnecessary due to the low frequency
> of changes/deployments and the lack of team collaboration (as I am the sole manager of this environment).
>
> I may reintegrate it in the future if the project scales to the point where multiple Kubernetes clusters are needed.
>
> The old ArgoCD code can be found here: https://github.com/adiffpirate/adiffhunting/commit/0df6678679f0678b12b18271c5b4e333b2339124
