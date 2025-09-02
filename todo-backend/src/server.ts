import express from "express";
import dotenv from "dotenv";
import { tasksRouter } from "./routes/tasks";
import { nlRouter } from "./routes/nl";
import "./db/index"; // init schema

dotenv.config();

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.use(tasksRouter);
app.use(nlRouter);

// error handler
app.use((err: any, _req: any, res: any, _next: any) => {
  const status = err.status || 500;
  const body = { status: "fail", message: err.message || "internal error", violations: err.violations || undefined };
  res.status(status).json(body);
});

const port = Number(process.env.PORT || 3000);
if (process.env.VITEST !== "1") {
  app.listen(port, () => console.log(`server listening on :${port}`));
}

export default app;

