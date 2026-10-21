require("dotenv").config();
const express = require("express");
const cors = require("cors");

const origins = (process.env.CORS_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
const app = express();
app.use(cors({ origin: origins, credentials: true }));
app.use(express.json({ limit: "1mb" }));

app.get("/api/health", async (req, res) => {
  try {
    await require("./src/db").query("SELECT 1");
    res.json({ ok: true, db: "mysql" });
  } catch {
    res.status(503).json({ ok: false });
  }
});
app.use("/api", require("./src/catalog"));
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ detail: "Terjadi kesalahan server" });
});

const port = Number(process.env.PORT || 3000);
if (require.main === module) app.listen(port, () => console.log(`Jasakamerata API (Express) di port ${port}`));

module.exports = app;
