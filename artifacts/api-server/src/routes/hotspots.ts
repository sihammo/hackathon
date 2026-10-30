import { Router, type Request, type Response } from "express";
import { HotspotModel } from "../models";
import { SEED_HOTSPOTS, isMongoConnected } from "../lib/db";
import { getPgHotspots } from "../lib/postgres";

const router = Router();
let memoryHotspots = [...SEED_HOTSPOTS];

// GET /api/hotspots
router.get("/", async (req: Request, res: Response) => {
  try {
    const { wilaya } = req.query;

    try {
      const pgHotspots = await getPgHotspots(wilaya ? Number(wilaya) : undefined);
      if (pgHotspots.length > 0) return res.json(pgHotspots);
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const query = wilaya ? { wilayaCode: Number(wilaya) } : {};
      const hotspots = await HotspotModel.find(query).sort({ severity: 1, accidentsCount: -1 });
      return res.json(hotspots);
    }

    let filtered = memoryHotspots;
    if (wilaya) filtered = filtered.filter((h) => h.wilayaCode === Number(wilaya));
    return res.json(filtered);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
