#!/usr/bin/env bun
// Reads `raw<TAB>output` lines on stdin and asks Jev (typesafe-ai/jev) whether each typed word
// is an everyday English word the user meant literally. Prints the likely English words the
// engine converted, most confident first. Candidates for Core/English.swift, not verdicts.
// Needs AI_GATEWAY_API_KEY in the environment.

const BATCH = 100;
const THRESHOLD = Number(process.env.THRESHOLD ?? 0.8);

if (!process.env.AI_GATEWAY_API_KEY) {
  console.error("AI_GATEWAY_API_KEY is not set");
  process.exit(1);
}

const { experimental_evaluate: evaluate } = await import("ai");

const pairs = (await Bun.stdin.text())
  .split("\n")
  .filter(Boolean)
  .map((line) => line.split("\t"));

const scored = [];
for (let start = 0; start < pairs.length; start += BATCH) {
  const batch = pairs.slice(start, start + BATCH);
  const state = batch.map(([raw, out]) => `${raw} -> ${out}`).join("\n");
  const questions = Object.fromEntries(
    batch.map(([raw, out], i) => [
      `q${i}`,
      {
        type: "boolean",
        instructions: `A bilingual Vietnamese typist typed the keys "${raw}" with Telex, and the keyboard turned them into "${out}". Is "${raw}" an everyday English word that the typist most likely meant literally?`,
      },
    ]),
  );
  const result = await evaluate({ model: "typesafe-ai/jev", state, questions });
  batch.forEach(([raw, out], i) => scored.push({ raw, out, prob: result.answers[`q${i}`].probability }));
}

const hits = scored.filter((s) => s.prob > THRESHOLD).sort((a, b) => b.prob - a.prob);
for (const { raw, out, prob } of hits) console.log(`${prob.toFixed(2)}\t${raw}\t${out}`);
console.error(`${hits.length} of ${scored.length} converted words look like English (threshold ${THRESHOLD})`);
