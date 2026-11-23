// infra/pm2/ecosystem.config.cjs — PM2 process list for AliNetwork
// Start:   pm2 start /srv/alinetwork/infra/pm2/ecosystem.config.cjs
// Reload:  pm2 reload /srv/alinetwork/infra/pm2/ecosystem.config.cjs --only prod-api
// Boot:    pm2 save && pm2 startup
//
// CPU budget on KVM 8 (8 vCPU, 32 GB RAM):
//   production: api 3 + worker 1 + storefront 2
//   staging:    1 each
//   remaining capacity: Postgres, Valkey, Meilisearch (Docker), Caddy

const ROOT = '/srv/alinetwork';
const LOGS = '/var/log/alinetwork';

const common = {
  autorestart: true,
  max_restarts: 10,
  restart_delay: 3000,
  kill_timeout: 10000, // let in-flight requests finish
  listen_timeout: 15000,
  time: true,
  merge_logs: true,
};

function api(env, port, instances, memory) {
  const prefix = env === 'production' ? 'prod' : 'staging';
  return {
    ...common,
    name: `${prefix}-api`,
    cwd: `${ROOT}/${env}/current/services/api`,
    script: 'dist/main.js',
    node_args: `--env-file=${ROOT}/secrets/${env}/api.env`,
    exec_mode: 'cluster',
    instances,
    max_memory_restart: memory,
    env: { NODE_ENV: 'production', APP_MODE: 'api', PORT: port },
    out_file: `${LOGS}/${prefix}-api.out.log`,
    error_file: `${LOGS}/${prefix}-api.err.log`,
  };
}

function worker(env, memory) {
  const prefix = env === 'production' ? 'prod' : 'staging';
  return {
    ...common,
    name: `${prefix}-worker`, // outbox relay, jobs, webhooks, search sync
    cwd: `${ROOT}/${env}/current/services/api`,
    script: 'dist/main.js',
    node_args: `--env-file=${ROOT}/secrets/${env}/api.env`,
    exec_mode: 'fork',
    instances: 1,
    max_memory_restart: memory,
    env: { NODE_ENV: 'production', APP_MODE: 'worker' },
    out_file: `${LOGS}/${prefix}-worker.out.log`,
    error_file: `${LOGS}/${prefix}-worker.err.log`,
  };
}

function storefront(env, port, instances, memory) {
  const prefix = env === 'production' ? 'prod' : 'staging';
  return {
    ...common,
    name: `${prefix}-storefront`, // Next.js standalone build
    cwd: `${ROOT}/${env}/current/apps/storefront/.next/standalone/apps/storefront`,
    script: 'server.js',
    node_args: `--env-file=${ROOT}/secrets/${env}/storefront.env`,
    exec_mode: 'cluster',
    instances,
    max_memory_restart: memory,
    env: { NODE_ENV: 'production', PORT: port, HOSTNAME: '127.0.0.1' },
    out_file: `${LOGS}/${prefix}-storefront.out.log`,
    error_file: `${LOGS}/${prefix}-storefront.err.log`,
  };
}

module.exports = {
  apps: [
    // ---------- PRODUCTION ----------
    api('production', 4000, 3, '1G'),        // api.alinetwork.store
    worker('production', '1G'),
    storefront('production', 3000, 2, '800M'), // alinetwork.store

    // ---------- STAGING ----------
    api('staging', 4100, 1, '600M'),         // staging-api.alinetwork.store
    worker('staging', '500M'),
    storefront('staging', 3100, 1, '500M'),  // staging.alinetwork.store

    // LATER (Go sync gateway, only when monitoring shows it is needed):
    // { ...common, name: 'prod-sync', cwd: `${ROOT}/production/current/services/sync-gateway`,
    //   script: './bin/sync', interpreter: 'none', env: { PORT: 4500 } },
  ],
};
