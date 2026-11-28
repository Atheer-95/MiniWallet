4. Interpretation:
   - ORA-471: a critical background process died. DBW0 (Database Writer) writes changed blocks from memory to the data files, so Oracle cannot run without it.
   - Almost no free memory and no free swap: the Linux kernel killed a process to free memory.
5. Check memory use of all containers:
   ```bash
   docker stats --no-stream
   ```

## Resolution

1. Restart the container:
   ```bash
   docker compose restart oracle
   ```
2. Follow the log until it shows `DATABASE IS READY TO USE!`:
   ```bash
   docker compose logs -f oracle
   ```
3. Confirm the status is `healthy`:
   ```bash
   docker compose ps
   ```
4. Confirm the data is intact (as miniwallet):
   ```sql
   SELECT COUNT(*) FROM txn_types;
   ```
   On startup Oracle performs instance recovery from the redo logs, so all committed data is kept.

## Prevention

- Run only one Oracle container at a time; stop the separate SQL lab container (`oracle-xe`) before starting MiniWallet.
- Give Docker Desktop at least 6 GB of memory (Settings → Resources → Memory).
- Stop containers that are not in use.
- Add monitoring and an alert on database health (planned in sprints 11 and 12), so a crash is found in minutes, not days.

## Lessons learned

- A running container does not mean a working database: always check the health status.
- The health check was correct, but nothing alerted on it, so the outage went unnoticed for 5 days.
- The alert log gives the root cause directly: read it from the end and look for `ORA-` errors and the memory summary.

## Related errors

| Error | Meaning |
| --- | --- |
| ORA-471 | Database Writer process terminated with error |
| ORA-1092 | Oracle instance terminated; disconnection forced |
| ORA-12514 / DPY-6001 | Listener has no service with that name; the database is down or still starting |


## Recurrence (2026-11-28)

The crash happened again: same ORA-471. Both crashes happened before the transaction seed load, so load was not the trigger; the first one started at exactly 22:00 UTC, when Oracle's nightly maintenance window begins.

Evidence (cgroup memory.stat, idle, 3 GB limit):

| Type | Size | Reclaimable |
| --- | --- | --- |
| anon (process memory) | 1.55 GiB | No |
| shmem (SGA) | 1.13 GiB | No |
| page cache (file - shmem) | 0.18 GiB | Yes |
| Non-reclaimable total | 2.68 GiB | |

- `docker stats` alone is misleading: it counts page cache, which the kernel can free.
- The alert log's "Memory (Avail / Total)" line shows the whole Docker VM, not the container limit.

Root cause: Oracle XE needs about 2.7 GB that cannot be freed (SGA, process memory and amd64 emulation overhead on Apple Silicon). A 2 GB limit could never fit it; any extra memory need, such as the maintenance window jobs, triggered the kernel to kill DBW0.

Permanent fix: raised `mem_limit` from 2g to 4g.
Possible later improvement: lower `sga_target` to 1 GB.
