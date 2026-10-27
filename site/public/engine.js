// Browser port of Core/Engine.swift for the demo on the home page: Telex rendering, the Vietnamese syllable check,
// the English word bands and the language of the previous word. Learning (corrections, habits), shorthand beyond
// `đc`, cheat codes and phrase suggestions stay in the app.
// site/engine.test.ts runs this against the Swift engine, so a change to Engine.swift that this file misses fails there.
import { syllables, always, context, known } from "./engine-data.js"

const VI = "vietnamese"
const EN = "english"
const ENGLISH_THRESHOLD = 2
const SHORTHAND = new Set(["đc"])

// Tones: 0 none, 1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng.
const TELEX_TONE = { s: 1, f: 2, r: 3, x: 4, j: 5 }

// MARK: - English bands

const band = new Map()
for (const word of known.split(" ")) band.set(word, 0)
for (const word of context.split(" ")) band.set(word, 1)
for (const word of always.split(" ")) band.set(word, 2)

// MARK: - Syllables

const TONE_MARKS = { "́": 1, "̀": 2, "̉": 3, "̃": 4, "̣": 5 }

/** For every leading part of every toneless syllable, the tones the syllables beginning with it carry. */
const prefixTones = new Map()
for (const syllable of syllables.split(" ")) {
  let tone = 0
  let toneless = ""
  for (const ch of syllable.normalize("NFD")) {
    if (ch in TONE_MARKS) tone = TONE_MARKS[ch]
    else toneless += ch
  }
  let prefix = ""
  for (const ch of toneless.normalize("NFC")) {
    prefix += ch
    if (!prefixTones.has(prefix)) prefixTones.set(prefix, new Set())
    prefixTones.get(prefix).add(tone)
  }
}

function accepts(toneless, tone) {
  const tones = prefixTones.get(toneless)
  return tones !== undefined && (tone === 0 || tones.has(tone))
}

// MARK: - Atoms

const atom = (base, upper) => ({ base, upper, hat: "none", stroke: false, markKey: null })
const isVowel = (a) => "aeiouy".includes(a.base)

function nucleus(a) {
  if (a.base === "a" && a.hat === "circumflex") return "â"
  if (a.base === "a" && a.hat === "breve") return "ă"
  if (a.base === "e" && a.hat === "circumflex") return "ê"
  if (a.base === "o" && a.hat === "circumflex") return "ô"
  if (a.base === "o" && a.hat === "horn") return "ơ"
  if (a.base === "u" && a.hat === "horn") return "ư"
  return a.base
}

const hasVowel = (atoms) => atoms.some(isVowel)

/** The last vowel run as [lo, hi). `gi` and `qu` are initials when a vowel follows the i/u. */
function vowelRange(atoms) {
  const hidden = new Set()
  const restHasVowel = atoms.slice(2).some(isVowel)
  if (atoms.length >= 3 && atoms[0].base === "g" && !atoms[0].stroke && atoms[0].hat === "none"
      && atoms[1].base === "i" && atoms[1].hat === "none" && restHasVowel) {
    hidden.add(1)
  } else if (atoms.length >= 3 && atoms[0].base === "q" && atoms[1].base === "u" && atoms[1].hat === "none" && restHasVowel) {
    hidden.add(1)
  }
  let best = [atoms.length, atoms.length]
  let index = 0
  while (index < atoms.length) {
    if (isVowel(atoms[index]) && !hidden.has(index)) {
      const start = index
      index += 1
      while (index < atoms.length && isVowel(atoms[index]) && !hidden.has(index)) index += 1
      best = [start, index]
    } else {
      index += 1
    }
  }
  return best
}

const range = ([lo, hi]) => Array.from({ length: hi - lo }, (_, i) => lo + i)

// MARK: - Telex consume

/** Returns true when the key undid a mark (`noww` → `now`). */
function consume(s, key, upper) {
  const afterTone = s.toneFrom !== null
  const repeated = s.markFrom === key
  s.markFrom = null
  if (key === s.escaped) {
    s.atoms.push(atom(key, upper))
    s.escaped = null
    s.toneFrom = null
    return false
  }
  s.escaped = null
  if (key === "z") {
    s.toneFrom = null
    if (s.tone !== 0) s.tone = 0
    else s.atoms.push(atom(key, upper))
    return false
  }
  const next = TELEX_TONE[key]
  if (next !== undefined) {
    if (hasVowel(s.atoms)) {
      if (s.tone === next && s.toneFrom === key) {
        s.tone = 0
        s.toneFrom = null
        s.escaped = key
        s.atoms.push(atom(key, upper))
      } else {
        s.tone = next
        s.toneFrom = key
      }
    } else {
      s.toneFrom = null
      s.atoms.push(atom(key, upper))
    }
    return false
  }
  s.toneFrom = null
  const intent = "aeo".includes(key) ? "circumflex" : key === "w" ? "hornOrBreve" : key === "d" ? "stroke" : null
  if (intent !== null) {
    const result = applyMark(s.atoms, key, upper, repeated, afterTone, intent)
    if (result === "applied") {
      s.markFrom = key
      return false
    }
    if (result === "undone") return true
  }
  s.atoms.push(atom(key, upper))
  return false
}

