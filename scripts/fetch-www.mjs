// 从核心仓取网页制品（www-<ver>.zip），解到 ExPermit/www
// 用法：
//   node scripts/fetch-www.mjs --ver 0.1.4                       # 从核心仓 Release 下载
//   node scripts/fetch-www.mjs --core ../expermit-eln            # 本地调试：直接用核心仓 dist/
//
// 核心仓发布 Release 时，core-artifacts 工作流会附加 www-<ver>.zip。
// 若远端还没有该制品，先在核心仓 Actions → Core artifacts 手动跑一次。
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
  if (!existsSync(join(c, 'dist', 'index.html'))) {
    throw new Error(`本地核心仓没有 dist/：${c}（先在其目录跑 npm run build）`)
  }
  cpSync(join(c, 'dist'), www, { recursive: true })
  console.log(`✓ 用本地核心仓 dist：${c}`)
} else {
  const asset = `www-${ver}.zip`
  const direct = `https://github.com/${CORE_REPO}/releases/download/v${ver}/${asset}`
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || ''

  async function download(url, headers = {}) {
    const r = await fetch(url, { headers })
    if (r.status === 302 || r.status === 301) {
      return download(r.headers.get('location'), headers)
    }
    if (!r.ok) throw new Error(`${r.status} ${url}`)
    return new Uint8Array(await r.arrayBuffer())
  }

  let bytes
  try {
    bytes = await download(direct)
  } catch (err) {
    // 直连失败时走 API（api.github.com 在部分网络下比 github.com 稳）
    console.warn(`直连下载失败（${err.message}），改用 API 取制品…`)
    const headers = { Accept: 'application/vnd.github+json' }
    if (token) headers.Authorization = `Bearer ${token}`
    const rel = await fetch(`https://api.github.com/repos/${CORE_REPO}/releases/tags/v${ver}`, { headers })
    if (!rel.ok) throw new Error(`核心仓没有 v${ver} 的 Release（${rel.status}）`)
    const assets = (await rel.json()).assets ?? []
    const hit = assets.find((a) => a.name === asset)
    if (!hit) {
      throw new Error(
        `核心仓 v${ver} 的 Release 里没有 ${asset}。\n` +
          `在核心仓跑一次 Actions → Core artifacts（version=${ver}），或本地用 --core ../expermit-eln。`
      )
    }
    bytes = await download(hit.url, { Accept: 'application/octet-stream', ...(token ? { Authorization: `Bearer ${token}` } : {}) })
  }

  const files = unzipSync(bytes)
  for (const [path, data] of Object.entries(files)) {
    const f = join(www, path)
    mkdirSync(join(f, '..'), { recursive: true })
    writeFileSync(f, data)
  }
  console.log(`✓ 已从核心仓 v${ver} 取回 ${asset}`)
}

pkg.version = ver
writeFileSync(join(root, 'package.json'), JSON.stringify(pkg, null, 2) + '\n')
console.log(`✓ ExPermit/www 就绪（版本 ${ver}）`)
