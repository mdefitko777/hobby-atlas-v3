// 옛 Gunpula app/collection-store.js 로 시험 값을 만든다 → test/fixtures/collection_store_js_vectors.json
// lib/sync/collection_merge.dart 가 JS 와 한 글자도 다르지 않은지 test/collection_merge_js_test.dart 가 비교한다.
// 다시 만들기 (Gunpula 저장소의 파일을 복사해 와서):
//   git -C <Gunpula> show origin/main:app/collection-store.js > /tmp/collection-store.mjs
//   node tool/gen_collection_vectors.mjs /tmp/collection-store.mjs test/fixtures/collection_store_js_vectors.json
import { writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
const { normalizeCollection, mergeCollectionState, mergeTimestampedMap } = await import(pathToFileURL(process.argv[2]).href);
let seed = 42;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const pick = (a) => a[Math.floor(rnd() * a.length)];
const members = ["me", "member", "ttungyimu", "ttungyimungyi", "냐아", "동생", " me ", "other"];
const kits = ["k1", "k2", "k3", "k4", "k5"];
const statuses = ["owned", "wanted", "deleted", "bogus", undefined];
const times = ["2026-01-01T00:00:00Z", "2026-01-02T00:00:00Z", "2026-01-02T00:00:00.000Z", "2025-12-31T23:59:59Z", "2026-03-01T10:00:00+09:00"];
const qty = [1, 2, "3", "0", 150, "abc", undefined, 2.7];
const price = [undefined, 1000, "12,000", "₩5,500.5", "", "abc", 0];
function entry() {
  const e = { status: pick(statuses), updated_at: pick(times) };
  const q = pick(qty); if (q !== undefined) e.quantity = q;
  const p = pick(price); if (p !== undefined) e.purchase_price = p;
  if (rnd() < 0.3) e.note = pick(["메모", "", "box"]);
  if (rnd() < 0.3) e.storage = pick(["선반", ""]);
  if (rnd() < 0.5) e.updated_by = pick(["me", "동생", ""]);
  return e;
}
function collection() {
  const c = { member_items: {} };
  const n = Math.floor(rnd() * 4);
  for (let i = 0; i < n; i++) {
    const m = pick(members); c.member_items[m] ||= {};
    for (let j = 0; j < 3; j++) c.member_items[m][pick(kits)] = entry();
  }
  if (n === 0 && rnd() < 0.7) { c.items = {}; for (let j = 0; j < 3; j++) c.items[pick(kits)] = entry(); }
  return c;
}
const cases = [];
for (let i = 0; i < 60; i++) {
  const self = pick(["me", "member", "동생"]);
  const options = { statuses: ["owned", "wanted", "deleted"], self, droppedMembers: new Set(["냐아"]),
    memberMerges: self === "member" ? {} : Object.fromEntries(["member", "ttungyimungyi", "ttungyimu"].map((a) => [a, self])) };
  const local = collection(), remote = collection();
  const ol = { a: { v: 1, updated_at: pick(times) }, b: { v: 2, hidden_at: pick(times) } };
  const or = { a: { v: 3, updated_at: pick(times) }, c: { v: 4, reviewed_at: pick(times) } };
  cases.push({ self, local, remote, ol, or,
    norm: normalizeCollection(structuredClone(local), options),
    merged: mergeCollectionState(structuredClone(local), structuredClone(remote), options),
    mtm: mergeTimestampedMap(ol, or) });
}
writeFileSync(process.argv[3], JSON.stringify(cases));
console.log("cases", cases.length);
