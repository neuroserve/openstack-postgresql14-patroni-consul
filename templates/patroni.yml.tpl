scope: ${consul_scope}
namespace: ${consul_namespace}
name: ${hostname}

restapi:
  listen: ${listen_ip}:8008
  connect_address: ${listen_ip}:8008

consul:
  host: localhost:8500
  register_service: true
  cacert: /etc/consul/certificates/ca.pem
  cert: /etc/consul/certificates/cert.pem
  key: /etc/consul/certificates/private_key.pem
  dc: ${consul_datacenter}

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:
        archive_mode: 'on'
        archive_command: '/bin/true'
        archive_timeout: 1800s
        autovacuum_analyze_scale_factor: 0.02
        autovacuum_max_workers: 5
        autovacuum_vacuum_scale_factor: 0.05
        checkpoint_completion_target: 0.9
        effective_cache_size: 30GB
        effective_io_concurrency: 300
        enable_partitionwise_aggregate: 'on'
        enable_partitionwise_join: 'on'
        hot_standby: 'on'
        log_autovacuum_min_duration: 0
        log_checkpoints: 'on'
        log_connections: 'on'
        log_disconnections: 'on'
        log_line_prefix: '%t [%p]: [%l-1] %c %x %d %u %a %h '
        log_lock_waits: 'on'
        log_min_duration_statement: 500
        log_statement: ddl
        log_temp_files: 0
        maintenance_work_mem: 2GB
        max_connections: 3000
        max_parallel_maintenance_workers: 8
        max_parallel_workers: 12
        max_parallel_workers_per_gather: 8
        max_replication_slots: 10
        max_standby_streaming_delay: -1
        max_wal_senders: 10
        max_worker_processes: 12
        random_page_cost: 1.5
        shared_buffers: 12GB
        tcp_keepalives_idle: 900
        tcp_keepalives_interval: 100
        track_functions: all
        track_io_timing: 'on'
        track_wal_io_timing: 'on'
        wal_buffers: -1
        wal_compression: 'on'
        wal_level: hot_standby
        wal_log_hints: 'on'
        work_mem: 10MB
        shared_preload_libraries: 'pg_stat_monitor'
        pg_stat_monitor.pgsm_query_max_len: 4096
        track_activity_query_size: 2048
        pg_stat_statements.track: all
        track_io_timing: 'on'

  # some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - data-checksums

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator 192.168.0.0/24 md5
  - host all all 0.0.0.0/0 md5
  - local all pmm md5

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

  # Some additional users users which needs to be created after initializing new cluster
  users:
    admin:
      password: ${admin_password}
      options:
        - createrole
        - createdb

postgresql:
  listen: "*:5432"
  connect_address: ${listen_ip}:5432
  data_dir: /var/lib/postgresql/data
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: rep-pass
    superuser:
      username: postgres
      password: ${admin_password}
    rewind:  # Has no effect on postgres 10 and lower
      username: rewind_user
      password: rewind_password
  parameters:
    unix_socket_directories: '/var/run/postgresql'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
