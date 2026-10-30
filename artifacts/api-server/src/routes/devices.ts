import { Router, type Request, type Response } from "express";
import { DeviceModel } from "../models";
import { SEED_DEVICES, isMongoConnected } from "../lib/db";
import { getPgDevices, updatePgDeviceTelemetry } from "../lib/postgres";

const router = Router();
let memoryDevices = [...SEED_DEVICES];

// GET /api/devices
router.get("/", async (req: Request, res: Response) => {
  try {
    const { userId } = req.query;

    // 1. Try Supabase PostgreSQL
    try {
      const pgDevs = await getPgDevices(userId ? String(userId) : undefined);
      if (pgDevs.length > 0) return res.json(pgDevs);
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const query = userId ? { userId } : {};
      const devices = await DeviceModel.find(query).sort({ lastSeen: -1 });
      return res.json(devices);
    }

    let filtered = memoryDevices;
    if (userId) filtered = filtered.filter((d) => d.userId === userId);
    return res.json(filtered);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/telemetry
router.post("/telemetry", async (req: Request, res: Response) => {
  try {
    const { id, batteryLevel, signalStrength, connected } = req.body;
    if (!id) return res.status(400).json({ error: "Device ID is required" });

    try {
      const updated = await updatePgDeviceTelemetry(id, batteryLevel, signalStrength, connected);
      if (updated) return res.json({ success: true, device: updated });
    } catch {
      // Fallback
    }

    if (isMongoConnected()) {
      const updated = await DeviceModel.findOneAndUpdate(
        { id },
        { batteryLevel, signalStrength, connected, lastSeen: new Date() },
        { new: true }
      );
      return res.json({ success: true, device: updated });
    }

    const index = memoryDevices.findIndex((d) => d.id === id);
    if (index !== -1) {
      memoryDevices[index] = {
        ...memoryDevices[index],
        batteryLevel: batteryLevel ?? memoryDevices[index].batteryLevel,
        signalStrength: signalStrength ?? memoryDevices[index].signalStrength,
        connected: connected ?? true,
        lastSeen: new Date(),
      };
      return res.json({ success: true, device: memoryDevices[index] });
    }

    return res.json({ success: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
