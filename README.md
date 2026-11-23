# ts-6lbr-setup
Setup Tailscale + nginx + 6LBR untuk gateway Raspberry Pi.

```bash
git clone https://github.com/<owner>/ts-6lbr-setup.git
cd ts-6lbr-setup
nano site.conf                     # IP 6LBR, site ID, subnet, port
nano templates/node_config.conf    # senarai node
bash setup.sh
```
Jangan simpan password / auth key dalam repo ni.
