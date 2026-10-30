import { Router, type Request, type Response } from "express";
import { AlertModel } from "../models";
import { SEED_ALERTS, isMongoConnected } from "../lib/db";

const router = Router();
let memoryAlerts: any[] = [...SEED_ALERTS];

// GET /api/alerts
router.get("/", async (req: Request, res: Response) => {
  try {
    const { userId, wilaya, status } = req.query;

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

// POST /api/alerts (New accident or SOS triggered)
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
      status: "sent" as const,
      trigger: trigger || "impact",
      peakG: peakG || 4.5,
      tilt: tilt || 15.0,
      statusTimestamps: { sent: now },
      responses: {},
      notifiedNumbers: notifiedNumbers || ["14", "17"],
      testMode: false,
      createdAt: now,
      updatedAt: now,
    };

    if (isMongoConnected()) {
      const created = await AlertModel.create(newAlert);
      return res.status(201).json({ success: true, alert: created });
    }

    memoryAlerts.unshift(newAlert as any);
    return res.status(201).json({ success: true, alert: newAlert });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/alerts/:id/status (Update accident status - arrived, dispatched, resolved)
router.put("/:id/status", async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { status, responder } = req.body;

    if (!status) return res.status(400).json({ error: "Status is required" });

    const now = new Date();

    if (isMongoConnected()) {
      const alert = await AlertModel.findOne({ id });
      if (!alert) return res.status(404).json({ error: "Alert not found" });

      alert.status = status;
      if (!alert.statusTimestamps) alert.statusTimestamps = {} as any;
      (alert.statusTimestamps as any)[status] = now;

      if (responder) {
        if (!alert.responses) alert.responses = {} as any;
        (alert.responses as any)[responder] = {
          status,
          timestamps: { [status]: now },
        };
      }

      alert.markModified("statusTimestamps");
      alert.markModified("responses");
      await alert.save();
      return res.json({ success: true, alert });
    }

    const index = memoryAlerts.findIndex((a: any) => a.id === id);
    if (index === -1) return res.status(404).json({ error: "Alert not found" });

    const current = memoryAlerts[index];
    memoryAlerts[index] = {
      ...current,
      status,
      statusTimestamps: {
        ...(current.statusTimestamps || {}),
        [status]: now,
      },
    };

    return res.json({ success: true, alert: memoryAlerts[index] });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
