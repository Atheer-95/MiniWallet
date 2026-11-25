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
