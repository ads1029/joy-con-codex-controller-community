# Source attribution and licensing

## Upstream source

- Original project: [Jinjiang/joy-con-codex-micro](https://github.com/Jinjiang/joy-con-codex-micro)
- Upstream attribution: Jinjiang and the contributors recorded in Git history
- Fork baseline: upstream 0.1.12
- Community repository: [ads1029/joy-con-codex-controller-community](https://github.com/ads1029/joy-con-codex-controller-community)
- Current application name: Joy-Con Unified Controller

Basic single-Joy-Con input, layered mapping and the original controller workflow
are inherited. Fork enhancements are described in [CHANGELOG.md](CHANGELOG.md)
and the [fork policy](Docs/Community-Fork-Maintenance.md). Retained source target
names and older artwork reflect that history.

## License and authorization record

This fork is distributed under the [MIT License](LICENSE), with copyright
attribution retained for Jinjiang, upstream contributors and Minjie Huang.

The tracked upstream snapshot originally contained no detected `LICENSE`.
On 2026-10-28, fork maintainer Minjie Huang confirmed that the upstream
maintainer had directly permitted adding MIT to this fork. This repository
adopts MIT on the basis of that reported permission. This record does not
claim that the upstream repository itself has published the same license.

Keep the copyright and permission notices in copies or substantial portions of
the software. MIT licensing does not imply trademark rights, product endorsement,
notarization, or that a particular binary has passed release checks.

## Other references

Berrry Joyful was inspected as prior art for the unified workflow. The
implementation reuses this controller's core; it does not ship a second Berrry
process or a copied Berrry speech engine. There are no third-party Swift package
runtime dependencies in the current manifest.

Nintendo Switch and Joy-Con, Apple/macOS, OpenAI/Codex/ChatGPT and Anthropic/Claude
names identify interoperating products. This independent fork does not claim
endorsement by those projects or companies.
