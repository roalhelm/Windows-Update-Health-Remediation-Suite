# In-place Upgrade as Escalation

## Gate

Consider this only when:

- storage/hardware risks have been assessed
- sufficient free space is available
- media matches architecture, edition, and language
- compatibility has been verified
- BitLocker, EDR, VPN, and critical apps have been reviewed
- backup/OneDrive status and end-user communication are clear

## Example, not enabled automatically

```cmd
setup.exe /auto upgrade /quiet /eula accept /dynamicupdate enable
```

Windows Setup must be monitored using the SetupDiag and Panther logs. A client that remains problematic after another in-place upgrade is not treated endlessly this way; it is escalated as a Repeat Offender.
