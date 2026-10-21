// Uji paritas: bandingkan respons Express (MySQL) dengan FastAPI (MongoDB) untuk endpoint katalog.
// Jalankan: FASTAPI_URL=http://localhost:8001 EXPRESS_URL=http://localhost:8099 node --test test/
const test = require("node:test");
const assert = require("node:assert");

const A = process.env.FASTAPI_URL;
const B = process.env.EXPRESS_URL;
const get = async (base, p) => {
  const r = await fetch(`${base}/api${p}`);
  return { status: r.status, body: await r.json() };
};
// created_at beda format; rating dibulatkan 2 desimal di MySQL; rating_source "demo" diisi eksportir bila kosong.
const norm = (p) => {
  const { created_at, rating_source, ...rest } = p;
  if (typeof rest.rating === "number") rest.rating = Math.round(rest.rating * 100) / 100;
  return rest;
};
const bySlug = (arr) => Object.fromEntries(arr.map((p) => [p.slug, norm(p)]));

test("categories sama", async () => {
  assert.deepStrictEqual((await get(B, "/categories")).body, (await get(A, "/categories")).body);
});

for (const q of ["", "?category=Wedding", "?search=studio", "?sort=harga-rendah", "?min_price=500000&max_price=1000000"]) {
  test(`photographers${q} sama`, async () => {
    const [a, b] = [await get(A, `/photographers${q}`), await get(B, `/photographers${q}`)];
    assert.deepStrictEqual(bySlug(b.body), bySlug(a.body));
  });
}

test("urutan harga-rendah sama", async () => {
  const [a, b] = [await get(A, "/photographers?sort=harga-rendah"), await get(B, "/photographers?sort=harga-rendah")];
  assert.deepStrictEqual(b.body.map((p) => p.starting_price), a.body.map((p) => p.starting_price));
});

test("featured sama", async () => {
  const [a, b] = [await get(A, "/photographers/featured"), await get(B, "/photographers/featured")];
  assert.deepStrictEqual(b.body.map((p) => p.slug).sort(), a.body.map((p) => p.slug).sort());
});

test("detail profil + portofolio sama", async () => {
  const list = (await get(A, "/photographers")).body;
  for (const p of list) {
    const [a, b] = [await get(A, `/photographers/${p.slug}`), await get(B, `/photographers/${p.slug}`)];
    assert.deepStrictEqual(norm(b.body), norm(a.body), p.slug);
  }
});

test("404 profil tidak ada", async () => {
  const b = await get(B, "/photographers/tidak-ada-xyz");
  assert.strictEqual(b.status, 404);
  assert.strictEqual(b.body.detail, "Fotografer tidak ditemukan");
});

test("services sama", async () => {
  const [a, b] = [await get(A, "/services"), await get(B, "/services")];
  const key = (s) => s.service_id;
  assert.deepStrictEqual([...b.body].sort((x, y) => key(x).localeCompare(key(y))), [...a.body].sort((x, y) => key(x).localeCompare(key(y))));
});
