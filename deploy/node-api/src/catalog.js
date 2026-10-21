const express = require("express");
const { query } = require("./db");

const CATEGORIES = ["Wedding", "Commercial", "Event", "Graduation"];
const VISIBLE = "p.listing_status NOT IN ('pending','rejected')";
const router = express.Router();

const isoDate = (v) => (v ? `${v.replace(" ", "T")}+00:00` : v);

async function hydrate(rows) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.photographer_id);
  const [services, gallery] = await Promise.all([
    query("SELECT * FROM services WHERE photographer_id IN (?) AND is_deleted = 0 ORDER BY service_id", [ids]),
    query("SELECT * FROM photographer_gallery WHERE photographer_id IN (?) ORDER BY position", [ids]),
  ]);
  return rows.map((p) => ({
    photographer_id: p.photographer_id,
    slug: p.slug,
    name: p.name,
    username: p.username,
    category: p.category,
    location: p.location,
    bio: p.bio,
    profile_image: p.profile_image,
    gallery: gallery.filter((g) => g.photographer_id === p.photographer_id).map((g) => g.url),
    availability: p.availability_note,
    service_area: p.service_area,
    min_duration: p.min_duration,
    starting_price: p.starting_price,
    listing_status: p.listing_status,
    verified: !!p.verified,
    verification: { status: p.verification_status, ...(p.verification_note ? { note: p.verification_note } : {}) },
    rating: p.rating === null ? null : Number(p.rating),
    reviews: p.reviews,
    rating_source: p.rating_source,
    demo: !!p.is_demo,
    created_at: isoDate(p.created_at),
    services: services.filter((s) => s.photographer_id === p.photographer_id).map((s) => ({
      service_id: s.service_id, title: s.title, category: s.category, price: s.price,
      pricing_type: s.pricing_type, duration: s.duration, deliverables: s.deliverables, turnaround: s.turnaround,
    })),
  }));
}

router.get("/", (req, res) => res.json({ message: "Jasakamerata API aktif", categories: CATEGORIES }));

router.get("/categories", (req, res) => res.json(CATEGORIES.map((c) => ({ name: c, slug: c.toLowerCase() }))));

router.get("/photographers", async (req, res) => {
  const { category, search, sort = "relevan" } = req.query;
  const min = Number(req.query.min_price || 0);
  const max = Number(req.query.max_price || 100000000);
  const where = [VISIBLE, "p.starting_price BETWEEN ? AND ?"];
  const params = [min, max];
  if (CATEGORIES.includes(category)) { where.push("p.category = ?"); params.push(category); }
  if (search) { where.push("(p.name LIKE ? OR p.category LIKE ?)"); params.push(`%${search}%`, `%${search}%`); }
  const order = sort === "harga-rendah" ? "p.starting_price ASC" : sort === "rating" ? "COALESCE(p.rating,0) DESC" : "p.created_at ASC";
  const rows = await query(`SELECT p.* FROM photographers p WHERE ${where.join(" AND ")} ORDER BY ${order} LIMIT 200`, params);
  res.json(await hydrate(rows));
});

router.get("/photographers/featured", async (req, res) => {
  const out = [];
  for (const c of CATEGORIES) {
    const rows = await query(
      `SELECT p.* FROM photographers p WHERE ${VISIBLE} AND p.category = ? AND p.starting_price > 0
       AND EXISTS (SELECT 1 FROM photographer_gallery g WHERE g.photographer_id = p.photographer_id)
       ORDER BY p.verified DESC, p.rating DESC LIMIT 2`, [c]);
    out.push(...(await hydrate(rows)));
  }
  res.json(out);
});

router.get("/photographers/:slug", async (req, res) => {
  const rows = await query(`SELECT p.* FROM photographers p WHERE p.slug = ? AND ${VISIBLE}`, [req.params.slug]);
  if (!rows.length) return res.status(404).json({ detail: "Fotografer tidak ditemukan" });
  const [doc] = await hydrate(rows);
  doc.portfolio = await query(
    "SELECT item_id, url, title, description FROM portfolio_items WHERE photographer_id = ? AND is_deleted = 0 ORDER BY is_cover DESC, sort_order ASC LIMIT 100",
    [doc.photographer_id]);
  res.json(doc);
});

router.get("/photographers/:slug/reviews", async (req, res) => {
  const rows = await query(`SELECT p.photographer_id FROM photographers p WHERE p.slug = ? AND ${VISIBLE}`, [req.params.slug]);
  if (!rows.length) return res.status(404).json({ detail: "Fotografer tidak ditemukan" });
  const reviews = await query(
    "SELECT review_id, photographer_id, customer_name, service_title AS service, rating, comment, created_at FROM reviews WHERE photographer_id = ? ORDER BY created_at DESC LIMIT 50",
    [rows[0].photographer_id]);
  res.json(reviews.map((r) => ({ ...r, created_at: isoDate(r.created_at) })));
});

router.get("/services", async (req, res) => {
  const ph = await hydrate(await query(`SELECT p.* FROM photographers p WHERE ${VISIBLE} LIMIT 200`));
  const out = [];
  for (const p of ph) for (const s of p.services) {
    if (!req.query.category || s.category === req.query.category) {
      out.push({ ...s, photographer_name: p.name, photographer_slug: p.slug, image: p.gallery[0] || "", verified: p.verified });
    }
  }
  res.json(out);
});

module.exports = router;
