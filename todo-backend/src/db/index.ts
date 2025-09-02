import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import dotenv from "dotenv";

dotenv.config();

const DB_URL = process.env.DATABASE_URL || "./data.sqlite";
const schemaPath = path.join(process.cwd(), "todo-backend", "src", "db", "schema.sql");

export const db = new Database(DB_URL);

// run schema
const schemaSQL = fs.readFileSync(schemaPath, "utf-8");
db.exec(schemaSQL);

export function toInt(b: boolean | number | null | undefined) {
  if (b === null || b === undefined) return null;
  if (typeof b === "boolean") return b ? 1 : 0;
  return b;
}