function applyMark(atoms, key, upper, repeated, afterTone, intent) {
  if (intent === "stroke") return applyStroke(atoms, key, upper)
  const cluster = vowelRange(atoms)
  if (cluster[0] === cluster[1]) return "none"
  const target = markTarget(atoms, cluster, afterTone, intent, key)
  if (target) {
    atoms[target.index].hat = target.hat
    atoms[target.index].markKey = key
    return "applied"
  }
  const marked = range(cluster).filter((i) => atoms[i].markKey === key)
  if (!repeated || marked.length === 0) return "none"
  if (intent === "circumflex" && cluster[1] !== atoms.length) return "none"
  for (const i of marked) {
    atoms[i].hat = "none"
    atoms[i].markKey = null
  }
  atoms.push(atom(key, upper))
  return "undone"
}

function applyStroke(atoms, key, upper) {
  const a = atoms[atoms.length - 1]
  if (!a || a.base !== "d") return "none"
  if (!a.stroke && a.markKey === null) {
    a.stroke = true
    a.markKey = key
    return "applied"
  }
  if (a.stroke && a.markKey === key) {
    a.stroke = false
    a.markKey = null
    atoms.push(atom(key, upper))
    return "undone"
  }
  return "none"
}

function markTarget(atoms, cluster, afterTone, intent, letter) {
  const indices = range(cluster)
  const open = indices.filter((i) => atoms[i].hat === "none" && atoms[i].markKey === null)
  const bases = indices.map((i) => atoms[i].base).join("")

  function hornTarget() {
    if (bases.startsWith("oa")) return null
    const j = indices.slice(1).find((i) => atoms[i].base === "o" && atoms[i - 1].base === "u")
    if (j !== undefined) return open.includes(j) ? j : null
    const first = open.find((i) => "uo".includes(atoms[i].base))
    return first === undefined ? null : first
  }

  if (intent === "hornOrBreve") {
    const horn = hornTarget()
    if (horn !== null) return { index: horn, hat: "horn" }
    const breve = open.find((i) => atoms[i].base === "a")
    return breve === undefined ? null : { index: breve, hat: "breve" }
  }
  // circumflex
  if (afterTone) return null
  const i = open.findLast((k) => atoms[k].base === letter)
  if (i === undefined) return null
  // A key that continues a real syllable stays a plain letter: `ngoeo` keeps its last o.
  if (i !== atoms.length - 1 && fitsShape([...atoms, atom(letter, false)], 0)) return null
  return { index: i, hat: "circumflex" }
}

/** A horn on either vowel of uo, uoi, uou means ươ. The open uo after an initial keeps its u: huơ, quơ, thuở. */
function normalizeHorn(atoms) {
  const cluster = vowelRange(atoms)
  const [lo, hi] = cluster
  if (hi - lo < 2 || atoms[lo].base !== "u" || atoms[lo + 1].base !== "o") return atoms
  const pair = [lo, lo + 1]
  if (!pair.some((i) => atoms[i].hat === "horn")) return atoms
  if (hi - lo === 2 && lo > 0 && hi === atoms.length) return atoms
  const out = atoms.map((a) => ({ ...a }))
  for (const i of pair) out[i].hat = "horn"
  return out
}

// MARK: - Spelling

const TONE_ON_SECOND = new Set(["oa", "oe", "uy", "oai", "oay", "uai", "uay", "uya", "uyu"])
const TONE_RANK = ["ơ", "ê", "ă", "â", "ô", "ư"]

