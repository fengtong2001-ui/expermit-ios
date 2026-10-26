// 取核心仓网页包，铺进 Xcode 工程的 ExPermit/www（folder reference 会自动打进 App）
// 用法：
//   node scripts/fetch-www.mjs --ver 0.1.4
//   node scripts/fetch-www.mjs --core ../expermit-eln     # 本地调试
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { unzipSync } from 'fflate'

const CORE_REPO = 'fengtong2001-ui/expermit-eln'
const root = join(import.meta.dirname, '..')
const arg = (n, d = null) => {
  const i = process.argv.indexOf(n)
  return i > -1 && i + 1 < process.argv.length ? process.argv[i + 1] : d
}
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'))
const ver = arg('--ver', pkg.version)
const core = arg('--core')
const www = join(root, 'ExPermit', 'www')

rmSync(www, { recursive: true, force: true })
mkdirSync(www, { recursive: true })

if (core) {
  const c = resolve(core)
  if (!existsSync(join(c, 'dist', 'index.html'))) throw new Error(`本地核心仓没有 dist/：${c}（先跑 npm run build）`)
  cpSync(join(c, 'dist'), www, { recursive: true })
  console.log(`✓ 用本地核心仓：${c}`)
} else {
  const url = `https://github.com/${CORE_REPO}/releases/download/v${ver}/www-${ver}.zip`
  const r = await fetch(url)
  if (!r.ok) throw new Error(`下载失败 ${r.status}：${url}`)
  for (const [path, bytes] of Object.entries(unzipSync(new Uint8Array(await r.arrayBuffer())))) {
    const f = join(www, path)
    mkdirSync(join(f, '..'), { recursive: true })
    writeFileSync(f, bytes)
  }
  console.log(`✓ 已从核心仓 v${ver} 取回网页包`)
}

pkg.version = ver
writeFileSync(join(root, 'package.json'), JSON.stringify(pkg, null, 2) + '\n')
console.log(`✓ ExPermit/www 就绪（版本 ${ver}，${existsSync(join(www, 'index.html')) ? 'index.html 存在' : '缺 index.html'}）`)
