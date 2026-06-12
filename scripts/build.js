const fs = require('fs');
const path = require('path');

const pkg = require('../package.json');
const buildInfo = {
  name: pkg.name,
  version: pkg.version,
  buildTime: new Date().toISOString(),
  commit: process.env.GITHUB_SHA || 'local',
  runNumber: process.env.GITHUB_RUN_NUMBER || '0',
};

fs.mkdirSync(path.join(__dirname, '..', 'dist'), { recursive: true });
fs.writeFileSync(
  path.join(__dirname, '..', 'dist', 'build-info.json'),
  JSON.stringify(buildInfo, null, 2)
);

console.log('Build info written to dist/build-info.json');
console.log(JSON.stringify(buildInfo, null, 2));
