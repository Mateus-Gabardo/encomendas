import { readFile, writeFile } from 'node:fs/promises';

const [version] = process.argv.slice(2);
if (!/^\d+\.\d+\.\d+$/.test(version ?? '')) {
  throw new Error('Informe uma versao semantica, por exemplo: 1.2.3');
}

const pubspecPath = 'pubspec.yaml';
const pubspec = await readFile(pubspecPath, 'utf8');
const current = pubspec.match(/^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$/m);
if (current == null) {
  throw new Error('Nao foi possivel localizar a versao no pubspec.yaml');
}

const buildNumber = Number.parseInt(current[1], 10) + 1;
const updated = pubspec.replace(current[0], `version: ${version}+${buildNumber}`);
await writeFile(pubspecPath, updated);
