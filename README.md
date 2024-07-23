scaleway-demo-mesh
==================

Leverage [yawm](https://github.com/n-Arno/yawm) to build a Wireguard mesh between nodes.

- Create four nodes (2 PAR, 2 AMS)
- Install and configure Wireguard

Use case
--------

This could help have app clusters accross region. In each region, the cluster is accessed via VPC (for example via internal LB).

What's next
-----------

Create and configure a cluster (like cockroachDB) using VPN provided IPs for internal communication.

With some modification to yawm (PN subnet in allowedIP) plus a VIP in each region, this could be also used to create an HA site to site VPN once custom routes are implemented.


Usage
-----

Deploy yawm (good candidate for a Serverless container, max 1 replica) and add url and token in terraform.tfvars.

Execute Makefile
