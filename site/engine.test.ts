// The demo engine must give the same text as the Swift engine for the same keys.
import { expect, test } from "bun:test"
import { readFileSync } from "node:fs"
import { Session } from "./public/engine.js"
import { always, context, known } from "./public/engine-data.js"

const root = new URL("../", import.meta.url).pathname

function typeText(keys: string): string {
  const session = new Session()
  let out = ""
  for (const ch of keys) {
    const push = session.push(ch)
    if (push === "pass") out += ch
    if (push === "commit") out += session.finish().text + ch
  }
  return out + session.finish().text
}

// Telex cases from the app's own tests, English words alone and after each language, and seeded random keys.
const fromTests = [...readFileSync(`${root}Tests/TestMain.swift`, "utf8").matchAll(/\("([^"\\]+)", "[^"]*"\)/g)].map((m) => m[1])
const words = [...always.split(" "), ...context.split(" "), ...known.split(" ")]
let seed = 20261018
const random = () => (seed = (seed * 1664525 + 1013904223) % 2 ** 32) / 2 ** 32
const alphabet = "aaeeiioouuydwsfrxjzbcghklmnpqrtv  ."
const fuzz = Array.from({ length: 4000 }, () =>
  Array.from({ length: 1 + Math.floor(random() * 12) }, () => alphabet[Math.floor(random() * alphabet.length)]).join(""),
)
const vectors = [
  ...fromTests,
  ...words,
  ...words.map((w) => `git ${w}`),
  ...words.map((w) => `tooi ${w}`),
  ...words.map((w) => `toois ${w} ${w}`),
  "Tieengs Vieetj ddepj quas.", "Tooi dungf git reset roiof test lai.", "my_var user@host foo.bar(x) arm64",
  ...fuzz,
]

test("engine.js matches the Swift engine", async () => {
  const build = Bun.spawnSync([
    "swiftc", "-swift-version", "5", "-O", "-o", "/tmp/ankey-site-oracle",
    ...new Bun.Glob("Core/*.swift").scanSync({ cwd: root }).toArray().map((f) => root + f),
    `${root}site/scripts/oracle/main.swift`,
  ])
  expect(build.stderr.toString()).toBe("")
  const run = Bun.spawnSync(["/tmp/ankey-site-oracle"], { stdin: new TextEncoder().encode(vectors.join("\n") + "\n") })
  const swift = run.stdout.toString().split("\n").slice(0, vectors.length)
  const mismatches = vectors.flatMap((keys, i) => {
    const js = typeText(keys)
    return js === swift[i] ? [] : [`${JSON.stringify(keys)}: swift ${JSON.stringify(swift[i])}, js ${JSON.stringify(js)}`]
  })
  expect(mismatches.slice(0, 20)).toEqual([])
  expect(swift.length).toBe(vectors.length)
}, 120_000)
