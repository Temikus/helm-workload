# helm-workload

Generic helm chart that allows to run a multitude of applications.

## Usage

It is recommended to use this chart with [helmfile](https://github.com/helmfile/helmfile).

Simple container:
```
releases:
  - name: curl-example
    namespace: example
    chart: ../charts/workload
    kubeContext: k3s
    values:
      - image:
          repository: 'quay.io/curl/curl'
          tag: 'latest'
        command: ["sleep", "infinity"]
```

More complicated container with an Ingress and persistence:
```
releases:
  - name: homebridge
    namespace: homebridge
    chart: ../../charts/workload
    kubeContext: k3s
    values:
      - image:
          repository: homebridge/homebridge
          tag: 2024-01-08
      - persistence:
          enabled: true
          type: statefulset
          storageClassName: longhorn-retained
          mountPath: /homebridge
          accessModes:
            - ReadWriteOnce
          size: 5Gi
      - service:
            type: ClusterIP
            port: 8581
      - ports:
          - name: http
            port: 8581
            service:
              enabled: true
              port: 8581
              name: http
      - hostNetwork:
          enabled: true
      - ingress:
          enabled: true
          annotations:
            "kubernetes.io/ingress.class": "traefik"
            "cert-manager.io/cluster-issuer": "digitalocean-dns-production-issuer"
          hosts:
            - host: homebridge.example.com
              paths:
                - path: "/"
                  pathType: ImplementationSpecific
          tls:
            - secretName: homebridge-tls
              hosts:
                - homebridge.example.com
```

## Known limitations

- AppVersion is not supported, as it is not possible to set it dynamically based on the image tag. It is currently set to the same value as the chart version for all releases.

## Development

### Testing

    ```bash
    helm unittest .
    ```

## TODO

- [ ] Add more docs & examples
- [ ] Release chart on a public repository
- [ ] Autogenerate value docs
