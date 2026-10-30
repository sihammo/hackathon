import { Router, type Request, type Response } from "express";
import { AlertModel } from "../models";
import { SEED_ALERTS, isMongoConnected } from "../lib/db";
import { getPgAlerts, createPgAlert } from "../lib/postgres";

const router = Router();
let memoryAlerts: any[] = [...SEED_ALERTS];

// GET /api/alerts
router.get("/", async (req: Request, res: Response) => {
  try {
    const { userId, wilaya, status } = req.query;

    try {
      const pgAlerts = await getPgAlerts(
        userId ? String(userId) : undefined,
        wilaya ? Number(wilaya) : undefined,
        status ? String(status) : undefined
      );
      if (pgAlerts.length > 0) return res.json(pgAlerts);
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const query: any = {};
      if (userId) query.userId = userId;
      if (wilaya) query.wilayaCode = Number(wilaya);
      if (status) query.status = status;
      const alerts = await AlertModel.find(query).sort({ createdAt: -1 });
      return res.json(alerts);
    }

    let filtered = memoryAlerts;
    if (userId) filtered = filtered.filter((a) => a.userId === userId);
    if (wilaya) filtered = filtered.filter((a) => a.wilayaCode === Number(wilaya));
    if (status) filtered = filtered.filter((a) => a.status === status);
    return res.json(filtered);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/alerts
router.post("/", async (req: Request, res: Response) => {
  try {
    const {
      userId,
      userName,
      userPhone,
      deviceId,
      lat,
      lng,
      wilayaCode,
      vehicleType,
      trigger,
      peakG,
      tilt,
      notifiedNumbers,
    } = req.body;

    const id = `alert-${Date.now()}`;
    const now = new Date();

    const newAlert = {
      id,
      userId: userId || "demo-user-1",
      userName: userName || "Karim Benali",
      userPhone: userPhone || "0555123456",
      deviceId: deviceId || "SOLVEX-A101",
      lat: lat || 36.7538,
      lng: lng || 3.0588,
      wilayaCode: Number(wilayaCode) || 16,
      vehicleType: vehicleType || "car",
      status: "sent",
      trigger: trigger || "impact",
      peakG: peakG || 4.5,
      tilt: tilt || 15.0,
      statusTimestamps: { sent: now },
      responses: {},
      notifiedNumbers: notifiedNumbers || ["14", "17"],
      testMode: false,
      createdAt: now,
    };

    try {
      const created = await createPgAlert(newAlert);
      if (created) return res.status(201).json({ success: true, alert: created });
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const created = await AlertModel.create(newAlert);
      return res.status(201).json({ success: true, alert: created });
    }

    memoryAlerts.unshift(newAlert);
    return res.status(201).json({ success: true, alert: newAlert });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
