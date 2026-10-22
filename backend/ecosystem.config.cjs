// pm2 process definition for the AG Farmer API only.
// Deploy:  pm2 startOrReload ecosystem.config.cjs --only ag-farmer-api && pm2 save
// Never use `pm2 restart all` on this host — other apps share the pm2 daemon.
module.exports = {
  apps: [
    {
      name: 'ag-farmer-api',
      script: 'src/server.js',
      cwd: '/opt/ag-farmer-backend',
      exec_mode: 'fork',
      instances: 1,
      node_args: '--max-old-space-size=8192',
      env: {
        NODE_ENV: 'production',
      },
      // server.js calls process.send('ready') once listening, so pm2 only
      // reports "online" when the port is actually accepting requests.
      wait_ready: true,
      listen_timeout: 15000,
      // SIGINT → finish in-flight chat/voice requests (server.js waits up to
      // 10s) before pm2 escalates to SIGKILL.
      kill_timeout: 12000,
      shutdown_with_message: false,
      autorestart: true,
      max_memory_restart: '6G',
      exp_backoff_restart_delay: 200,
      max_restarts: 30,
      min_uptime: 5000,
      time: true,
      merge_logs: true,
    },
  ],
};
