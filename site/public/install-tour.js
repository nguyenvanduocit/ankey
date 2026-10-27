// The install walkthrough: four scenes played on one clock. A scene is a list of timed steps, so changing a scene
// means editing its list. The clock only runs while the tour is on screen and not paused.
import { Session } from "./engine.js"

const HOLD_MS = 1800
const START = { x: 0.82, y: 0.8 }

/** [at ms, action, target id, argument]. `type` and `keys` take their text from the target's data attribute and run for the duration. */
const SCENES = [
  {
    length: 5600,
    steps: [
      [300, "type", "t-cmd", 2200],
      [2900, "on", "t-l1"],
      [3500, "on", "t-l2"],
      [4200, "on", "t-l3"],
    ],
  },
  {
    length: 5200,
    steps: [
      [300, "move", "l-apple"],
      [1100, "click", "l-apple"],
      [1150, "on", "l-menu"],
      [1700, "move", "l-logout"],
      [2400, "on", "l-logout"],
      [2700, "click", "l-logout"],
      [2900, "on", "l-login"],
      [3300, "type", "l-pass", 1300],
    ],
  },
  {
    length: 8000,
    steps: [
      [300, "move", "s-edit"],
      [1000, "click", "s-edit"],
      [1050, "on", "s-edit"],
      [1250, "on", "s-sheet"],
      [1700, "move", "s-plus"],
      [2400, "click", "s-plus"],
      [2450, "on", "s-plus"],
      [2650, "on", "s-picker"],
      [3200, "move", "s-vn"],
      [3800, "click", "s-vn"],
      [3850, "on", "s-vn"],
      [3850, "on", "s-srcs"],
      [4300, "move", "s-ankey"],
      [4900, "click", "s-ankey"],
      [4950, "on", "s-ankey"],
      [5400, "move", "s-add"],
      [6000, "click", "s-add"],
      [6200, "off", "s-picker"],
      [6200, "off", "s-plus"],
      [6200, "on", "s-row"],
    ],
  },
  {
    length: 7600,
    steps: [
      [300, "move", "m-label"],
      [900, "click", "m-label"],
      [950, "on", "m-menu"],
      [1500, "move", "m-ankey"],
      [2000, "on", "m-ankey"],
      [2300, "click", "m-ankey"],
      [2500, "on", "m-label"],
      [2500, "off", "m-menu"],
      [2900, "move", "m-field"],
      [3500, "keys", "m-text", 3600],
    ],
  },
]

const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches
const tour = document.querySelector("[data-tour]")
const screen = tour.querySelector("[data-screen]")
const pointer = tour.querySelector("[data-pointer]")
const sceneEls = [...screen.querySelectorAll("[data-scene]")]
const stepButtons = [...tour.querySelectorAll("[data-step]")]
const pauseButton = tour.querySelector("[data-tour-pause]")
const $ = (id) => screen.querySelector(`#${id}`)

let scene = 0
let t = 0
let next = 0
let typers = []
let playing = !reducedMotion
let onScreen = false
let last = 0
let frame = 0

/** What the engine shows for the keys typed so far: finished words as text, the word in progress underlined. */
function keysHtml(keys) {
  const session = new Session()
  let done = ""
  for (const ch of keys) {
    const push = session.push(ch)
    if (push === "commit") done += session.finish().text
    if (push !== "consumed") done += ch
  }
  const composing = session.isComposing ? `<span class="composing">${session.display()}</span>` : ""
  return done + composing
}

function paintTyper({ el, text, mode }, fraction) {
  const count = Math.ceil(text.length * fraction)
  if (mode === "keys") el.innerHTML = keysHtml(text.slice(0, count))
  else el.textContent = text.slice(0, count)
}

function movePointer(id) {
  const target = $(id).getBoundingClientRect()
  const box = screen.getBoundingClientRect()
  place(target.left - box.left + target.width * 0.6, target.top - box.top + target.height * 0.55)
}

function place(x, y) {
  pointer.style.translate = `${x}px ${y}px`
}

function clickPointer() {
  pointer.classList.add("press")
  setTimeout(() => pointer.classList.remove("press"), 220)
}

function run([, action, id, duration], { instant }) {
  const el = $(id)
  if (action === "on") el.classList.add("on")
  else if (action === "off") el.classList.remove("on")
  else if (action === "move" && !instant) movePointer(id)
  else if (action === "click" && !instant) clickPointer()
  else if (action === "type" || action === "keys") {
    const typer = { el, text: el.dataset[action === "keys" ? "keys" : "type"], mode: action, start: t, duration }
    if (instant) paintTyper(typer, 1)
    else typers.push(typer)
  }
}

function resetScene(el) {
  for (const on of el.querySelectorAll(".on")) on.classList.remove("on")
  for (const typed of el.querySelectorAll("[data-type], [data-keys]")) typed.textContent = ""
}

function showScene(index, { final = false } = {}) {
  scene = index
  t = 0
  next = 0
  typers = []
  sceneEls.forEach((el, i) => {
    el.classList.toggle("active", i === index)
    resetScene(el)
  })
  stepButtons.forEach((button, i) => {
    if (i === index) button.setAttribute("aria-current", "step")
    else button.removeAttribute("aria-current")
  })
  const box = screen.getBoundingClientRect()
  pointer.classList.add("jump")
  place(box.width * START.x, box.height * START.y)
  pointer.getBoundingClientRect()
  pointer.classList.remove("jump")
  pointer.classList.toggle("hidden", final || !SCENES[index].steps.some((step) => step[1] === "move"))
  if (final) {
    for (const step of SCENES[index].steps) run(step, { instant: true })
    next = SCENES[index].steps.length
  }
  paintBars(final ? 1 : 0)
}

function paintBars(progress) {
  stepButtons.forEach((button, i) => {
    const fill = i < scene ? 1 : i === scene ? progress : 0
    button.querySelector(".tour-bar").style.setProperty("--fill", String(fill))
  })
}

function tick(now) {
  frame = requestAnimationFrame(tick)
  t += Math.min(now - last, 100)
  last = now
  const { steps, length } = SCENES[scene]
  while (next < steps.length && steps[next][0] <= t) run(steps[next++], { instant: false })
  typers = typers.filter((typer) => {
    const fraction = Math.min(1, (t - typer.start) / typer.duration)
    paintTyper(typer, fraction)
    return fraction < 1
  })
  paintBars(Math.min(1, t / (length + HOLD_MS)))
  if (t >= length + HOLD_MS) showScene((scene + 1) % SCENES.length)
}

function sync() {
  cancelAnimationFrame(frame)
  if (!(playing && onScreen)) return
  last = performance.now()
  frame = requestAnimationFrame(tick)
}

function setPlaying(value) {
  playing = value
  pauseButton.setAttribute("aria-pressed", String(!value))
  pauseButton.textContent = value ? "Tạm dừng" : "Phát lại"
  // Paused tours show the end of the scene, so the page can be read without waiting for the clock.
  if (value) showScene(scene)
  else showScene(scene, { final: true })
  sync()
}

stepButtons.forEach((button, i) =>
  button.addEventListener("click", () => showScene(i, { final: !playing })),
)
pauseButton.addEventListener("click", () => setPlaying(!playing))
new IntersectionObserver(([entry]) => {
  onScreen = entry.isIntersecting
  sync()
}, { threshold: 0.4 }).observe(screen)

if (reducedMotion) {
  pauseButton.hidden = true
  showScene(0, { final: true })
} else {
  showScene(0)
}
