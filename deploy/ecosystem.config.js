// PM2 ecosystem — 110번 (jsong-demo-01) 배포 상정
// 실행: pm2 start deploy/ecosystem.config.js --env production
module.exports = {
  apps: [
    {
      name: 'meta-zkbridge-operator',
      script: './prover/run-operator.sh',
      // run-operator.sh 자체가 prover/config/metadium-testnet.env 를 로드
      args: '',
      cwd: '/home/jsong/deploy/meta-zkbridge',
      interpreter: 'bash',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      restart_delay: 30000,   // 30초. prover API 과호출 방지
      min_uptime: 60000,      // 60초 미만 죽으면 실패로 집계
      watch: false,
      max_memory_restart: '2G',
      env: {
        NODE_ENV: 'production',
        RUST_LOG: 'info',
      },
      error_file: '/home/jsong/logs/meta-zkbridge-operator.err.log',
      out_file: '/home/jsong/logs/meta-zkbridge-operator.out.log',
      time: true,
    },
  ],
};
