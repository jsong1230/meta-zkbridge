// PM2 ecosystem — 150번 (cp-gpusrv-1, H100 GPU) 배포
// operator = prover(GPU) + tx sender
// 실행: pm2 start deploy/ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'meta-zkbridge-operator',
      script: './prover/run-operator.sh',
      args: '',
      cwd: '/home/jsong/deploy/meta-zkbridge',
      interpreter: 'bash',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      restart_delay: 30000,   // 30초. proving 재시도 간격
      min_uptime: 120000,     // 2분 미만 죽으면 실패 (첫 빌드 시간 감안)
      watch: false,
      max_memory_restart: '8G', // GPU proving은 메모리 사용량 높을 수 있음
      env: {
        RUST_LOG: 'info,operator=debug',
      },
      error_file: '/home/jsong/logs/meta-zkbridge-operator.err.log',
      out_file: '/home/jsong/logs/meta-zkbridge-operator.out.log',
      time: true,
    },
  ],
};
