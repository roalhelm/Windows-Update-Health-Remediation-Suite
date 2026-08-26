# Operating Model

## Roles

- Endpoint Engineering: code, configuration, ring design
- Service Desk: check status, collect log bundles, standard escalation
- Workplace Operations: pilot, deployment, reporting
- Hardware/OEM Team: storage, BIOS, and firmware findings
- Security: script signing, AV/EDR exceptions only after review

## KPIs

- Healthy / Repairable / Escalated per ring
- Remediation success rate
- Repeat offender rate
- Findings by manufacturer, model, BIOS, and storage/driver provider
- Time since last successful update installation

## Escalation

- Storage Event 55/98/129/153/157: diagnose, backup status, OEM testing
- PnP errors: identify affected device and driver package
- RepairCount >= threshold: no further blind repair
- DISM not repairable: suitable repair source or controlled in-place upgrade
