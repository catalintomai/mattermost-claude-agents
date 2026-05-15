Drop and recreate the local Mattermost test database to clear stale migration records.

Run:
```bash
dropdb -U mmuser mattermost_test && createdb -U mmuser mattermost_test
```

Then confirm success and remind the user to restart the server so migrations re-apply from scratch.

Note: This is for local (non-Docker) PostgreSQL setups. If using Docker, use `make clean-docker && make start-docker` instead.
