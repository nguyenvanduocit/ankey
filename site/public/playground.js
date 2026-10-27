// The demo on the home page. The keys typed are a list of operations; each render replays the list through two
// sessions of the engine, one as plain Telex and one as Ankey, so what is on screen is always a pure function of the keys.
import { Session } from "./engine.js"

const REDUCED_MOTION = matchMedia("(prefers-reduced-motion: reduce)").matches
const KEY_DELAY_MS = 85
const KEYS_SHOWN = 16

/** What the page shows for a word: Vietnamese when Telex changed it and the verdict kept the change, kept English when it undid it. */
function kindOf(verdict) {
  if (!verdict.differs) return "plain"
  return verdict.language === "vietnamese" ? "vi" : "kept"
}

/** Replays the operations: `{ keys: string }` types characters, `esc` and `swap` act on the word being typed. */
function replay(ops, restoreRaw) {
  const session = new Session({ restoreRaw })
  const tokens = []
  const word = (verdict) => tokens.push({ text: verdict.text, kind: kindOf(verdict) })
  for (const op of ops) {
    if (op.type === "swap") session.swap()
    else if (op.type === "esc") word(session.finishRaw())
    else {
      const push = session.push(op.ch)
      if (push === "commit") word(session.finish())
      if (push !== "consumed") tokens.push({ text: op.ch, kind: "sep" })
    }
  }
  const composing = session.isComposing ? { text: session.display(), kind: kindOf(session.decide()) } : null
  return { tokens, composing }
}

function renderPane(el, { tokens, composing }, other, focused) {
  el.replaceChildren()
  const add = (text, kind, extra) => {
    if (text === "\n") return el.append(document.createElement("br"))
    const span = document.createElement("span")
    span.textContent = text
    if (kind !== "sep" && kind !== "plain") span.className = kind
    if (extra) span.classList.add(extra)
    el.append(span)
  }
  tokens.forEach((token, i) => {
    const differs = other && token.kind !== "sep" && other.tokens[i]?.text !== token.text
    add(token.text, differs ? "wrong" : token.kind)
  })
  if (composing) {
    const differs = other && other.composing?.text !== composing.text
    add(composing.text, differs ? "wrong" : composing.kind, "composing")
  }
  if (focused || composing || tokens.length) {
    const caret = document.createElement("span")
    caret.className = "caret"
    caret.setAttribute("aria-hidden", "true")
    el.append(caret)
  } else {
    el.innerHTML = '<span class="empty">Gõ thử: tieengs vieetj</span>'
  }
}

function keycap(op) {
  const kbd = document.createElement("kbd")
  if (op.type === "esc") kbd.textContent = "esc"
  else if (op.type === "swap") kbd.textContent = "⇧esc"
  else kbd.textContent = op.ch === " " ? "space" : op.ch === "\n" ? "return" : op.ch
  if (kbd.textContent.length > 1) kbd.classList.add("wide")
  return kbd
}

function initStage(stage) {
  const keysRow = stage.querySelector("[data-keys]")
  const plainOut = stage.querySelector('[data-out="plain"]')
  const ankeyOut = stage.querySelector('[data-out="ankey"]')
  let ops = []
  let timer = null

  const stopPlaying = () => {
    clearTimeout(timer)
    timer = null
  }

  function render() {
    const ankey = replay(ops, true)
    const plain = replay(ops, false)
    const focused = document.activeElement === stage
    renderPane(ankeyOut, ankey, null, focused)
    renderPane(plainOut, plain, ankey, focused)
    keysRow.replaceChildren(...ops.slice(-KEYS_SHOWN).map(keycap))
    return ankey.composing !== null
  }

  function type(text) {
    stopPlaying()
    ops = []
    const chars = [...text]
    if (REDUCED_MOTION) {
      ops = chars.map((ch) => ({ type: "key", ch }))
      render()
      return
    }
    const step = () => {
      if (chars.length === 0) return stopPlaying()
      ops.push({ type: "key", ch: chars.shift() })
      render()
      timer = setTimeout(step, KEY_DELAY_MS)
    }
    step()
  }

  stage.addEventListener("keydown", (event) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    let handled = true
    if (event.key === "Backspace") {
      stopPlaying()
      ops.pop()
    } else if (event.key === "Escape") {
      stopPlaying()
      if (!render()) return
      ops.push({ type: event.shiftKey ? "swap" : "esc" })
    } else if (event.key === "Enter") {
      stopPlaying()
      ops.push({ type: "key", ch: "\n" })
    } else if (event.key.length === 1) {
      stopPlaying()
      ops.push({ type: "key", ch: event.key })
    } else {
      handled = false
    }
    if (!handled) return
    event.preventDefault()
    render()
  })
  stage.addEventListener("focus", render)
  stage.addEventListener("blur", render)
  stage.addEventListener("pointerdown", () => stage.focus())

  for (const button of stage.querySelectorAll("[data-preset]")) {
    button.addEventListener("click", () => type(button.dataset.preset))
  }
  stage.querySelector("[data-clear]").addEventListener("click", () => {
    stopPlaying()
    ops = []
    render()
  })

  render()
  // The opening example is the one where the two panes disagree.
  setTimeout(() => type(stage.querySelector("[data-autoplay]").dataset.preset), 500)
}

/** Fills the table from the engine, so its columns cannot disagree with what the demo does. */
function initLedger(table) {
  const read = (keys, restoreRaw) => {
    const result = replay([...keys].map((ch) => ({ type: "key", ch })), restoreRaw)
    return [...result.tokens, ...(result.composing ? [result.composing] : [])]
  }
  for (const row of table.querySelectorAll("tr[data-keys]")) {
    const keys = row.dataset.keys
    const plain = read(keys, false)
    const ankey = read(keys, true)
    const cells = row.querySelectorAll("td")
    cells[0].textContent = keys
    const fill = (cell, tokens, other) => {
      tokens.forEach((token, i) => {
        const span = document.createElement("span")
        span.textContent = token.text
        const differs = other && token.kind !== "sep" && other[i]?.text !== token.text
        if (differs) span.className = "wrong"
        else if (token.kind === "vi" || token.kind === "kept") span.className = token.kind
        cell.append(span)
      })
    }
    fill(cells[1], plain, ankey)
    fill(cells[2], ankey, null)
  }
}

function initCopy() {
  for (const button of document.querySelectorAll("[data-copy]")) {
    const label = button.textContent
    button.addEventListener("click", async () => {
      const text = document.querySelector(button.dataset.copy).textContent
      try {
        await navigator.clipboard.writeText(text)
        button.textContent = "Đã sao chép lệnh cài"
      } catch {
        const range = document.createRange()
        range.selectNodeContents(document.querySelector(button.dataset.copy))
        getSelection().removeAllRanges()
        getSelection().addRange(range)
        button.textContent = "Chọn lệnh rồi bấm Cmd+C"
      }
      setTimeout(() => (button.textContent = label), 2200)
    })
  }
}

async function initVersion(el) {
  try {
    const response = await fetch("https://api.github.com/repos/nguyenvanduocit/ankey/releases/latest")
    if (!response.ok) return
    const { tag_name: tag } = await response.json()
    if (!/^v\d+(\.\d+)*$/.test(tag)) return
    el.textContent = `Bản mới nhất là ${tag}.`
    for (const shown of document.querySelectorAll("[data-ver]")) shown.textContent = tag.slice(1)
  } catch {
    // The static sentence stays.
  }
}

initStage(document.querySelector("[data-stage]"))
initLedger(document.querySelector("[data-ledger]"))
initCopy()
initVersion(document.querySelector("[data-version]"))
