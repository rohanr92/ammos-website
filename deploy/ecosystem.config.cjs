// PM2 keeps the website running 24/7 and restarts it after a crash or a server reboot.
//   start:   pm2 start deploy/ecosystem.config.cjs
//   logs:    pm2 logs ammos
//   restart: pm2 reload ammos
module.exports = {
  apps: [
    {
      name: "ammos",
      cwd: "/var/www/ammos",
      script: "node_modules/next/dist/bin/next",
      args: "start -p 3000 -H 127.0.0.1",
      instances: 1, // one process (the login rate-limiter lives in memory)
      exec_mode: "fork",
      env: { NODE_ENV: "production" },
      max_memory_restart: "800M",
      time: true,
    },
  ],
};
