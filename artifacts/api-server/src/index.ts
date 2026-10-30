import app from "./app";
import { logger } from "./lib/logger";
import { testPgConnection } from "./lib/postgres";
import { connectMongo } from "./lib/db";

const rawPort = process.env["PORT"] ?? "5000";
const port = Number(rawPort);

if (Number.isNaN(port) || port <= 0) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}

// Initialize Supabase PostgreSQL & MongoDB connections
testPgConnection().catch((err) => {
  logger.warn({ err }, "Initial PostgreSQL Supabase check deferred");
});

connectMongo().catch((err) => {
  logger.warn({ err }, "Initial MongoDB check deferred");
});

app.listen(port, (err) => {
  if (err) {
    logger.error({ err }, "Error listening on port");
    process.exit(1);
  }

  logger.info({ port }, "Slamtek Backend & API Server listening");
});
