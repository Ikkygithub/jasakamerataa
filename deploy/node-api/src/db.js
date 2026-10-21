const mysql = require("mysql2/promise");

const required = ["DB_HOST", "DB_USER", "DB_NAME"];
for (const k of required) if (!process.env[k]) throw new Error(`Env ${k} belum diatur`);

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  charset: "utf8mb4",
  timezone: "Z",
  dateStrings: true,
  connectionLimit: 5,
});

const query = async (sql, params = []) => (await pool.query(sql, params))[0];

module.exports = { pool, query };