const WITH_TONE = {
  a: ["a", "á", "à", "ả", "ã", "ạ"],
  ă: ["ă", "ắ", "ằ", "ẳ", "ẵ", "ặ"],
  â: ["â", "ấ", "ầ", "ẩ", "ẫ", "ậ"],
  e: ["e", "é", "è", "ẻ", "ẽ", "ẹ"],
  ê: ["ê", "ế", "ề", "ể", "ễ", "ệ"],
  i: ["i", "í", "ì", "ỉ", "ĩ", "ị"],
  o: ["o", "ó", "ò", "ỏ", "õ", "ọ"],
  ô: ["ô", "ố", "ồ", "ổ", "ỗ", "ộ"],
  ơ: ["ơ", "ớ", "ờ", "ở", "ỡ", "ợ"],
  u: ["u", "ú", "ù", "ủ", "ũ", "ụ"],
  ư: ["ư", "ứ", "ừ", "ử", "ữ", "ự"],
  y: ["y", "ý", "ỳ", "ỷ", "ỹ", "ỵ"],
}

function toneOffset(vowels) {
  const keys = vowels.map(nucleus)
  if (TONE_ON_SECOND.has(keys.join(""))) return 1
  for (const mark of TONE_RANK) {
    const index = keys.indexOf(mark)
    if (index !== -1) return index
  }
  return 0
}

function draw(a, tone) {
  if (a.stroke && a.base === "d") return a.upper ? "Đ" : "đ"
  const body = isVowel(a) && WITH_TONE[nucleus(a)] ? WITH_TONE[nucleus(a)][tone] : a.base
  return a.upper ? body.toUpperCase() : body
}

function compose(atoms, tone) {
  if (atoms.length === 0) return ""
  const [lo, hi] = vowelRange(atoms)
  const toneAt = lo === hi || tone === 0 ? null : lo + toneOffset(atoms.slice(lo, hi))
  return atoms.map((a, i) => draw(a, i === toneAt ? tone : 0)).join("")
}

// MARK: - Validity

const INITIALS = new Set([
  "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
  "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
])
const FINALS = new Set(["", "c", "ch", "m", "n", "ng", "nh", "p", "t"])
const NUCLEI = new Set([
  "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
  "ai", "ao", "au", "âu", "ay", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi", "ôi",
  "ơi", "ua", "uâ", "uê", "ui", "uô", "uơ", "ưa", "ưi", "ươ", "ưu", "uy", "yê", "oo",
  "iêu", "yêu", "oai", "oao", "oay", "oây", "oeo", "uai", "uay", "uây", "uêu", "uôi", "ươi", "ươu", "uya", "uyê", "uyu",
])
/** Vowels still waiting for their circumflex. They are valid only while no tone is set. */
const UNFINISHED_NUCLEI = new Set(["ie", "ye", "uo", "uoi", "uou", "uye", "ieu", "yeu"])

/** Initial + vowels + final, where a final c, ch, p or t takes only the sắc or nặng tone. */
function fitsShape(atoms, tone) {
  const [lo, hi] = vowelRange(atoms)
  const letters = (slice) => slice.map((a) => (a.stroke ? "đ" : a.base)).join("")
  if (!INITIALS.has(letters(atoms.slice(0, lo)))) return false
  if (lo === hi) return true
  const core = atoms.slice(lo, hi).map(nucleus).join("")
  if (!(NUCLEI.has(core) || (tone === 0 && UNFINISHED_NUCLEI.has(core)))) return false
  const final = letters(atoms.slice(hi))
  if (!FINALS.has(final)) return false
  if (["c", "ch", "p", "t"].includes(final)) return [0, 1, 5].includes(tone)
  return true
}

const isRealSyllable = (atoms, tone) => fitsShape(atoms, tone) && accepts(compose(atoms, 0).toLowerCase(), tone)

// MARK: - Engine

function telex(raw) {
  const s = { atoms: [], tone: 0, toneFrom: null, markFrom: null, escaped: null }
  let literal = ""
  for (const ch of raw) {
    const upper = ch !== ch.toLowerCase()
    const undidMark = consume(s, ch.toLowerCase(), upper)
    // The first press of an undone mark already sits in the literal text.
    if (!undidMark) literal += ch
  }
  const atoms = normalizeHorn(s.atoms)
  return { atoms, tone: s.tone, out: compose(atoms, s.tone), literal }
}

function isSyllable(atoms, tone, out) {
  return isRealSyllable(atoms, tone) || SHORTHAND.has(out.toLowerCase())
}

/** The text of a tone key typed twice, when the second press undoes the tone (`as` showed `á`, so `ass` is `as`). */
function toneUndo(raw, previous) {
  const word = raw.toLowerCase()
  const key = word.slice(-1)
  if (TELEX_TONE[key] !== undefined && word.endsWith(key.repeat(3)) && word.slice(0, -3).slice(-1) !== key) {
    return toneUndo(raw.slice(0, -1), previous) === null ? null : telex(raw).out
  }
  if (word.length < 2 || word.slice(-2, -1) !== key || TELEX_TONE[key] === undefined
      || band.has(word) || !band.has(word.slice(0, -1))) return null
  const prefix = raw.slice(0, -1)
  if (telex(prefix).tone !== TELEX_TONE[key] || analyze(prefix, previous).language !== VI) return null
  return telex(raw).out
}

