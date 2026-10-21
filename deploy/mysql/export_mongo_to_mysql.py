"""Ekspor data MongoDB Jasakamerata ke file SQL INSERT untuk MySQL/MariaDB (tidak mengubah MongoDB).

Pemakaian (dari folder /app/backend):
  python ../deploy/mysql/export_mongo_to_mysql.py                 # hanya data asli (tanpa DEMO/uji)
  python ../deploy/mysql/export_mongo_to_mysql.py --include-demo  # termasuk data DEMO/uji (untuk pengujian saja)
Hasil: deploy/mysql/data_export.sql — impor SETELAH schema.sql melalui phpMyAdmin.
"""
import asyncio
import os
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
from dotenv import load_dotenv  # noqa: E402

load_dotenv(Path(__file__).resolve().parents[2] / "backend" / ".env")
from motor.motor_asyncio import AsyncIOMotorClient  # noqa: E402

INCLUDE_DEMO = "--include-demo" in sys.argv
OUT = Path(__file__).with_name("data_export.sql")


def q(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"


def dt(v):
    if not v:
        return None
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    return datetime.fromisoformat(str(v)).strftime("%Y-%m-%d %H:%M:%S")


class Writer:
    def __init__(self):
        self.lines, self.counts = [], {}

    def row(self, table, data):
        cols = ", ".join(data)
        vals = ", ".join(q(v) for v in data.values())
        self.lines.append(f"INSERT IGNORE INTO {table} ({cols}) VALUES ({vals});")
        self.counts[table] = self.counts.get(table, 0) + 1


async def main():
    db = AsyncIOMotorClient(os.environ["MONGO_URL"])[os.environ["DB_NAME"]]
    w = Writer()
    is_test_user = lambda u: u["user_id"].startswith("test_") or u["email"].lower().endswith("@example.com")  # noqa: E731
    skipped = []
    demo_ph = {p["photographer_id"] async for p in db.photographers.find({"demo": True}, {"photographer_id": 1})}
    users = {}
    async for u in db.users.find({}, {"_id": 0}):
        if not INCLUDE_DEMO and is_test_user(u):
            continue
        if any(x["email"].lower() == u["email"].lower() for x in users.values()):
            skipped.append(f"users: {u['user_id']} (email duplikat)")
            continue
        users[u["user_id"]] = u
    phs = {}
    async for p in db.photographers.find({}, {"_id": 0}):
        if not INCLUDE_DEMO and (p["photographer_id"] in demo_ph or (p.get("user_id") and p["user_id"] not in users)):
            continue
        phs[p["photographer_id"]] = p
    for u in users.values():
        b = u.get("bank") or {}
        w.row("users", {"user_id": u["user_id"], "email": u["email"], "name": u.get("name", ""), "picture": u.get("picture"), "role": u.get("role") or "customer",
                        "photographer_id": u.get("photographer_id") if u.get("photographer_id") in phs else None, "bank_name": b.get("bank_name"), "bank_holder_name": b.get("holder_name"),
                        "bank_number_encrypted": b.get("number_encrypted") or u.get("bank_account_encrypted"), "bank_masked": b.get("masked") or u.get("bank_account_masked"),
                        "bank_updated_at": dt(b.get("updated_at")), "photographer_policy_agreed_at": dt(u.get("photographer_policy_agreed_at")), "created_at": dt(u.get("created_at")) or dt(datetime.now())})
    for p in phs.values():
        v = p.get("verification") or {}
        w.row("photographers", {"photographer_id": p["photographer_id"], "user_id": p.get("user_id") if p.get("user_id") in users else None, "slug": p["slug"], "name": p["name"], "username": p.get("username"),
                                "category": p["category"], "location": p.get("location", ""), "bio": p.get("bio"), "profile_image": p.get("profile_image"), "service_area": p.get("service_area"), "availability_note": p.get("availability"),
                                "min_duration": p.get("min_duration", 2), "starting_price": p.get("starting_price", 0), "listing_status": p.get("listing_status", "pending"), "listing_note": p.get("listing_note"),
                                "verified": bool(p.get("verified")), "verification_status": v.get("status", "not_submitted"), "verification_note": v.get("note"), "rating": p.get("rating"),
                                "reviews": p.get("reviews", 0), "rating_source": p.get("rating_source") or ("demo" if p.get("demo") else None), "is_demo": bool(p.get("demo")), "created_at": dt(p.get("created_at")) or dt(datetime.now())})
        for i, url in enumerate(p.get("gallery", [])):
            w.row("photographer_gallery", {"photographer_id": p["photographer_id"], "position": i, "url": url})
        for s in p.get("services", []):
            w.row("services", {"service_id": s["service_id"], "photographer_id": p["photographer_id"], "title": s["title"], "category": s.get("category", p["category"]), "price": s["price"],
                               "pricing_type": s.get("pricing_type", "per paket"), "duration": s["duration"], "deliverables": s["deliverables"], "turnaround": s.get("turnaround", "7 hari kerja")})
    async for it in db.portfolio_items.find({"photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("portfolio_items", {"item_id": it["item_id"], "photographer_id": it["photographer_id"], "url": it["url"], "storage_path": it.get("storage_path"), "content_type": it.get("content_type"),
                                  "size_bytes": it.get("size"), "title": it.get("title", ""), "description": it.get("description", ""), "sort_order": it.get("order", 0), "is_cover": bool(it.get("is_cover")),
                                  "is_deleted": bool(it.get("is_deleted")), "created_at": dt(it.get("created_at")), "deleted_at": dt(it.get("deleted_at"))})
    async for b in db.availability_blocks.find({"photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("availability_blocks", {"block_id": b["block_id"], "photographer_id": b["photographer_id"], "block_date": b["date"], "start_time": b["start"], "end_time": b["end"], "reason": b.get("reason", ""), "created_at": dt(b.get("created_at"))})
    bookings = set()
    async for b in db.bookings.find({"customer_id": {"$in": list(users)}, "photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        bookings.add(b["booking_id"])
        w.row("bookings", {"booking_id": b["booking_id"], "customer_id": b["customer_id"], "customer_name": b.get("customer_name", ""), "photographer_id": b["photographer_id"], "photographer_name": b["photographer_name"],
                           "photographer_slug": b["photographer_slug"], "service_id": b["service_id"], "service_title": b["service"], "category": b["category"], "session_date": b["date"], "start_time": b["time"],
                           "duration_hours": b["duration"], "location": b["location"], "notes": b.get("notes"), "total": b["total"], "commission_rate": b.get("commission_rate", 0.05), "commission": b["commission"],
                           "photographer_earning": b["photographer_earning"], "status": b["status"], "payment_status": b.get("payment_status", "demo_deferred"), "payment_due_at": dt(b.get("payment_due_at")),
                           "payment_order_id": b.get("payment_order_id"), "paid_at": dt(b.get("paid_at")), "policy_version": b.get("policy_version"), "policy_agreed_at": dt(b.get("policy_agreed_at")),
                           "created_at": dt(b.get("created_at")), "updated_at": dt(b.get("updated_at"))})
        for h in b.get("history", []):
            w.row("booking_history", {"booking_id": b["booking_id"], "status": h["status"], "actor": h["by"], "note": h.get("note", "")[:500], "created_at": dt(h["at"])})
    async for d in db.deliveries.find({"booking_id": {"$in": list(bookings)}}, {"_id": 0}):
        w.row("deliveries", {"delivery_id": d["delivery_id"], "booking_id": d["booking_id"], "note": d.get("note"), "link": d.get("link"), "created_at": dt(d["created_at"])})
        for f in d.get("files", []):
            w.row("delivery_files", {"file_id": f["file_id"], "delivery_id": d["delivery_id"], "storage_path": f["storage_path"], "content_type": f["content_type"], "size_bytes": f["size"], "original_filename": f.get("original_filename", "")})
    async for r in db.reviews.find({"booking_id": {"$in": list(bookings)}}, {"_id": 0}):
        w.row("reviews", {"review_id": r["review_id"], "booking_id": r["booking_id"], "photographer_id": r["photographer_id"], "customer_name": r["customer_name"], "service_title": r["service"], "rating": r["rating"], "comment": r.get("comment"), "created_at": dt(r["created_at"])})
    async for f in db.favorites.find({"user_id": {"$in": list(users)}, "photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("favorites", {"user_id": f["user_id"], "photographer_id": f["photographer_id"], "created_at": dt(f.get("created_at"))})
    convs = set()
    async for c in db.conversations.find({"customer_id": {"$in": list(users)}, "photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        convs.add(c["conversation_id"])
        w.row("conversations", {"conversation_id": c["conversation_id"], "customer_id": c["customer_id"], "photographer_id": c["photographer_id"], "last_message": c.get("last_message", "")[:120], "last_at": dt(c["last_at"]),
                                "unread_customer": c.get("unread_customer", 0), "unread_photographer": c.get("unread_photographer", 0), "created_at": dt(c.get("created_at"))})
    async for m in db.messages.find({"conversation_id": {"$in": list(convs)}}, {"_id": 0}):
        w.row("messages", {"message_id": m["message_id"], "conversation_id": m["conversation_id"], "sender_id": m["sender_id"], "sender_role": m["sender_role"], "body": m["text"], "created_at": dt(m["created_at"])})
    async for p in db.payments.find({"booking_id": {"$in": list(bookings)}}, {"_id": 0}):
        w.row("payments", {"order_id": p["order_id"], "booking_id": p["booking_id"], "customer_id": p["customer_id"], "gross_amount": p["gross_amount"], "snap_token": p.get("token"), "transaction_status": p.get("transaction_status"),
                           "status_code": p.get("status_code"), "fraud_status": p.get("fraud_status"), "transaction_id": p.get("transaction_id"), "is_production": bool(p.get("production")), "expires_at": dt(p.get("expires_at")), "created_at": dt(p.get("created_at"))})
    async for e in db.ledger.find({"$or": [{"photographer_id": {"$in": list(phs)}}, {"photographer_id": None, "ref": {"$in": list(bookings)}}]}, {"_id": 0}):
        w.row("ledger", {"entry_id": e["entry_id"], "idem_key": e["key"], "photographer_id": e["photographer_id"], "type": e["type"], "amount": e["amount"], "ref": e["ref"], "note": e.get("note", "")[:300], "created_at": dt(e["created_at"])})
    async for wl in db.wallets.find({"photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("wallets", {"photographer_id": wl["photographer_id"], "available": wl.get("available", 0)})
    async for po in db.payouts.find({"photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("payouts", {"payout_id": po["payout_id"], "photographer_id": po["photographer_id"], "photographer_name": po.get("photographer_name", ""), "amount": po["amount"], "bank_name": po.get("bank_name"),
                          "holder_name": po.get("holder_name"), "bank_account_masked": po.get("bank_account_masked"), "bank_snapshot_encrypted": po["bank_snapshot_encrypted"], "status": po["status"],
                          "transfer_reference": po.get("transfer_reference"), "note": po.get("note"), "created_at": dt(po["created_at"]), "updated_at": dt(po.get("updated_at"))})
        for h in po.get("history", []):
            w.row("payout_history", {"payout_id": po["payout_id"], "status": h["status"], "actor": h["by"], "note": h.get("note", "")[:500], "reference": h.get("reference", ""), "created_at": dt(h["at"])})
    async for v in db.verifications.find({"photographer_id": {"$in": list(phs)}}, {"_id": 0}):
        w.row("verifications", {"submission_id": v["submission_id"], "photographer_id": v["photographer_id"], "photographer_name": v["photographer_name"], "experience": v["experience"], "links": v.get("links", ""),
                                "status": v["status"], "note": v.get("note"), "decided_by": v.get("decided_by"), "decided_at": dt(v.get("decided_at")), "created_at": dt(v["created_at"])})
        for d in v.get("documents", []):
            w.row("verification_documents", {"doc_id": d["doc_id"], "submission_id": v["submission_id"], "kind": d["kind"], "storage_path": d["storage_path"], "content_type": d["content_type"], "size_bytes": d["size"], "original_filename": d.get("original_filename", "")})
    header = ["-- Jasakamerata data export", f"-- Generated {datetime.now().isoformat()} · include_demo={INCLUDE_DEMO}", "SET NAMES utf8mb4;", "SET FOREIGN_KEY_CHECKS=0;", "START TRANSACTION;"]
    OUT.write_text("\n".join(header + w.lines + ["COMMIT;", "SET FOREIGN_KEY_CHECKS=1;", ""]), encoding="utf-8")
    print(f"Wrote {OUT}")
    for x in skipped:
        print(f"  DILEWATI {x}")
    for t, n in sorted(w.counts.items()):
        print(f"  {t}: {n}")


asyncio.run(main())
