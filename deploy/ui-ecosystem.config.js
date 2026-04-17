// PM2 ecosystem — 110번 (jsong-demo-01) 정적 UI 서빙
// python3 http.server를 pm2로 데몬화 (nginx 불필요)
module.exports = {
  apps: [
    {
      name: 'meta-zkbridge-ui',
      script: '/usr/bin/python3',
      args: '-m http.server 8080 --bind 0.0.0.0',
      cwd: '/home/jsong/www/meta-zkbridge-ui',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      min_uptime: 10000,
      watch: false,
      error_file: '/home/jsong/logs/meta-zkbridge-ui.err.log',
      out_file: '/home/jsong/logs/meta-zkbridge-ui.out.log',
      time: true,
    },
  ],
};