/**
 * The text a word shows and the language it reveals. `language` is null when the word reads the same in both.
 * `differs` is true when Telex alone would have changed the keys.
 */
export function analyze(raw, previous = null, glued = false, restoreRaw = true) {
  const { atoms, tone, out, literal } = telex(raw)
  const differs = out !== literal
  const language = differs ? VI : null
  if (!restoreRaw) return { text: out, language, differs }
  if (glued) return { text: literal, language: EN, differs }
  const undone = toneUndo(raw, previous)
  if (undone !== null) return { text: undone, language: EN, differs }
  const word = raw.toLowerCase()
  const score = (band.get(word) ?? 0) + (previous === EN ? 1 : 0)
  if (score >= ENGLISH_THRESHOLD) return { text: literal, language: EN, differs }
  if (!isSyllable(atoms, tone, out)) return { text: literal, language: EN, differs }
  return { text: out, language, differs }
}

/** The other reading of the keys: the typed keys when the verdict shows the Telex text, and the reverse. */
function opposite(raw, verdict) {
  const { out, literal } = telex(raw)
  if (out === literal) return verdict
  return verdict.text === out ? { text: literal, language: EN, differs: true } : { text: out, language: VI, differs: true }
}

export const render = (raw, previous = null) => analyze(raw, previous).text

// MARK: - Session

const GLUE = new Set(["_", "@", "\\", "=", "|", "&", "$", "^", "~"])
const glues = (ch, afterVietnamese) => GLUE.has(ch) || (ch === "." && !afterVietnamese)
const isComposing = (ch) => /^[A-Za-z]$/.test(ch)

/** One word being typed, and what the words before it say about the next one. */
export class Session {
  constructor({ restoreRaw = true } = {}) {
    this.restoreRaw = restoreRaw
    this.raw = ""
    this.previous = null
    this.endsSentence = false
    this.boundary = null
    this.afterVietnamese = false
    this.glued = false
    this.swapped = false
  }

  get isComposing() {
    return this.raw !== ""
  }

  get endsInDigit() {
    return this.boundary !== null && /^[0-9]$/.test(this.boundary)
  }

  decide() {
    const verdict = analyze(this.raw, this.previous, this.glued || this.endsInDigit, this.restoreRaw)
    return this.swapped ? opposite(this.raw, verdict) : verdict
  }

  display() {
    return this.decide().text
  }

  /** "consumed": the key joined the word. "pass": nothing is composing. "commit": finish the word, then pass the key. */
  push(ch) {
    if (isComposing(ch)) {
      this.raw += ch
      this.swapped = false
      return "consumed"
    }
    const sentenceEnd = ".!?".includes(ch)
    if (this.raw === "") {
      if (sentenceEnd) this.previous = null
      this.glued = glues(ch, this.afterVietnamese)
      if (ch !== ".") this.afterVietnamese = false
      return "pass"
    }
    this.endsSentence = sentenceEnd
    this.boundary = ch
    return "commit"
  }

  /** Commits the word and remembers its language for the next one. */
  finish() {
    const verdict = this.decide()
    this.glued = this.boundary === null ? false : glues(this.boundary, verdict.language === VI)
    this.afterVietnamese = verdict.language === VI
    this.boundary = null
    if (this.endsSentence) this.previous = null
    else if (verdict.language) this.previous = verdict.language
    this.endsSentence = false
    this.raw = ""
    this.swapped = false
    return verdict
  }

  /** The typed keys as they are. The word counts as English from here on. */
  finishRaw() {
    const text = this.raw
    const differs = telex(text).out !== text
    this.raw = ""
    this.swapped = false
    this.previous = EN
    this.endsSentence = false
    this.glued = false
    this.afterVietnamese = false
    this.boundary = null
    return { text, language: EN, differs }
  }

  pop() {
    if (this.raw === "") return false
    this.raw = this.raw.slice(0, -1)
    this.swapped = false
    return true
  }

  /** Shows the other reading of the word being typed. Returns the language now shown, or null when there is none. */
  swap() {
    if (this.raw === "") return null
    const before = this.display()
    this.swapped = !this.swapped
    if (this.display() === before) {
      this.swapped = !this.swapped
      return null
    }
    return this.decide().language
  }

  forgetContext() {
    this.previous = null
    this.glued = false
    this.afterVietnamese = false
  }
}
