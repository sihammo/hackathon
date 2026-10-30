import { Router, type Request, type Response } from "express";
import { isMongoConnected } from "../lib/db";
import { isPgConnected, getPgDatabaseStats, testPgConnection } from "../lib/postgres";

const router = Router();

// GET /api/db/status
router.get("/status", async (req: Request, res: Response) => {
  try {
    let pgStats: any = null;
    let pgOk = isPgConnected();

    if (!pgOk) {
      pgOk = await testPgConnection();
    }

    if (pgOk) {
      try {
        pgStats = await getPgDatabaseStats();
      } catch (e: any) {
        pgStats = { error: e.message };
      }
    }

    return res.json({
      success: true,
      primaryDatabase: {
        type: "Supabase PostgreSQL",
        connected: pgOk,
        host: "aws-1-eu-west-3.pooler.supabase.com:6543/postgres",
        ssl: true,
        stats: pgStats,
      },
      secondaryDatabase: {
        type: "MongoDB",
        connected: isMongoConnected(),
      },
      configuredUrls: {
        DATABASE_URL: Boolean(process.env.DATABASE_URL),
        MONGODB_URI: Boolean(process.env.MONGODB_URI),
      },
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
