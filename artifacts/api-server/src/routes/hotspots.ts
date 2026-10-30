import { Router, type Request, type Response } from "express";
import { HotspotModel } from "../models";
import { SEED_HOTSPOTS, isMongoConnected } from "../lib/db";

const router = Router();
let memoryHotspots = [...SEED_HOTSPOTS];

// GET /api/hotspots
router.get("/", async (req: Request, res: Response) => {
  try {
    const { wilaya } = req.query;

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

// POST /api/hotspots
router.post("/", async (req: Request, res: Response) => {
  try {
    const { title, description, lat, lng, wilayaCode, radius, severity } = req.body;

    if (!title || !lat || !lng) {
      return res.status(400).json({ error: "Title, lat and lng are required" });
    }

    const newHotspot = {
      id: `hp-${Date.now()}`,
      title,
      description: description || "",
      lat: Number(lat),
      lng: Number(lng),
      wilayaCode: Number(wilayaCode) || 16,
      radius: Number(radius) || 300,
      severity: severity || "high",
      accidentsCount: 0,
    };

    if (isMongoConnected()) {
      const created = await HotspotModel.create(newHotspot);
      return res.status(201).json({ success: true, hotspot: created });
    }

    memoryHotspots.push(newHotspot as any);
    return res.status(201).json({ success: true, hotspot: newHotspot });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
